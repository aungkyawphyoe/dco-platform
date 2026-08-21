import { desc, eq, sql } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { auditEvents, documents, partners, refreshTokens, users, vehicles } from "../db/schema.js";
import { newId, randomToken, sha256 } from "../lib/crypto.js";
import { AppError } from "../lib/errors.js";
import { emailTokens } from "../db/schema.js";
import { requireAdmin } from "./auth.js";

export const adminPlugin: FastifyPluginAsync = async (app) => {
  app.addHook("preHandler", async (request) => {
    requireAdmin(request, app.env.JWT_ADMIN_AUD);
  });

  app.get("/admin/dashboard", async () => {
    const [{ count: usersTotal }] = await app.db.select({ count: sql<number>`count(*)::int` }).from(users);
    const [{ count: vehiclesActive }] = await app.db
      .select({ count: sql<number>`count(*)::int` })
      .from(vehicles)
      .where(eq(vehicles.archived, false));
    const [{ count: partnersTotal }] = await app.db.select({ count: sql<number>`count(*)::int` }).from(partners);
    const recentUsers = await app.db.select().from(users).orderBy(desc(users.createdAt)).limit(5);
    return {
      users_total: Number(usersTotal),
      vehicles_active: Number(vehiclesActive),
      partners_total: Number(partnersTotal),
      sync_errors_24h: 0,
      recent_activity: recentUsers.map((u) => ({
        at: u.createdAt.toISOString(),
        kind: "signup" as const,
        summary: u.email,
      })),
    };
  });

  app.get("/admin/users", async (request) => {
    const q = request.query as { q?: string; status?: "active" | "deactivated" };
    let rows = await app.db.select().from(users);
    if (q.status) rows = rows.filter((u) => u.status === q.status);
    if (q.q) {
      const needle = q.q.toLowerCase();
      rows = rows.filter(
        (u) => u.email.includes(needle) || (u.displayName ?? "").toLowerCase().includes(needle),
      );
    }
    const items = [];
    for (const u of rows) {
      const v = await app.db.select().from(vehicles).where(eq(vehicles.userId, u.id));
      items.push({
        id: u.id,
        email: u.email,
        display_name: u.displayName,
        plan: u.plan,
        status: u.status,
        vehicle_count: v.filter((x) => !x.archived).length,
        created_at: u.createdAt.toISOString(),
      });
    }
    return { items };
  });

  app.get("/admin/users/:userId", async (request) => {
    const { userId } = request.params as { userId: string };
    const [u] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) throw new AppError(404, "not_found", "User not found");
    const v = await app.db.select().from(vehicles).where(eq(vehicles.userId, userId));
    let documentsCount = 0;
    for (const vehicle of v) {
      const docs = await app.db.select().from(documents).where(eq(documents.vehicleId, vehicle.id));
      documentsCount += docs.length;
    }
    return {
      id: u.id,
      email: u.email,
      display_name: u.displayName,
      plan: u.plan,
      status: u.status,
      vehicle_count: v.filter((x) => !x.archived).length,
      created_at: u.createdAt.toISOString(),
      email_verified: u.emailVerified,
      vehicles: v.map((veh) => ({
        id: veh.id,
        nickname: veh.nickname ?? veh.name,
        license_plate: veh.licensePlate,
      })),
      documents_count: documentsCount,
    };
  });

  app.patch("/admin/users/:userId", async (request) => {
    const { userId } = request.params as { userId: string };
    const body = z.object({ plan: z.enum(["free", "premium"]).optional() }).parse(request.body ?? {});
    const [u] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) throw new AppError(404, "not_found", "User not found");
    const [updated] = await app.db
      .update(users)
      .set({ ...(body.plan ? { plan: body.plan } : {}) })
      .where(eq(users.id, userId))
      .returning();
    await audit(app, request.authUser!.sub, "user.plan_change", { userId, plan: updated.plan });
    return { id: updated.id, plan: updated.plan, email: updated.email, status: updated.status };
  });

  app.post("/admin/users/:userId/deactivate", async (request, reply) => {
    const { userId } = request.params as { userId: string };
    await app.db.update(users).set({ status: "deactivated" }).where(eq(users.id, userId));
    await app.db.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.userId, userId));
    await audit(app, request.authUser!.sub, "user.deactivate", { userId });
    return reply.code(204).send();
  });

  app.post("/admin/users/:userId/reactivate", async (request, reply) => {
    const { userId } = request.params as { userId: string };
    await app.db.update(users).set({ status: "active" }).where(eq(users.id, userId));
    await audit(app, request.authUser!.sub, "user.reactivate", { userId });
    return reply.code(204).send();
  });

  app.post("/admin/users/:userId/send-password-reset", async (request, reply) => {
    const { userId } = request.params as { userId: string };
    const [u] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) throw new AppError(404, "not_found", "User not found");
    const token = randomToken();
    await app.db.insert(emailTokens).values({
      id: newId(),
      userId,
      purpose: "reset",
      tokenHash: sha256(token),
      expiresAt: new Date(Date.now() + 86400000),
    });
    await app.mailer.sendPasswordReset(u.email, token);
    await audit(app, request.authUser!.sub, "user.send_password_reset", { userId });
    return reply.code(202).send();
  });

  const publicPartner = (row: typeof partners.$inferSelect) => ({
    id: row.id,
    name: row.name,
    type: row.type,
    status: row.status,
    contact_email: row.contactEmail,
    contact_phone: row.contactPhone,
    notes: row.notes,
    updated_at: row.updatedAt.toISOString(),
  });

  app.get("/admin/partners", async (request) => {
    const q = (request.query as { q?: string }).q;
    let rows = await app.db.select().from(partners);
    if (q) {
      const needle = q.toLowerCase();
      rows = rows.filter((p) => p.name.toLowerCase().includes(needle));
    }
    return { items: rows.map(publicPartner) };
  });

  app.post("/admin/partners", async (request, reply) => {
    const body = z
      .object({
        name: z.string().min(1).max(120),
        type: z.enum(["workshop", "insurer"]),
        status: z.enum(["draft", "pending_verification", "verified", "rejected"]).optional(),
        contact_email: z.string().optional().nullable(),
        contact_phone: z.string().optional().nullable(),
        notes: z.string().optional().nullable(),
      })
      .parse(request.body);
    const [row] = await app.db
      .insert(partners)
      .values({
        id: newId(),
        name: body.name,
        type: body.type,
        status: body.status ?? "draft",
        contactEmail: body.contact_email ?? null,
        contactPhone: body.contact_phone ?? null,
        notes: body.notes ?? null,
      })
      .returning();
    await audit(app, request.authUser!.sub, "partner.create", { partnerId: row.id });
    return reply.code(201).send(publicPartner(row));
  });

  app.get("/admin/partners/:partnerId", async (request) => {
    const { partnerId } = request.params as { partnerId: string };
    const [row] = await app.db.select().from(partners).where(eq(partners.id, partnerId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Partner not found");
    return publicPartner(row);
  });

  app.patch("/admin/partners/:partnerId", async (request) => {
    const { partnerId } = request.params as { partnerId: string };
    const [row] = await app.db.select().from(partners).where(eq(partners.id, partnerId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Partner not found");
    const body = z
      .object({
        name: z.string().max(120).optional(),
        type: z.enum(["workshop", "insurer"]).optional(),
        status: z.enum(["draft", "pending_verification", "verified", "rejected"]).optional(),
        contact_email: z.string().optional().nullable(),
        contact_phone: z.string().optional().nullable(),
        notes: z.string().optional().nullable(),
      })
      .parse(request.body ?? {});
    const [updated] = await app.db
      .update(partners)
      .set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.type !== undefined ? { type: body.type } : {}),
        ...(body.status !== undefined ? { status: body.status } : {}),
        ...(body.contact_email !== undefined ? { contactEmail: body.contact_email } : {}),
        ...(body.contact_phone !== undefined ? { contactPhone: body.contact_phone } : {}),
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
        updatedAt: new Date(),
      })
      .where(eq(partners.id, partnerId))
      .returning();
    await audit(app, request.authUser!.sub, "partner.update", { partnerId, status: updated.status });
    return publicPartner(updated);
  });
};

async function audit(
  app: { db: import("../db/client.js").Db },
  adminUserId: string,
  action: string,
  detail: Record<string, unknown>,
) {
  await app.db.insert(auditEvents).values({ adminUserId, action, detail });
}
