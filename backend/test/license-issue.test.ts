import { createPublicKey } from "node:crypto";
import { jwtVerify } from "jose";
import { describe, expect, it } from "vitest";
import { issueLicense, LICENSE_GRACE_DAYS, LICENSE_ISSUER, pemFromBase64Url } from "../src/lib/license.js";
import { PLANS } from "../src/lib/plans.js";
import { createTestApp, testEnv, uuid } from "./helpers.js";

async function signup(app: { inject: Function }, label: string) {
  const email = `${label}-${uuid()}@test.local`;
  const response = await app.inject({
    method: "POST",
    url: "/v1/auth/signup",
    payload: { email, password: "password1", display_name: label },
  }) as { statusCode: number; json: () => { access_token: string; user: { id: string } } };
  expect(response.statusCode).toBe(201);
  return { id: response.json().user.id, token: response.json().access_token };
}

async function adminToken(app: { inject: Function }) {
  const response = await app.inject({
    method: "POST",
    url: "/v1/auth/login",
    payload: { email: testEnv.BOOTSTRAP_ADMIN_EMAIL, password: testEnv.BOOTSTRAP_ADMIN_PASSWORD },
  }) as { statusCode: number; json: () => { access_token: string } };
  expect(response.statusCode).toBe(200);
  return response.json().access_token;
}

const auth = (token: string) => ({ authorization: `Bearer ${token}` });

const publicKey = createPublicKey(pemFromBase64Url(testEnv.LICENSE_ED25519_KEY!));

async function fetchLicense(app: { inject: Function }, token: string) {
  const response = await app.inject({ method: "GET", url: "/v1/me/license", headers: auth(token) });
  expect(response.statusCode).toBe(200);
  return (response.json() as { license: string }).license;
}

describe("offline entitlement license (GET /v1/me/license)", () => {
  it("requires an owner access token", async () => {
    const { app } = await createTestApp();

    const anonymous = await app.inject({ method: "GET", url: "/v1/me/license" });
    expect(anonymous.statusCode).toBe(401);

    const admin = await adminToken(app);
    const adminAttempt = await app.inject({ method: "GET", url: "/v1/me/license", headers: auth(admin) });
    expect(adminAttempt.statusCode).toBe(403);
  });

  it("issues an EdDSA license whose claims mirror the free plan registry", async () => {
    const { app } = await createTestApp();
    const owner = await signup(app, "lic-free");

    const license = await fetchLicense(app, owner.token);
    const { payload, protectedHeader } = await jwtVerify(license, publicKey, { algorithms: ["EdDSA"] });

    expect(protectedHeader.alg).toBe("EdDSA");
    expect(protectedHeader.kid).toBe(testEnv.LICENSE_KID);
    expect(payload.iss).toBe(LICENSE_ISSUER);
    expect(payload.sub).toBe(owner.id);

    const plan = PLANS.free;
    expect(payload.plan_id).toBe("free");
    expect(payload.vehicle_limit).toBe(plan.vehicleLimit);
    expect(payload.sharing_limit).toBe(plan.sharingLimit);
    expect(payload.storage_bytes).toBe(plan.storageBytes);
    expect(payload.ai_tier).toBe(plan.aiTier);
    expect(payload.features).toEqual({ ...plan.features });
    expect(payload.period_end).toBeNull();
    expect(payload.exp! - payload.iat!).toBe(testEnv.LICENSE_TTL_DAYS * 86_400);
  });

  it("re-issues with updated claims after an admin plan change", async () => {
    const { app } = await createTestApp();
    const owner = await signup(app, "lic-std");
    const admin = await adminToken(app);

    const patched = await app.inject({
      method: "PATCH",
      url: `/v1/admin/users/${owner.id}`,
      headers: auth(admin),
      payload: { plan: "standard" },
    });
    expect(patched.statusCode).toBe(200);

    const license = await fetchLicense(app, owner.token);
    const { payload } = await jwtVerify(license, publicKey, { algorithms: ["EdDSA"] });

    expect(payload.plan_id).toBe("standard");
    expect(payload.vehicle_limit).toBe(PLANS.standard.vehicleLimit);
    expect(payload.sharing_limit).toBeNull();
    expect(payload.features).toEqual({ ...PLANS.standard.features });
  });

  it("rejects a tampered signature", async () => {
    const { app } = await createTestApp();
    const owner = await signup(app, "lic-tamper");
    const license = await fetchLicense(app, owner.token);

    // Flip the first signature char — trailing chars can be base64url
    // padding bits that decode to identical bytes.
    const [header, payload, signature] = license.split(".");
    const flipped = (signature[0] === "A" ? "B" : "A") + signature.slice(1);
    await expect(
      jwtVerify(`${header}.${payload}.${flipped}`, publicKey, { algorithms: ["EdDSA"] }),
    ).rejects.toThrow();
  });
});

describe("issueLicense (unit)", () => {
  it("bakes period_end + 7d grace into exp when a billing period exists", async () => {
    const periodEnd = new Date("2026-11-01T00:00:00Z");
    const { license } = await issueLicense(testEnv, { userId: uuid(), plan: "lite", periodEnd });
    const { payload } = await jwtVerify(license, publicKey, { algorithms: ["EdDSA"] });

    expect(payload.period_end).toBe(periodEnd.toISOString());
    expect(new Date(payload.exp! * 1000)).toEqual(
      new Date(periodEnd.getTime() + LICENSE_GRACE_DAYS * 86_400_000),
    );
  });

  it("falls back to the rolling TTL while billing is absent", async () => {
    const now = new Date("2026-10-09T12:00:00Z");
    const { license } = await issueLicense(testEnv, { userId: uuid(), plan: "free", now });
    const { payload } = await jwtVerify(license, publicKey, { algorithms: ["EdDSA"] });

    expect(payload.iat).toBe(Math.floor(now.getTime() / 1000));
    expect(payload.exp! - payload.iat!).toBe(30 * 86_400);
  });

  it("returns 503 license_unavailable when no signing key is configured", async () => {
    const unconfigured = { ...testEnv, LICENSE_ED25519_KEY: undefined };
    await expect(issueLicense(unconfigured, { userId: uuid(), plan: "free" })).rejects.toMatchObject({
      statusCode: 503,
      code: "license_unavailable",
    });
  });
});
