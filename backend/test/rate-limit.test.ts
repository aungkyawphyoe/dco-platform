import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { eq } from "drizzle-orm";
import Fastify from "fastify";
import { createTestApp } from "./helpers.js";
import { buildApp } from "../src/app.js";
import { authLimits } from "../src/db/schema.js";
import { sha256 } from "../src/lib/crypto.js";
import { attachPublicRateLimits, authLimit, pruneRateLimits, PUBLIC_RATE_LIMITS } from "../src/lib/rate-limit.js";

describe("public API rate limits", () => {
  let ctx: Awaited<ReturnType<typeof createTestApp>>;
  beforeEach(async () => {
    ctx = await createTestApp();
    ctx.app.env = { ...ctx.app.env, AUTH_CODES_ENABLED: "off" };
  });
  afterEach(async () => { vi.restoreAllMocks(); await ctx.app.close(); await ctx.client.close(); });

  async function exhaust(key: string, count: number) {
    await ctx.db.insert(authLimits).values({
      key: sha256(key), count, expiresAt: new Date(Date.now() + 60000),
    });
  }

  it.each(["off", "on"] as const)("limits signup before validation with email codes %s", async flag => {
    ctx.app.env.AUTH_CODES_ENABLED = flag;
    for (let i = 0; i < 10; i++) {
      const res = await ctx.app.inject({ method: "POST", url: "/v1/auth/signup", payload: {} });
      expect(res.statusCode).toBe(422);
    }
    const res = await ctx.app.inject({ method: "POST", url: "/v1/auth/signup", payload: {} });
    expect(res.statusCode).toBe(429);
    expect(res.json().error.code).toBe("rate_limited");
    expect(Number(res.headers["retry-after"])).toBeGreaterThan(0);
    expect(res.headers["cache-control"]).toBe("no-store");
  });

  it("shares a login account budget across email and username without email codes", async () => {
    const signup = await ctx.app.inject({ method: "POST", url: "/v1/auth/signup",
      payload: { email: "alias@test.local", password: "Password123!" } });
    const user = signup.json().user;
    await exhaust(`login-account:${user.id}`, 19);
    const attempt = (email: string) => ctx.app.inject({ method: "POST", url: "/v1/auth/login",
      payload: { email, password: "wrong" } });
    expect((await attempt("ALIAS@test.local")).statusCode).toBe(401);
    expect((await attempt(user.username)).statusCode).toBe(429);
  });

  it("limits reset delivery by account across different IPs with email codes off", async () => {
    for (let i = 0; i < 6; i++) {
      const res = await ctx.app.inject({ method: "POST", url: "/v1/auth/forgot-password",
        remoteAddress: `192.0.2.${i + 1}`, payload: { email: "unknown@test.local" } });
      expect(res.statusCode).toBe(i < 5 ? 202 : 429);
    }
  });

  it("covers refresh, reset, OAuth callbacks, billing, pricing and media with stable route keys", async () => {
    const cases = [
      ["POST", "/v1/auth/refresh", "/v1/auth/refresh"],
      ["POST", "/v1/auth/reset-password", "/v1/auth/reset-password"],
      ["GET", "/v1/auth/social/google/callback", "/v1/auth/social/:provider/callback"],
      ["POST", "/v1/billing/google-play/notifications", "/v1/billing/google-play/notifications"],
      ["GET", "/v1/pricing", "/v1/pricing"],
      ["GET", "/v1/media/00000000-0000-4000-8000-000000000001/content", "/v1/media/:mediaId/content"],
    ] as const;
    for (const [method, url, route] of cases) {
      await exhaust(`public:${route}:127.0.0.1`, PUBLIC_RATE_LIMITS[route]?.max ?? 120);
      const res = await ctx.app.inject({ method, url: `${url}?cache_bust=${Math.random()}`,
        headers: { "x-forwarded-for": "198.51.100.20", origin: "http://localhost:5173" } });
      expect(res.statusCode, url).toBe(429);
      expect(res.headers["access-control-expose-headers"]).toContain("Retry-After");
    }
  });

  it("shares counters between replicas and applies an aggregate budget across routes", async () => {
    // Build another replica with the same shared DB; register before ready.
    const replica = await buildApp({ env: ctx.app.env, db: ctx.db, mailer: ctx.app.mailer, media: ctx.app.media });
    try {
      await exhaust("public:/v1/pricing:127.0.0.1", 119);
      expect((await ctx.app.inject({ url: "/v1/pricing" })).statusCode).toBe(200);
      expect((await replica.inject({ url: "/v1/pricing" })).statusCode).toBe(429);
      await ctx.db.delete(authLimits);
      await exhaust("public:all:127.0.0.1", 600);
      expect((await replica.inject({ method: "POST", url: "/v1/auth/refresh" })).statusCode).toBe(429);
      expect((await replica.inject({ url: "/v1/health" })).statusCode).toBe(200);
      expect((await replica.inject({ url: "/v1/ready" })).statusCode).toBe(200);
    } finally { await replica.close(); }
  });

  it("allows a separate client IP and ignores spoofed forwarding headers by default", async () => {
    await exhaust("public:/v1/pricing:127.0.0.1", 120);
    expect((await ctx.app.inject({ url: "/v1/pricing", headers: { "x-forwarded-for": "192.0.2.1" } })).statusCode).toBe(429);
    expect((await ctx.app.inject({ url: "/v1/pricing", remoteAddress: "192.0.2.1" })).statusCode).toBe(200);
  });

  it("gives newly registered public routes the default budget without a policy entry", async () => {
    const app = Fastify();
    app.decorate("db", ctx.db);
    attachPublicRateLimits(app);
    app.get("/v1/new-public/:id", { config: { public: true } }, async () => ({ ok: true }));
    try {
      await exhaust("public:/v1/new-public/:id:127.0.0.1", 119);
      expect((await app.inject({ url: "/v1/new-public/one" })).statusCode).toBe(200);
      expect((await app.inject({ url: "/v1/new-public/two?different=true" })).statusCode).toBe(429);
    } finally { await app.close(); }
  });

  it("atomically bounds concurrent requests and resets expired counters", async () => {
    const results = await Promise.allSettled(Array.from({ length: 12 }, () => authLimit(ctx.db, "parallel", 4, 60)));
    expect(results.filter(r => r.status === "fulfilled")).toHaveLength(4);
    const [row] = await ctx.db.select().from(authLimits).where(eq(authLimits.key, sha256("parallel")));
    expect(row.count).toBe(5);
    await ctx.db.update(authLimits).set({ expiresAt: new Date(0) });
    await expect(authLimit(ctx.db, "parallel", 4, 60)).resolves.toBeUndefined();
    await ctx.db.insert(authLimits).values({ key: sha256("expired"), count: 1, expiresAt: new Date(0) });
    await pruneRateLimits(ctx.db);
    const remaining = await ctx.db.select().from(authLimits);
    expect(remaining).toHaveLength(1);
    expect(remaining[0].key).toBe(sha256("parallel"));
    expect(remaining[0].count).toBe(1);
  });

  it("fails closed on store failure without making liveness depend on counters", async () => {
    vi.spyOn(ctx.db, "insert").mockImplementation(() => { throw new Error("database credentials must not leak"); });
    const res = await ctx.app.inject({ method: "POST", url: "/v1/auth/login" });
    expect(res.statusCode).toBe(503);
    expect(res.json().error.code).toBe("rate_limit_unavailable");
    expect(res.headers["retry-after"]).toBe("30");
    expect(res.body).not.toContain("credentials");
    expect((await ctx.app.inject({ url: "/v1/health" })).statusCode).toBe(200);
  });
});
