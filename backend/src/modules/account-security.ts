import { createHmac, randomInt, timingSafeEqual } from "node:crypto";
import { and, eq, isNull, sql } from "drizzle-orm";
import type { FastifyInstance, FastifyPluginAsync, FastifyRequest } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import { authChallenges, authLimits, emailTokens, refreshTokens, users } from "../db/schema.js";
import { hashPassword, newId, sha256, verifyPassword } from "../lib/crypto.js";
import { AppError } from "../lib/errors.js";
import { publicUser } from "../lib/serialize.js";

// PostgreSQL-backed counters work across replicas. Upsert serializes contenders.
export async function authLimit(db: Db, key: string, max: number, seconds = 3600) {
  const [row] = await db.insert(authLimits).values({ key: sha256(key), count: 1, expiresAt: new Date(Date.now() + seconds * 1000) })
    .onConflictDoUpdate({ target: authLimits.key, set: {
      count: sql`CASE WHEN ${authLimits.expiresAt} <= now() THEN 1 ELSE ${authLimits.count} + 1 END`,
      expiresAt: sql`CASE WHEN ${authLimits.expiresAt} <= now() THEN now() + ${seconds} * interval '1 second' ELSE ${authLimits.expiresAt} END`,
    } }).returning();
  if (row.count > max) throw new AppError(429, "rate_limited", "Too many requests. Please try again later.");
}

export async function requireRecent(app: FastifyInstance, request: FastifyRequest, password?: string) {
  const [user] = await app.db.select().from(users).where(eq(users.id, request.authUser!.sub));
  if (!user || user.status !== "active") throw new AppError(401, "unauthorized", "Sign in again");
  if (Number(request.authUser?.auth_time ?? 0) < Date.now() / 1000 - 300) {
    await authLimit(app.db, `reauth:${user.id}`, 10);
    if (!password || !await verifyPassword(password, user.passwordHash)) throw new AppError(401, "reauth_required", "Sign in again before changing your account");
  }
  return user;
}

export async function requireVerifiedForSharing(app: FastifyInstance, userId: string) {
  if (app.env.AUTH_CODES_ENABLED !== "on") return;
  const [user] = await app.db.select().from(users).where(eq(users.id, userId));
  if (!user?.emailVerified) throw new AppError(403, "email_verification_required", "Verify your email before creating or accepting a share");
}

const locale = z.enum(["en", "my"]).default("en");
const codeBody = z.object({ challenge_id: z.string().uuid(), code: z.string().regex(/^\d{6}$/) });
function digest(app: FastifyInstance, id: string, code: string) {
  return createHmac("sha256", app.env.AUTH_CODE_SECRET!).update(`${id}:${code}`).digest("hex");
}

