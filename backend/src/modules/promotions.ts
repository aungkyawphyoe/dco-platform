import { publicPlaySubscription } from "../lib/play-subscriptions.js";
import { randomBytes } from "node:crypto";
import { and, desc, eq, gt, sql } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import { auditEvents, giftGrants, playSubscriptions, promotionCodes, promotions, users } from "../db/schema.js";
import { newId, sha256 } from "../lib/crypto.js";
import { AppError } from "../lib/errors.js";
import { effectiveSubscription, publicGift } from "../lib/gifts.js";
import { assertPersonalGarageAllowed } from "../lib/personal-garage.js";
import { requireAdmin, requireOwner } from "./auth.js";
import { authLimit } from "./account-security.js";

const normalize = (code: string) => code.trim().toUpperCase();
const codeSchema = z.string().trim().min(6).max(64).regex(/^[A-Za-z0-9-]+$/).transform(normalize);
const createSchema = z.object({
  name: z.string().trim().min(1).max(100), kind: z.enum(["single_use", "shared"]),
  plan: z.enum(["lite", "standard"]), duration_days: z.number().int().min(1).max(3650),
  redeem_by: z.string().datetime({ offset: true }), capacity: z.number().int().min(1).max(1000000),
  code: codeSchema.optional(),
}).strict().superRefine((body, ctx) => {
  if (body.kind === "single_use" && body.capacity > 1000) ctx.addIssue({ code: "custom", message: "Batches are limited to 1000 codes", path: ["capacity"] });
  if (body.kind === "single_use" && body.code) ctx.addIssue({ code: "custom", message: "Batch codes are generated", path: ["code"] });
});
const publicPromotion = (p: typeof promotions.$inferSelect, redeemed: number) => ({
  id: p.id, name: p.name, kind: p.kind, plan: p.plan, duration_days: p.durationDays,
  redeem_by: p.redeemBy.toISOString(), capacity: p.capacity, enabled: p.enabled,
  created_at: p.createdAt.toISOString(), redeemed,
});

