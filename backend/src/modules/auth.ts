import { and, eq, gt, isNull } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { emailTokens, fuelTypes, refreshTokens, users } from "../db/schema.js";
import { DEFAULT_FUEL_TYPES } from "../lib/catalog.js";
import {
  hashPassword,
  newId,
  randomToken,
  sha256,
  signAccess,
  signRefresh,
  verifyAccess,
  verifyPassword,
  verifyRefresh,
  type AccessClaims,
} from "../lib/crypto.js";
import { AppError } from "../lib/errors.js";
import { publicUser } from "../lib/serialize.js";
import { recordChange } from "../lib/dbx.js";
import { bearer } from "../types.js";

const signupBody = z.object({
  email: z.string().email().max(254),
  password: z.string().min(8),
  display_name: z.string().optional(),
});

const loginBody = z.object({
  email: z.string().email(),
  password: z.string(),
});

const TOKEN_TTL_MS = 24 * 60 * 60 * 1000;

export const authPlugin: FastifyPluginAsync = async (app) => {
  app.post("/auth/signup", { config: { public: true } }, async (request, reply) => {
    const body = signupBody.parse(request.body);
    const email = body.email.toLowerCase();
    const existing = await app.db.select().from(users).where(eq(users.email, email)).limit(1);
    if (existing[0]) throw new AppError(409, "email_taken", "Email already registered");
    const id = newId();
    const passwordHash = await hashPassword(body.password);
    const [user] = await app.db
      .insert(users)
      .values({
        id,
        email,
        passwordHash,
        displayName: body.display_name ?? null,
        role: "owner",
        plan: "free",
      })
      .returning();
    for (const ft of DEFAULT_FUEL_TYPES) {
      await app.db.insert(fuelTypes).values({
        id: newId(),
        userId: id,
        name: ft.name,
        kind: ft.kind,
        unit: ft.unit,
      });
    }
    await recordChange(app.db, { userId: id, entityType: "user", entityId: id, op: "upsert", payload: publicUser(user) });
    const verify = randomToken();
    await app.db.insert(emailTokens).values({
      id: newId(),
      userId: id,
      purpose: "verify",
      tokenHash: sha256(verify),
      expiresAt: new Date(Date.now() + TOKEN_TTL_MS),
    });
    await app.mailer.sendVerification(email, verify);
    const session = await issueSession(app, user);
    return reply.code(201).send(session);
  });

  app.post("/auth/login", { config: { public: true } }, async (request) => {
    const body = loginBody.parse(request.body);
    const email = body.email.toLowerCase();
    const [user] = await app.db.select().from(users).where(eq(users.email, email)).limit(1);
    if (!user || !(await verifyPassword(body.password, user.passwordHash))) {
      throw new AppError(401, "invalid_credentials", "Invalid email or password");
    }
    if (user.status === "deactivated") {
      throw new AppError(401, "deactivated", "Account is deactivated");
    }
    return issueSession(app, user);
  });

  app.post("/auth/refresh", { config: { public: true } }, async (request) => {
    const body = z.object({ refresh_token: z.string() }).parse(request.body);
    let payload;
    try {
      payload = await verifyRefresh(app.env, body.refresh_token);
    } catch {
      throw new AppError(401, "invalid_refresh", "Refresh token is invalid");
    }
    const [stored] = await app.db
      .select()
      .from(refreshTokens)
      .where(
        and(
          eq(refreshTokens.id, payload.jti),
          eq(refreshTokens.tokenHash, sha256(body.refresh_token)),
          isNull(refreshTokens.revokedAt),
          gt(refreshTokens.expiresAt, new Date()),
        ),
      )
      .limit(1);
    if (!stored) throw new AppError(401, "invalid_refresh", "Refresh token is invalid");
    await app.db.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.id, stored.id));
    const [user] = await app.db.select().from(users).where(eq(users.id, stored.userId)).limit(1);
    if (!user || user.status === "deactivated") throw new AppError(401, "invalid_refresh", "Refresh token is invalid");
    return issueSession(app, user, stored.familyId);
  });

  app.post("/auth/logout", async (request, reply) => {
    const userId = request.authUser!.sub;
    await app.db.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.userId, userId));
    return reply.code(204).send();
  });

  app.post("/auth/verify-email", { config: { public: true } }, async (request, reply) => {
    const body = z.object({ token: z.string() }).parse(request.body);
    const [row] = await app.db
      .select()
      .from(emailTokens)
      .where(and(eq(emailTokens.tokenHash, sha256(body.token)), eq(emailTokens.purpose, "verify")))
      .limit(1);
    if (!row || row.usedAt || row.expiresAt < new Date()) {
      throw new AppError(400, "invalid_token", "Verification token is invalid");
    }
    await app.db.update(emailTokens).set({ usedAt: new Date() }).where(eq(emailTokens.id, row.id));
    await app.db.update(users).set({ emailVerified: true }).where(eq(users.id, row.userId));
    return reply.code(204).send();
  });

  app.post("/auth/resend-verification", async (request, reply) => {
    const userId = request.authUser!.sub;
    const [user] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (user && !user.emailVerified) {
      const token = randomToken();
      await app.db.insert(emailTokens).values({
        id: newId(),
        userId,
        purpose: "verify",
        tokenHash: sha256(token),
        expiresAt: new Date(Date.now() + TOKEN_TTL_MS),
      });
      await app.mailer.sendVerification(user.email, token);
    }
    return reply.code(202).send();
  });

  app.post("/auth/forgot-password", { config: { public: true } }, async (request, reply) => {
    const body = z.object({ email: z.string().email() }).parse(request.body);
    const [user] = await app.db.select().from(users).where(eq(users.email, body.email.toLowerCase())).limit(1);
    if (user) {
      const token = randomToken();
      await app.db.insert(emailTokens).values({
        id: newId(),
        userId: user.id,
        purpose: "reset",
        tokenHash: sha256(token),
        expiresAt: new Date(Date.now() + TOKEN_TTL_MS),
      });
      await app.mailer.sendPasswordReset(user.email, token);
    }
    return reply.code(202).send();
  });

  app.post("/auth/reset-password", { config: { public: true } }, async (request, reply) => {
    const body = z.object({ token: z.string(), password: z.string().min(8) }).parse(request.body);
    const [row] = await app.db
      .select()
      .from(emailTokens)
      .where(and(eq(emailTokens.tokenHash, sha256(body.token)), eq(emailTokens.purpose, "reset")))
      .limit(1);
    if (!row || row.usedAt || row.expiresAt < new Date()) {
      throw new AppError(400, "invalid_token", "Reset token is invalid");
    }
    await app.db.update(emailTokens).set({ usedAt: new Date() }).where(eq(emailTokens.id, row.id));
    await app.db.update(users).set({ passwordHash: await hashPassword(body.password) }).where(eq(users.id, row.userId));
    await app.db.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.userId, row.userId));
    return reply.code(204).send();
  });
};

