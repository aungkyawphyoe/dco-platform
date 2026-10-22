import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { eq } from "drizzle-orm";
import { decodeJwt } from "jose";
import { createTestApp, testEnv, uuid } from "./helpers.js";
import { playSubscriptions, users } from "../src/db/schema.js";
import { effectiveSubscription } from "../src/lib/gifts.js";
import { GooglePlayGateway, playAccountId, verifiedPlayLine, type PlayPurchase } from "../src/lib/google-play.js";
import { syncPlayPurchase } from "../src/lib/play-subscriptions.js";
import { issueLicense } from "../src/lib/license.js";
import { signAccess } from "../src/lib/crypto.js";

function purchase(id: string, state = "SUBSCRIPTION_STATE_ACTIVE", expiry = new Date(Date.now() + 30 * 86400000)): PlayPurchase {
  return { subscriptionState: state, acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
    externalAccountIdentifiers: { obfuscatedExternalAccountId: playAccountId(id) },
    lineItems: [{ productId: "autox_standard", expiryTime: expiry.toISOString(), offerDetails: { basePlanId: "monthly" }, autoRenewingPlan: { autoRenewEnabled: true } }] };
}
describe("Google Play subscriptions", () => {
  let ctx: Awaited<ReturnType<typeof createTestApp>>;
  beforeAll(async () => { ctx = await createTestApp(); });
  afterAll(async () => { await ctx.app.close(); await ctx.client.close(); });
  async function owner() {
    const id = uuid();
    await ctx.db.insert(users).values({ id, email: `${id}@test.local`, username: id, passwordHash: "unused", role: "owner", plan: "free", emailVerified: true });
    return id;
  }
  it("grants only active/grace/canceled-unexpired states", () => {
    for (const state of ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "SUBSCRIPTION_STATE_CANCELED"]) {
      expect(verifiedPlayLine(purchase("u", state), playAccountId("u")).entitled).toBe(true);
    }
    for (const state of ["SUBSCRIPTION_STATE_PENDING", "SUBSCRIPTION_STATE_ON_HOLD", "SUBSCRIPTION_STATE_PAUSED", "SUBSCRIPTION_STATE_EXPIRED", "UNKNOWN"]) {
      expect(verifiedPlayLine(purchase("u", state), playAccountId("u")).entitled).toBe(false);
    }
    expect(verifiedPlayLine(purchase("u", undefined, new Date(0)), playAccountId("u")).entitled).toBe(false);
    expect(() => verifiedPlayLine(purchase("u"), playAccountId("other"))).toThrow();
    const invalid = purchase("u"); invalid.lineItems![0].productId = "invented";
    expect(() => verifiedPlayLine(invalid, playAccountId("u"))).toThrow();
    invalid.lineItems![0].productId = "autox_lite"; invalid.lineItems![0].offerDetails!.basePlanId = "invented";
    expect(() => verifiedPlayLine(invalid, playAccountId("u"))).toThrow();
  });
  it("persists before acknowledgement, retries idempotently, and rejects account transfers", async () => {
    const id = await owner(); const token = uuid();
    const gateway = { get: vi.fn(async () => purchase(id)), acknowledge: vi.fn(async () => {
      expect((await effectiveSubscription(ctx.db, id)).plan).toBe("standard");
    }) };
    expect(await syncPlayPurchase(ctx.db, gateway, id, token)).toMatchObject({ verified: true, entitled: true, acknowledged: true });
    expect(await syncPlayPurchase(ctx.db, gateway, id, token)).toMatchObject({ entitled: true });
    expect(await ctx.db.select().from(playSubscriptions).where(eq(playSubscriptions.purchaseToken, token))).toHaveLength(1);
    await expect(syncPlayPurchase(ctx.db, gateway, await owner(), token)).rejects.toMatchObject({ code: "purchase_account_mismatch" });
    const [base] = await ctx.db.select().from(users).where(eq(users.id, id)); expect(base.plan).toBe("free");
  });
  it("withholds acknowledgement for pending/invalid purchases and preserves durable retry on ack failure", async () => {
    const id = await owner(); const token = uuid();
    const gateway = { get: vi.fn(async () => purchase(id, "SUBSCRIPTION_STATE_PENDING")), acknowledge: vi.fn(async () => {}) };
    expect((await syncPlayPurchase(ctx.db, gateway, id, token)).entitled).toBe(false);
    expect(gateway.acknowledge).not.toHaveBeenCalled();
    gateway.get.mockImplementation(async () => purchase(id));
    gateway.acknowledge.mockRejectedValueOnce(new Error("network"));
    await expect(syncPlayPurchase(ctx.db, gateway, id, token)).rejects.toThrow();
    expect((await effectiveSubscription(ctx.db, id)).plan).toBe("standard");
    await syncPlayPurchase(ctx.db, gateway, id, token);
    expect(gateway.acknowledge).toHaveBeenCalledTimes(2);
  });
  it("refreshes lifecycle from Google, preserves admin plans and caps offline license", async () => {
    const id = await owner(); const token = uuid(); let data = purchase(id);
    const gateway = { get: async () => data, acknowledge: async () => {} };
    await syncPlayPurchase(ctx.db, gateway, id, token);
    let sub = await effectiveSubscription(ctx.db, id);
    const now = new Date();
    const signed = decodeJwt((await issueLicense(testEnv, { userId: id, plan: sub.plan, paidEnd: sub.paidEnd, now })).license);
    expect(signed.exp).toBe(Math.floor((now.getTime() + 86400000) / 1000));
    data = purchase(id, "SUBSCRIPTION_STATE_CANCELED"); await syncPlayPurchase(ctx.db, gateway, id, token);
    expect((await effectiveSubscription(ctx.db, id)).plan).toBe("standard");
    data = purchase(id, "SUBSCRIPTION_STATE_ON_HOLD"); await syncPlayPurchase(ctx.db, gateway, id, token);
    expect((await effectiveSubscription(ctx.db, id)).plan).toBe("free");
    await ctx.db.update(users).set({ plan: "lite" }).where(eq(users.id, id));
    expect((await effectiveSubscription(ctx.db, id)).plan).toBe("lite");
    data = purchase(id, "SUBSCRIPTION_STATE_EXPIRED", new Date(0)); await syncPlayPurchase(ctx.db, gateway, id, token);
    expect((await effectiveSubscription(ctx.db, id)).plan).toBe("lite");
  });
  it("fails closed before configuration and authenticates notification endpoint", async () => {
    const id = await owner();
    const headers = { authorization: `Bearer ${(await signAccess(testEnv, { sub: id, role: "owner", plan: "free" })).token}` };
    const config = await ctx.app.inject({ method: "GET", url: "/v1/me/play-billing", headers });
    expect(config.json()).toMatchObject({ enabled: false, can_purchase: false, account_id: playAccountId(id) });
    expect((await ctx.app.inject({ method: "POST", url: "/v1/me/play-purchases", headers, payload: { purchase_token: "x" } })).statusCode).toBe(503);
    expect((await ctx.app.inject({ method: "POST", url: "/v1/me/play-purchases", payload: { purchase_token: "x" } })).statusCode).toBe(401);
    expect((await ctx.app.inject({ method: "POST", url: "/v1/billing/google-play/notifications", payload: {} })).statusCode).toBe(503);
  });
  it("verifies through the owner endpoint and rejects unauthenticated RTDN even when enabled", async () => {
    const id = await owner();
    const headers = { authorization: `Bearer ${(await signAccess(testEnv, { sub: id, role: "owner", plan: "free" })).token}` };
    const previous = { ...ctx.app.env };
    ctx.app.env.PLAY_BILLING_ENABLED = "on";
    ctx.app.env.PLAY_SERVICE_ACCOUNT_JSON = "{}";
    ctx.app.env.PLAY_RTDN_AUDIENCE = "https://example.test/v1/billing/google-play/notifications";
    ctx.app.env.PLAY_RTDN_SERVICE_ACCOUNT = "push@example.test";
    const get = vi.spyOn(GooglePlayGateway.prototype, "get").mockResolvedValue(purchase(id));
    const acknowledge = vi.spyOn(GooglePlayGateway.prototype, "acknowledge").mockResolvedValue();
    try {
      expect((await ctx.app.inject({ method: "GET", url: "/v1/me/play-billing", headers })).json().can_purchase).toBe(true);
      const result = await ctx.app.inject({ method: "POST", url: "/v1/me/play-purchases", headers, payload: { purchase_token: uuid() } });
      expect(result.statusCode, result.body).toBe(200);
      expect(result.json()).toEqual({ verified: true, entitled: true, acknowledged: true });
      expect(acknowledge).toHaveBeenCalledOnce();
      ctx.app.env.PLAY_BILLING_ENABLED = "off";
      expect((await ctx.app.inject({ method: "POST", url: "/v1/me/play-purchases", headers, payload: { purchase_token: uuid() } })).statusCode).toBe(200);

      expect((await ctx.app.inject({ method: "GET", url: "/v1/me/play-billing", headers })).json().can_purchase).toBe(false);
      const status = (await ctx.app.inject({ method: "GET", url: "/v1/me/subscription", headers })).json();
      expect(status.plan).toBe("standard"); expect(status.play.product_id).toBe("autox_standard");
      expect(JSON.stringify(status)).not.toContain("purchase_token");
      expect((await ctx.app.inject({ method: "POST", url: "/v1/billing/google-play/notifications", payload: {} })).statusCode).toBe(401);
      expect((await ctx.app.inject({ method: "POST", url: "/v1/billing/google-play/notifications", headers, payload: {} })).statusCode).toBe(401);
    } finally {
      get.mockRestore(); acknowledge.mockRestore(); Object.assign(ctx.app.env, previous);
    }
  });

});
