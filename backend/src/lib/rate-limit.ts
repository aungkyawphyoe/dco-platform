import { sql } from "drizzle-orm";
import type { FastifyInstance } from "fastify";
import type { Db } from "../db/client.js";
import { authLimits } from "../db/schema.js";
import { sha256 } from "./crypto.js";
import { AppError } from "./errors.js";

// Atomic PostgreSQL counters are shared by all API replicas. Blocked requests
// neither extend the window nor grow the counter indefinitely.
export async function authLimit(db: Db, key: string, max: number, seconds = 3600) {
  let row: typeof authLimits.$inferSelect;
  try {
    [row] = await db.insert(authLimits).values({
      key: sha256(key), count: 1,
      expiresAt: sql`now() + ${seconds} * interval '1 second'`,
    }).onConflictDoUpdate({ target: authLimits.key, set: {
      count: sql`CASE WHEN ${authLimits.expiresAt} <= now() THEN 1 ELSE LEAST(${authLimits.count} + 1, ${max + 1}) END`,
      expiresAt: sql`CASE WHEN ${authLimits.expiresAt} <= now() THEN now() + ${seconds} * interval '1 second' ELSE ${authLimits.expiresAt} END`,
    } }).returning();
  } catch {
    // Never bypass protection when the shared store is unavailable.
    throw new AppError(503, "rate_limit_unavailable", "Please try again shortly", { retry_after: 30 });
  }
  if (row.count > max) {
    const retryAfter = Math.max(1, Math.min(seconds, Math.ceil((row.expiresAt.getTime() - Date.now()) / 1000)));
    throw new AppError(429, "rate_limited", "Too many requests. Please try again later.", { retry_after: retryAfter });
  }
}

type Policy = { max: number; seconds: number };
const minute = (max: number): Policy => ({ max, seconds: 60 });
const hour = (max: number): Policy => ({ max, seconds: 3600 });

// Keys are registered route templates, not caller-provided URLs or query strings.
// Portal logins/refreshes may share a server/NAT IP; account-level limits below
// the hook protect passwords without a small hourly cap on an entire portal.
export const PUBLIC_RATE_LIMITS: Readonly<Record<string, Policy>> = {
  "/v1/auth/signup": hour(10),
  "/v1/auth/login": minute(120),
  "/v1/auth/forgot-password": hour(20),
  "/v1/auth/reset-password": hour(20),
  "/v1/auth/verify-email": hour(60),
  "/v1/auth/refresh": minute(300),
  "/v1/auth/logout": minute(60),
  "/v1/auth/social/:provider/start": hour(30),
  "/v1/auth/social/:provider/callback": minute(60),
  "/v1/auth/social/complete": hour(60),
  "/v1/auth/recovery-code": hour(30),
  "/v1/auth/recovery-code/confirm": hour(60),
  "/v1/billing/google-play/notifications": minute(600),
};

export async function pruneRateLimits(db: Db) {
  // Bounded, indexed cleanup. Lock skipping lets multiple replicas clean safely.
  await db.execute(sql`DELETE FROM auth_limits WHERE key IN (
    SELECT key FROM auth_limits WHERE expires_at <= now()
    ORDER BY expires_at LIMIT 1000 FOR UPDATE SKIP LOCKED
  )`);
}

export function attachPublicRateLimits(app: FastifyInstance) {
  app.addHook("onRequest", async request => {
    if (!request.routeOptions.config.public || request.method === "OPTIONS") return;
    const route = request.routeOptions.url ?? "unmatched-public";
    // Liveness must work when the DB is down; readiness has its own DB check.
    // These probe endpoints must be restricted/rate-limited at the ingress.
    if (route === "/v1/health" || route === "/v1/ready") return;
    await authLimit(app.db, `public:all:${request.ip}`, 600, 60);
    const policy = PUBLIC_RATE_LIMITS[route] ?? minute(120);
    await authLimit(app.db, `public:${route}:${request.ip}`, policy.max, policy.seconds);
  });

  let pending: Promise<void> | undefined;
  const timer = setInterval(() => {
    if (pending) return;
    pending = pruneRateLimits(app.db)
      .catch(() => { app.log.error("Rate-limit cleanup failed"); })
      .finally(() => { pending = undefined; });
  }, 60_000);
  timer.unref();
  app.addHook("onClose", async () => { clearInterval(timer); await pending; });
}
