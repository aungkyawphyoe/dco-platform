import { authLimit } from "./account-security.js";
import { and, eq, gt, isNull, sql } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { emailTokens, fuelTypes, organizationMembers, organizations, partners, refreshTokens, users, workshopMembers } from "../db/schema.js";
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
import { generateUniqueUsername } from "../lib/username.js";
import { bearer } from "../types.js";

const signupBody = z.object({
  email: z.string().email().max(254),
  password: z.string().min(8),
  display_name: z.string().optional(),
});

const loginBody = z.object({
  email: z.string().min(1).max(254),
  password: z.string(),
  surface: z.enum(["owner", "fleet", "workshop"]).optional().default("owner"),
});

const TOKEN_TTL_MS = 24 * 60 * 60 * 1000;

export const authPlugin: FastifyPluginAsync = async (app) => {
  app.post("/auth/signup", { config: { public: true } }, async (request, reply) => {
    const body = signupBody.parse(request.body);
    if (app.env.AUTH_CODES_ENABLED === "on") await authLimit(app.db, `signup:${request.ip}`, 10);
    const email = body.email.toLowerCase();
    const existing = await app.db.select().from(users).where(eq(users.email, email)).limit(1);
    if (existing[0]) throw new AppError(409, "email_taken", "Email already registered");
    const id = newId();
    const passwordHash = await hashPassword(body.password);
    const emailVerification = app.env.EMAIL_VERIFICATION === "on" || app.env.AUTH_CODES_ENABLED === "on";
    const username = await generateUniqueUsername(app.db, email);
    const [user] = await app.db
      .insert(users)
      .values({
        id,
        email,
        username,
        passwordHash,
        displayName: body.display_name ?? null,
        role: "owner",
        plan: "free",
        // Disabling delivery must never count as proof of address ownership.
        emailVerified: false,
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
    if (emailVerification && app.env.AUTH_CODES_ENABLED !== "on") {
      const verify = randomToken();
      await app.db.insert(emailTokens).values({
        id: newId(),
        userId: id,
        purpose: "verify",
        tokenHash: sha256(verify),
        expiresAt: new Date(Date.now() + TOKEN_TTL_MS),
      });
      try {
        await app.mailer.sendVerification(email, verify);
      } catch (err) {
        app.log.error({ err, userId: id }, "verification email send failed; signup continues");
      }
    }
    const session = await issueSession(app, user);
    return reply.code(201).send(session);
  });

  app.post("/auth/login", { config: { public: true } }, async (request) => {
    const body = loginBody.parse(request.body);
    if (app.env.AUTH_CODES_ENABLED === "on") {
      await authLimit(app.db, `login-ip:${request.ip}`, 60);
      await authLimit(app.db, `login-account:${body.email.trim().toLowerCase()}`, 20);
    }
    const identifier = body.email.trim().toLowerCase();
    const [user] = identifier.includes("@")
      ? await app.db.select().from(users).where(eq(users.email, identifier)).limit(1)
      : await app.db.select().from(users).where(eq(users.username, identifier)).limit(1);
    if (!user || !(await verifyPassword(body.password, user.passwordHash))) {
      throw new AppError(401, "invalid_credentials", "Invalid credentials");
    }
    if (user.status === "deactivated") {
      throw new AppError(401, "deactivated", "Account is deactivated");
    }
    if (user.role === "admin") {
      if (body.surface !== "owner") throw new AppError(403, "forbidden", "Business audiences are for their provisioned accounts");
      return issueSession(app, user);
    }
    if (body.surface === "workshop") {
      const [workshop] = await app.db.select({ member: workshopMembers, partner: partners })
        .from(workshopMembers)
        .innerJoin(partners, eq(workshopMembers.partnerId, partners.id))
        .where(and(eq(workshopMembers.userId, user.id), eq(partners.type, "workshop"), eq(partners.status, "verified")))
        .limit(1);
      if (!workshop) throw new AppError(403, "workshop_access_required", "A verified workshop account is required");
      return issueSession(app, user, app.env.JWT_WORKSHOP_AUD);
    }
    if (body.surface === "fleet") {
      const memberships = await app.db
        .select({ role: organizationMembers.role, org: organizations })
        .from(organizationMembers)
        .innerJoin(organizations, eq(organizationMembers.orgId, organizations.id))
        .where(and(
          eq(organizationMembers.userId, user.id),
          eq(organizations.plan, "enterprise"),
          eq(organizations.status, "active"),
        ));
      if (!memberships.length) throw new AppError(403, "fleet_access_required", "An active Enterprise organization membership is required");
      if (memberships.every((m) => m.role === "org_driver")) {
        throw new AppError(403, "portal_access_restricted", "Drivers do not use the Fleet Portal");
      }
      return issueSession(app, user, app.env.JWT_FLEET_AUD);
    }
    return issueSession(app, user, app.env.JWT_OWNER_AUD);
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
    if (!user || user.status === "deactivated" || Number(payload.ver ?? 0) !== user.authVersion) throw new AppError(401, "invalid_refresh", "Refresh token is invalid");
    return issueSession(app, user, stored.audience, Number(payload.auth_time ?? payload.iat ?? 0));
  });

  app.post("/auth/logout", { config: { public: true } }, async (request, reply) => {
    const parsedBody = z
      .object({ refresh_token: z.string().optional() })
      .safeParse(request.body ?? {});
    const refreshToken = parsedBody.success ? parsedBody.data.refresh_token : undefined;

    const token = bearer(request);
    if (token) {
      let claims;
      try {
        claims = await verifyAccess(app.env, token);
      } catch {
        throw new AppError(401, "unauthorized", "Invalid access token");
      }
      await app.db
        .update(refreshTokens)
        .set({ revokedAt: new Date() })
        .where(eq(refreshTokens.userId, claims.sub));
      return reply.code(204).send();
    }

    if (refreshToken) {
      let payload;
      try {
        payload = await verifyRefresh(app.env, refreshToken);
      } catch {
        throw new AppError(401, "invalid_refresh", "Refresh token is invalid");
      }
      await app.db
        .update(refreshTokens)
        .set({ revokedAt: new Date() })
        .where(and(eq(refreshTokens.id, payload.jti), eq(refreshTokens.userId, payload.sub)));
      return reply.code(204).send();
    }

    throw new AppError(401, "unauthorized", "Missing access token");
  });

  app.post("/auth/change-password", async (request, reply) => {
    const body = z
      .object({
        current_password: z.string().min(1),
        new_password: z.string().min(8),
      })
      .parse(request.body);
    const userId = request.authUser!.sub;
    const [user] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!user) throw new AppError(401, "unauthorized", "Invalid access token");
    if (!(await verifyPassword(body.current_password, user.passwordHash))) {
      throw new AppError(401, "invalid_password", "Current password is incorrect");
    }
    const [updated] = await app.db
      .update(users)
      .set({ passwordHash: await hashPassword(body.new_password), mustChangePassword: false })
      .where(eq(users.id, userId))
      .returning();
    await app.db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(eq(refreshTokens.userId, userId));
    await recordChange(app.db, {
      userId,
      entityType: "user",
      entityId: userId,
      op: "upsert",
      payload: publicUser(updated),
    });
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
    await app.db.transaction(async (tx) => {
      await tx.select().from(users).where(eq(users.id, row.userId)).for("update");
      const used = await tx.update(emailTokens).set({ usedAt: new Date() }).where(and(eq(emailTokens.id, row.id), isNull(emailTokens.usedAt), gt(emailTokens.expiresAt, new Date()))).returning();
      if (!used.length) throw new AppError(400, "invalid_token", "Verification token is invalid");
      await tx.update(users).set({ emailVerified: true }).where(eq(users.id, row.userId));
    });
    return reply.code(204).send();
  });

  app.post("/auth/resend-verification", async (request, reply) => {
    const userId = request.authUser!.sub;
    if (app.env.AUTH_CODES_ENABLED === "on") await authLimit(app.db, `legacy-verify:${userId}`, 5);
    const [user] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (user && !user.emailVerified && user.email) {
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
    if (app.env.AUTH_CODES_ENABLED === "on") {
      await authLimit(app.db, `legacy-reset:${body.email.toLowerCase()}`, 5);
      await authLimit(app.db, `legacy-reset-ip:${request.ip}`, 20);
    }
    const [user] = await app.db.select().from(users).where(eq(users.email, body.email.toLowerCase())).limit(1);
    if (user?.passwordHash) {
      const token = randomToken();
      await app.db.insert(emailTokens).values({
        id: newId(),
        userId: user.id,
        purpose: "reset",
        tokenHash: sha256(token),
        expiresAt: new Date(Date.now() + TOKEN_TTL_MS),
      });
      await app.mailer.sendPasswordReset(body.email.toLowerCase(), token);
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
    const passwordHash = await hashPassword(body.password);
    await app.db.transaction(async (tx) => {
      const [account] = await tx.select().from(users).where(eq(users.id, row.userId)).for("update");
      if (!account?.passwordHash) throw new AppError(400, "invalid_token", "Reset token is invalid");
      const used = await tx.update(emailTokens).set({ usedAt: new Date() }).where(and(eq(emailTokens.id, row.id), isNull(emailTokens.usedAt))).returning();
      if (!used.length) throw new AppError(400, "invalid_token", "Reset token is invalid");
      await tx.update(users).set({ passwordHash, authVersion: sql`${users.authVersion} + 1` }).where(eq(users.id, row.userId));
      await tx.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.userId, row.userId));
    });
    return reply.code(204).send();
  });
};

export async function attachAuth(app: Parameters<FastifyPluginAsync>[0]): Promise<void> {
  const publicPaths = new Set([
    "/health",
    "/ready",
    "/auth/signup",
    "/auth/login",
    "/auth/refresh",
    "/auth/verify-email",
    "/auth/forgot-password",
    "/auth/reset-password",
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
      const [account] = await app.db.select().from(users).where(eq(users.id, claims.sub));
      if (!account || account.status !== "active" || (claims.ver ?? 0) !== account.authVersion) throw new Error("revoked");
      request.authUser = claims as AccessClaims & { sub: string };
    } catch {
      throw new AppError(401, "unauthorized", "Invalid access token");
    }
  });
}

