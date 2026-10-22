import { beforeAll, afterAll, describe, expect, it } from "vitest";
import { eq } from "drizzle-orm";
import { decodeJwt } from "jose";
import { createTestApp, testEnv, uuid } from "./helpers.js";
import { giftGrants, users, promotions, organizations, organizationMembers, vehicles, vehicleShares } from "../src/db/schema.js";
import { signAccess } from "../src/lib/crypto.js";
import { effectiveSubscription } from "../src/lib/gifts.js";
import { storageUsage } from "../src/lib/storage.js";

describe("subscription gifts", () => {
  let ctx: Awaited<ReturnType<typeof createTestApp>>;
  let admin: { authorization: string };
  beforeAll(async () => {
    ctx = await createTestApp();
    const [row] = await ctx.db.select().from(users).where(eq(users.role, "admin"));
    admin = { authorization: `Bearer ${(await signAccess(testEnv, { sub: row.id, role: "admin", plan: "free", aud: testEnv.JWT_ADMIN_AUD })).token}` };
  });
  afterAll(async () => { await ctx.app.close(); await ctx.client.close(); });
  async function owner(verified = true, plan: "free" | "lite" = "free") {
    const id = uuid();
    await ctx.db.insert(users).values({ id, email: `${id}@test.local`, username: id, passwordHash: "unused", role: "owner", plan, emailVerified: verified });
    return { id, headers: { authorization: `Bearer ${(await signAccess(testEnv, { sub: id, role: "owner", plan })).token}` } };
  }
  async function campaign(kind = "shared", capacity = 2) {
    const res = await ctx.app.inject({ method: "POST", url: "/v1/admin/promotions", headers: admin,
      payload: { name: "Launch", kind, capacity, plan: "standard", duration_days: 90, redeem_by: new Date(Date.now() + 86400000).toISOString() } });
    expect(res.statusCode, res.body).toBe(201);
    return res.json();
  }
  async function redeem(o: Awaited<ReturnType<typeof owner>>, code: string, requestId = uuid()) {
    return ctx.app.inject({ method: "POST", url: "/v1/me/gift-redemptions", headers: o.headers, payload: { code, request_id: requestId } });
  }
  it("activates effective limits, signs an exact expiry, replays safely, and preserves admin plans", async () => {
    const o = await owner(); const c = await campaign(); const requestId = uuid();
    const result = await redeem(o, c.codes[0].toLowerCase(), requestId);
    expect(result.statusCode, result.body).toBe(200);
    const gift = result.json().gift;
    expect(new Date(gift.ends_at).getTime() - new Date(gift.starts_at).getTime()).toBe(90 * 86400000);
    expect((await redeem(o, c.codes[0], requestId)).json()).toMatchObject({ gift, replayed: true });
    expect((await effectiveSubscription(ctx.db, o.id)).plan).toBe("standard");
    expect((await storageUsage(ctx.db, { userId: o.id })).limit_bytes).toBe(500 * 1024 * 1024);
    const license = await ctx.app.inject({ method: "GET", url: "/v1/me/license", headers: o.headers });
    const claims = decodeJwt(license.json().license);
    expect(claims.plan_id).toBe("standard");
    expect(claims.exp).toBe(Math.floor(new Date(gift.ends_at).getTime() / 1000));
    expect(claims.gift_end).toBe(gift.ends_at);
    await ctx.db.update(users).set({ plan: "lite" }).where(eq(users.id, o.id));
    expect((await effectiveSubscription(ctx.db, o.id, new Date(Date.now() + 100 * 86400000))).plan).toBe("lite");
  });
  it("enforces verification, Free eligibility, one active gift and one redemption per promotion", async () => {
    const c = await campaign("single_use", 3); const o = await owner(false);
    expect((await redeem(o, c.codes[0])).json().error.code).toBe("email_verification_required");
    const paid = await owner(true, "lite");
    expect((await redeem(paid, c.codes[0])).json().error.code).toBe("plan_ineligible");
    await ctx.db.update(users).set({ emailVerified: true }).where(eq(users.id, o.id));
    expect((await redeem(o, c.codes[0])).statusCode).toBe(200);
    expect((await redeem(o, c.codes[1])).json().error.code).toBe("gift_active");
    await ctx.db.update(giftGrants).set({ startsAt: new Date(Date.now() - 2 * 86400000), endsAt: new Date(Date.now() - 1000) }).where(eq(giftGrants.userId, o.id));
    expect((await effectiveSubscription(ctx.db, o.id)).plan).toBe("free");
    expect((await redeem(o, c.codes[1])).json().error.code).toBe("promotion_redeemed");
    const other = await campaign();
    expect((await redeem(o, other.codes[0])).statusCode).toBe(200);
    expect((await redeem(await owner(), c.codes[1])).statusCode).toBe(200);
  });
  it("serializes the final campaign slot and rejects consumed single-use codes", async () => {
    const c = await campaign("shared", 1); const a = await owner(); const b = await owner();
    const results = await Promise.all([redeem(a, c.codes[0]), redeem(b, c.codes[0])]);
    expect(results.map(r => r.statusCode).sort()).toEqual([200, 422]);
    const batch = await campaign("single_use", 2);
    expect((await redeem(await owner(), batch.codes[0])).statusCode).toBe(200);
    expect((await redeem(await owner(), batch.codes[0])).statusCode).toBe(422);
  });
  it("disable and deadlines block new redemptions without removing existing gifts", async () => {
    const c = await campaign(); const o = await owner();
    await redeem(o, c.codes[0]);
    const res = await ctx.app.inject({ method: "PATCH", url: `/v1/admin/promotions/${c.promotion.id}`, headers: admin, payload: { enabled: false } });
    expect(res.statusCode).toBe(200);
    expect((await redeem(await owner(), c.codes[0])).statusCode).toBe(422);
    expect((await effectiveSubscription(ctx.db, o.id)).plan).toBe("standard");
    const expired = await campaign();
    await ctx.db.update(promotions).set({ redeemBy: new Date(Date.now() - 1) }).where(eq(promotions.id, expired.promotion.id));
    expect((await redeem(await owner(), expired.codes[0])).statusCode).toBe(422);
    const history = await ctx.app.inject({ method: "GET", url: `/v1/admin/promotions/${c.promotion.id}/redemptions`, headers: admin });
    expect(history.json().items).toHaveLength(1);
    expect(history.body).not.toContain(c.codes[0]);
    const forbidden = await ctx.app.inject({ method: "GET", url: "/v1/admin/promotions", headers: o.headers });
    expect(forbidden.statusCode).toBe(403);
  });
  it("blocks drivers, rejects a reused request id with a different code, and records admin actions", async () => {
    const driver = await owner();
    const organizationId = uuid();
    await ctx.db.insert(organizations).values({ id: organizationId, name: "Fleet", type: "taxi_fleet", adminUserId: driver.id, createdBy: driver.id });
    await ctx.db.insert(organizationMembers).values({ id: uuid(), orgId: organizationId, userId: driver.id, role: "org_driver" });
    const c = await campaign("single_use", 2);
    expect((await redeem(driver, c.codes[0])).json().error.code).toBe("personal_garage_forbidden");
    const o = await owner(); const requestId = uuid();
    expect((await redeem(o, c.codes[0], requestId)).statusCode).toBe(200);
    expect((await redeem(o, c.codes[1], requestId)).json().error.code).toBe("request_conflict");
    const list = await ctx.app.inject({ method: "GET", url: "/v1/admin/promotions", headers: admin });
    expect(list.json().items.find((p: { id: string }) => p.id === c.promotion.id).redeemed).toBe(1);
  });

  it("expiry preserves over-limit vehicles and shares but blocks new vehicle admission", async () => {
    const o = await owner(); const c = await campaign();
    await redeem(o, c.codes[0]);
    const vehicleId = uuid();
    for (const id of [vehicleId, uuid()]) {
      await ctx.db.insert(vehicles).values({ id, userId: o.id, name: "Car", make: "Toyota", model: "Camry", year: 2022, licensePlate: id, fuelType: "petrol", mileage: "100" });
    }
    for (let i = 0; i < 2; i++) {
      const recipient = await owner();
      await ctx.db.insert(vehicleShares).values({ id: uuid(), vehicleId, userId: recipient.id, grantedBy: o.id, accessLevel: "view", status: "active" });
    }
    const active = await ctx.app.inject({ method: "GET", url: "/v1/me/entitlements", headers: o.headers });
    expect(active.json().plan).toBe("standard");
    await ctx.db.update(giftGrants).set({ startsAt: new Date(Date.now() - 2 * 86400000), endsAt: new Date(Date.now() - 1000) }).where(eq(giftGrants.userId, o.id));
    const ended = await ctx.app.inject({ method: "GET", url: "/v1/me/entitlements", headers: o.headers });
    expect(ended.json().plan).toBe("free");
    expect(ended.json().vehicle_sharing.active_shares).toBe(2);
    expect(await ctx.db.select().from(vehicles).where(eq(vehicles.userId, o.id))).toHaveLength(2);
    const blocked = await ctx.app.inject({ method: "POST", url: "/v1/vehicles", headers: o.headers, payload: {
      id: uuid(), name: "Extra", make: "Toyota", model: "Camry", year: 2022,
      license_plate: uuid().slice(0, 12), fuel_type: "petrol", mileage: 0, mileage_unit: "mi",
    } });
    expect(blocked.json().error.code).toBe("LIMIT_EXCEEDED");
    expect((await storageUsage(ctx.db, { userId: o.id })).limit_bytes).toBe(50 * 1024 * 1024);
  });

});