export const accountSecurityPlugin: FastifyPluginAsync = async (app) => {
  const enabled = () => {
    if (app.env.AUTH_CODES_ENABLED !== "on") throw new AppError(503, "auth_not_configured", "Email verification is not configured yet");
  };
  async function issue(request: FastifyRequest, purpose: "verify" | "reset", email: string, userId: string | null, language: "en" | "my") {
    await authLimit(app.db, `code-ip:${request.ip}`, 30);
    await authLimit(app.db, `code-hour:${email}`, 8);
    await authLimit(app.db, `code-minute:${email}`, 1, 60);
    const id = newId();
    const code = randomInt(0, 1000000).toString().padStart(6, "0");
    await app.db.transaction(async (tx) => {
      await tx.update(authChallenges).set({ consumedAt: new Date() }).where(and(eq(authChallenges.email, email), eq(authChallenges.purpose, purpose), isNull(authChallenges.consumedAt)));
      await tx.insert(authChallenges).values({ id, userId, email, purpose, digest: digest(app, id, code), expiresAt: new Date(Date.now() + 600000) });
    });
    if (userId) {
      try { await app.mailer.sendCode(email, code, purpose, language); }
      catch {
        await app.db.update(authChallenges).set({ consumedAt: new Date() }).where(eq(authChallenges.id, id));
        app.log.error({ purpose }, "Authentication email delivery failed");
        // Recovery has identical public behavior for unknown/social-only addresses.
        if (purpose === "verify") throw new AppError(503, "delivery_failed", "Could not send the email. Please try again later.");
      }
    }
    return { challenge_id: id, expires_in: 600, resend_after: 60 };
  }
  async function consume(request: FastifyRequest, purpose: "verify" | "reset", password?: string) {
    const body = codeBody.parse(request.body);
    await authLimit(app.db, `code-check:${request.ip}`, 60);
    const result = await app.db.transaction(async (tx) => {
      const [row] = await tx.select().from(authChallenges).where(eq(authChallenges.id, body.challenge_id)).for("update");
      if (!row || row.purpose !== purpose || row.consumedAt || row.expiresAt <= new Date() || row.attempts >= 5 || !row.userId) return null;
      if (purpose === "verify" && row.userId !== request.authUser?.sub) return null;
      const valid = timingSafeEqual(Buffer.from(row.digest, "hex"), Buffer.from(digest(app, row.id, body.code), "hex"));
      if (!valid) {
        await tx.update(authChallenges).set({ attempts: row.attempts + 1 }).where(eq(authChallenges.id, row.id));
        return null;
      }
      const [user] = await tx.select().from(users).where(eq(users.id, row.userId)).for("update");
      if (!user || user.email !== row.email || user.status !== "active" || (purpose === "reset" && !user.passwordHash)) return null;
      await tx.update(authChallenges).set({ consumedAt: new Date() }).where(eq(authChallenges.id, row.id));
      const [updated] = await tx.update(users).set(purpose === "verify" ? { emailVerified: true } : { passwordHash: password!, authVersion: user.authVersion + 1 }).where(eq(users.id, user.id)).returning();
      if (purpose === "reset") await tx.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.userId, user.id));
      return publicUser(updated);
    });
    if (!result) throw new AppError(400, "invalid_code", "The code is incorrect, expired, or has already been used");
    return { user: result };
  }
  app.post("/auth/email-code", async (request) => {
    enabled();
    const body = z.object({ locale }).parse(request.body ?? {});
    const [user] = await app.db.select().from(users).where(eq(users.id, request.authUser!.sub));
    if (!user?.email || user.emailVerified) throw new AppError(409, "verification_not_needed", "No unverified email address");
    return issue(request, "verify", user.email, user.id, body.locale);
  });
  app.post("/auth/email-code/confirm", async (request) => { enabled(); return consume(request, "verify"); });
  app.post("/auth/email-correction", async (request) => {
    enabled();
    const body = z.object({ email: z.string().email().max(254).transform(s => s.toLowerCase()), password: z.string().optional(), locale }).parse(request.body);
    const user = await requireRecent(app, request, body.password);
    if (user.emailVerified) throw new AppError(409, "already_verified", "This address is already verified");
    await authLimit(app.db, `correction:${user.id}`, 5);
    const [existing] = await app.db.select().from(users).where(eq(users.email, body.email));
    if (existing && existing.id !== user.id) throw new AppError(409, "email_taken", "Sign in to or recover the existing account; accounts cannot be merged here");
    try {
      await app.db.transaction(async (tx) => {
        await tx.update(users).set({ email: body.email, emailVerified: false }).where(and(eq(users.id, user.id), eq(users.emailVerified, false)));
        await tx.update(authChallenges).set({ consumedAt: new Date() }).where(eq(authChallenges.userId, user.id));
        await tx.update(emailTokens).set({ usedAt: new Date() }).where(eq(emailTokens.userId, user.id));
      });
    } catch (error) {
      if ((error as { cause?: { code?: string }; code?: string }).cause?.code === "23505" || (error as { code?: string }).code === "23505") throw new AppError(409, "email_taken", "Sign in to the existing account");
      throw error;
    }
    return issue(request, "verify", body.email, user.id, body.locale);
  });
  app.post("/auth/recovery-code", { config: { public: true } }, async (request) => {
    enabled();
    const body = z.object({ email: z.string().email().max(254).transform(s => s.toLowerCase()), locale }).parse(request.body);
    const [user] = await app.db.select().from(users).where(eq(users.email, body.email));
    return issue(request, "reset", body.email, user?.passwordHash && user.status === "active" ? user.id : null, body.locale);
  });
  app.post("/auth/recovery-code/confirm", { config: { public: true } }, async (request, reply) => {
    enabled();
    const body = codeBody.extend({ password: z.string().min(8).max(128) }).parse(request.body);
    await authLimit(app.db, `recovery-hash:${request.ip}`, 20);
    await consume(request, "reset", await hashPassword(body.password));
    return reply.code(204).send();
  });
  app.post("/auth/first-password", async (request, reply) => {
    const body = z.object({ password: z.string().min(8).max(128) }).parse(request.body);
    const user = await requireRecent(app, request);
    if (user.passwordHash || !user.emailVerified) throw new AppError(409, "password_setup_unavailable", "Verify your email or use password change");
    await app.db.update(users).set({ passwordHash: await hashPassword(body.password) }).where(and(eq(users.id, user.id), isNull(users.passwordHash)));
    return reply.code(204).send();
  });
};