export async function attachAuth(app: Parameters<FastifyPluginAsync>[0]): Promise<void> {
  const publicPaths = new Set([
    "/v1/health",
    "/v1/ready",
    "/v1/auth/signup",
    "/v1/auth/login",
    "/v1/auth/refresh",
    "/v1/auth/verify-email",
    "/v1/auth/forgot-password",
    "/v1/auth/reset-password",
  ]);
  app.addHook("preHandler", async (request) => {
    const cfg = request.routeOptions.config as { public?: boolean } | undefined;
    const path = request.url.split("?")[0];
    if (cfg?.public || publicPaths.has(path) || path.startsWith("/v1/media/") && path.endsWith("/content")) {
      return;
    }
    const token = bearer(request);
    if (!token) throw new AppError(401, "unauthorized", "Missing access token");
    try {
      const claims = await verifyAccess(app.env, token);
      request.authUser = claims as AccessClaims & { sub: string };
    } catch {
      throw new AppError(401, "unauthorized", "Invalid access token");
    }
  });
}

export function requireOwner(request: { authUser?: AccessClaims & { sub: string } }) {
  if (!request.authUser) throw new AppError(401, "unauthorized", "Missing access token");
  if (request.authUser.role !== "owner") {
    throw new AppError(403, "forbidden", "Owner audience required");
  }
}

export function requireAdmin(request: { authUser?: AccessClaims & { sub: string } }, adminAud: string) {
  if (!request.authUser) throw new AppError(401, "unauthorized", "Missing access token");
  if (request.authUser.role !== "admin" || request.authUser.aud !== adminAud) {
    throw new AppError(403, "forbidden", "Admin role required");
  }
}

async function issueSession(
  app: { env: import("../config/env.js").Env; db: import("../db/client.js").Db },
  user: typeof users.$inferSelect,
  familyId = newId(),
) {
  const access = await signAccess(app.env, {
    sub: user.id,
    role: user.role,
    plan: user.plan,
  });
  const jti = newId();
  const refresh = await signRefresh(app.env, user.id, familyId, jti);
  await app.db.insert(refreshTokens).values({
    id: jti,
    userId: user.id,
    familyId,
    tokenHash: sha256(refresh.token),
    expiresAt: refresh.expiresAt,
  });
  return {
    access_token: access.token,
    refresh_token: refresh.token,
    expires_in: access.expiresIn,
    user: publicUser(user),
  };
}

export { issueSession };