export function requireOwner(request: { authUser?: AccessClaims & { sub: string } }) {
  if (!request.authUser) throw new AppError(401, "unauthorized", "Missing access token");
  if (request.authUser.role !== "owner" || request.authUser.surface !== "owner") {
    throw new AppError(403, "forbidden", "Owner audience required");
  }
}

export function requireAdmin(request: { authUser?: AccessClaims & { sub: string } }, adminAud: string) {
  if (!request.authUser) throw new AppError(401, "unauthorized", "Missing access token");
  if (request.authUser.role !== "admin" || request.authUser.aud !== adminAud) {
    throw new AppError(403, "forbidden", "Admin role required");
  }
}

export function requireFleetClient(request: { authUser?: AccessClaims & { sub: string } }) {
  if (!request.authUser) throw new AppError(401, "unauthorized", "Missing access token");
  if (request.authUser.role !== "owner" || (request.authUser.surface !== "owner" && request.authUser.surface !== "fleet")) {
    throw new AppError(403, "forbidden", "Owner or Fleet audience required");
  }
}

export function requireWorkshopClient(request: { authUser?: AccessClaims & { sub: string } }) {
  if (!request.authUser) throw new AppError(401, "unauthorized", "Missing access token");
  if (request.authUser.role !== "owner" || request.authUser.surface !== "workshop") {
    throw new AppError(403, "forbidden", "Workshop audience required");
  }
}

async function issueSession(
  app: { env: import("../config/env.js").Env; db: import("../db/client.js").Db },
  user: typeof users.$inferSelect,
  audience = user.role === "admin" ? app.env.JWT_ADMIN_AUD : app.env.JWT_OWNER_AUD,
  authTime = Math.floor(Date.now() / 1000),
) {
  const access = await signAccess(app.env, {
    sub: user.id,
    role: user.role,
    plan: user.plan,
    aud: audience,
    ver: user.authVersion,
    auth_time: authTime,
  });
  const jti = newId();
  const refresh = await signRefresh(app.env, user.id, jti, authTime, user.authVersion);
  await app.db.insert(refreshTokens).values({
    id: jti,
    userId: user.id,
    audience,
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