export const promotionsPlugin: FastifyPluginAsync = async (app) => {
  app.get("/me/subscription", async request => {
    requireOwner(request);
    await assertPersonalGarageAllowed(app.db, request.authUser!.sub);
    const sub = await effectiveSubscription(app.db, request.authUser!.sub);
    const [play] = await app.db.select().from(playSubscriptions).where(eq(playSubscriptions.userId, request.authUser!.sub)).orderBy(desc(playSubscriptions.expiresAt)).limit(1);
    return { plan: sub.plan, gift: sub.gift ? publicGift(sub.gift) : null, play: play ? publicPlaySubscription(play) : null };
  });

  app.post("/me/gift-redemptions", async request => {
    requireOwner(request);
    const userId = request.authUser!.sub;
    await authLimit(app.db, `gift-account:${userId}`, 10, 600);
    await authLimit(app.db, `gift-ip:${request.ip}`, 60, 600);
    const body = z.object({ code: codeSchema, request_id: z.string().uuid() }).strict().parse(request.body);
    return app.db.transaction(async tx => {
      // Account then promotion: consistent locks serialize both account eligibility
      // and campaign capacity across replicas. Failed transactions consume nothing.
      const [user] = await tx.select().from(users).where(eq(users.id, userId)).for("update");
      await assertPersonalGarageAllowed(tx as unknown as Db, userId);
      if (!user.emailVerified) throw new AppError(403, "email_verification_required", "Verify your email before redeeming a code");
      const [code] = await tx.select().from(promotionCodes).where(eq(promotionCodes.codeHash, sha256(body.code)));
      const [previous] = await tx.select().from(giftGrants).where(and(eq(giftGrants.userId, userId), eq(giftGrants.requestId, body.request_id)));
      if (previous) {
        if (previous.codeId !== code?.id) throw new AppError(409, "request_conflict", "Use a new request for a different code");
        return { gift: publicGift(previous), replayed: true };
      }
      if (!code) throw new AppError(422, "code_unavailable", "This code is invalid or no longer available");
      const [promotion] = await tx.select().from(promotions).where(eq(promotions.id, code.promotionId)).for("update");
      const now = new Date();
      if (!promotion.enabled || promotion.redeemBy <= now) throw new AppError(422, "code_unavailable", "This code is invalid or no longer available");
      if ((await effectiveSubscription(tx as unknown as Db, userId)).play || user.plan !== "free") throw new AppError(409, "plan_ineligible", "Only Free accounts can redeem a gift");
      const [active] = await tx.select().from(giftGrants).where(and(eq(giftGrants.userId, userId), gt(giftGrants.endsAt, now))).limit(1);
      if (active) throw new AppError(409, "gift_active", "Wait until your current gift expires before redeeming another");
      const [used] = await tx.select().from(giftGrants).where(and(eq(giftGrants.userId, userId), eq(giftGrants.promotionId, promotion.id)));
      if (used) throw new AppError(409, "promotion_redeemed", "You have already redeemed this promotion");
      const [count] = await tx.select({ total: sql<number>`count(*)` }).from(giftGrants).where(eq(giftGrants.promotionId, promotion.id));
      const [codeUsed] = promotion.kind === "single_use"
        ? await tx.select().from(giftGrants).where(eq(giftGrants.codeId, code.id)).limit(1) : [];
      if (Number(count.total) >= promotion.capacity || codeUsed) throw new AppError(422, "code_unavailable", "This code is invalid or no longer available");
      const [gift] = await tx.insert(giftGrants).values({ id: newId(), userId,
        promotionId: promotion.id, codeId: code.id, singleUseCodeId: promotion.kind === "single_use" ? code.id : null, requestId: body.request_id, plan: promotion.plan,
        startsAt: now, endsAt: new Date(now.getTime() + promotion.durationDays * 86400000) }).returning();
      return { gift: publicGift(gift), replayed: false };
    });
  });

  app.get("/admin/promotions", async request => {
    requireAdmin(request, app.env.JWT_ADMIN_AUD);
    const query = z.object({ offset: z.coerce.number().int().min(0).default(0) }).parse(request.query);
    const rows = await app.db.select({ promotion: promotions, redeemed: sql<number>`count(${giftGrants.id})` })
      .from(promotions).leftJoin(giftGrants, eq(giftGrants.promotionId, promotions.id))
      .groupBy(promotions.id).orderBy(desc(promotions.createdAt), promotions.id).limit(50).offset(query.offset);
    return { items: rows.map(r => publicPromotion(r.promotion, Number(r.redeemed))), next_offset: rows.length === 50 ? query.offset + 50 : null };
  });

  app.post("/admin/promotions", async (request, reply) => {
    requireAdmin(request, app.env.JWT_ADMIN_AUD);
    const body = createSchema.parse(request.body);
    if (new Date(body.redeem_by) <= new Date()) throw new AppError(422, "invalid_deadline", "Choose a future redemption deadline");
    const codes = Array.from({ length: body.kind === "single_use" ? body.capacity : 1 }, () => `AX-${randomBytes(12).toString("hex").toUpperCase()}`);
    if (body.kind === "shared" && body.code) codes[0] = body.code;
    const result = await app.db.transaction(async tx => {
      const [promotion] = await tx.insert(promotions).values({ id: newId(), name: body.name, kind: body.kind,
        plan: body.plan, durationDays: body.duration_days, redeemBy: new Date(body.redeem_by), capacity: body.capacity,
        createdBy: request.authUser!.sub }).returning();
      const inserted = await tx.insert(promotionCodes).values(codes.map(code => ({ id: newId(), promotionId: promotion.id, codeHash: sha256(code) })))
        .onConflictDoNothing().returning();
      if (inserted.length !== codes.length) throw new AppError(409, "code_exists", "Choose a different shared code");
      await tx.insert(auditEvents).values({ adminUserId: request.authUser!.sub, action: "promotion.create", detail: { promotionId: promotion.id, kind: promotion.kind, capacity: promotion.capacity } });
      return publicPromotion(promotion, 0);
    });
    // Plaintext codes are returned once for distribution; only hashes persist.
    return reply.code(201).send({ promotion: result, codes });
  });

  app.patch("/admin/promotions/:id", async request => {
    requireAdmin(request, app.env.JWT_ADMIN_AUD);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    z.object({ enabled: z.literal(false) }).strict().parse(request.body);
    return app.db.transaction(async tx => {
      const [row] = await tx.update(promotions).set({ enabled: false }).where(eq(promotions.id, id)).returning();
      if (!row) throw new AppError(404, "not_found", "Promotion not found");
      await tx.insert(auditEvents).values({ adminUserId: request.authUser!.sub, action: "promotion.disable", detail: { promotionId: id } });
      return { id: row.id, enabled: row.enabled };
    });
  });

  app.get("/admin/promotions/:id/redemptions", async request => {
    requireAdmin(request, app.env.JWT_ADMIN_AUD);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const { offset } = z.object({ offset: z.coerce.number().int().min(0).default(0) }).parse(request.query);
    const rows = await app.db.select({ gift: giftGrants, email: users.email }).from(giftGrants)
      .innerJoin(users, eq(users.id, giftGrants.userId)).where(eq(giftGrants.promotionId, id))
      .orderBy(desc(giftGrants.startsAt), giftGrants.id).limit(50).offset(offset);
    return { items: rows.map(r => ({ ...publicGift(r.gift), user_id: r.gift.userId, email: r.email })), next_offset: rows.length === 50 ? offset + 50 : null };
  });
};
