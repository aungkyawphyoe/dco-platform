import { describe, expect, it } from "vitest";
import { createTestApp, testEnv, uuid } from "./helpers.js";
import { storeWithQuota, storageUsage } from "../src/lib/storage.js";

async function signup(app: { inject: Function }, label: string) {
  const email = `${label}-${uuid()}@test.local`;
  const response = await app.inject({
    method: "POST",
    url: "/v1/auth/signup",
    payload: { email, password: "password1", display_name: label },
  }) as { statusCode: number; json: () => { access_token: string; user: { id: string } } };
  expect(response.statusCode).toBe(201);
  return { email, id: response.json().user.id, token: response.json().access_token };
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

async function createVehicle(app: { inject: Function }, token: string, label: string) {
  const vehicleId = uuid();
  const vehicle = await app.inject({
    method: "POST",
    url: "/v1/vehicles",
    headers: auth(token),
    payload: {
      id: vehicleId, name: `${label} Car`, make: "Toyota", model: "Corolla", year: 2021,
      license_plate: `${label.slice(0, 3).toUpperCase()}${vehicleId.slice(0, 4)}`,
      vin: vehicleId.replaceAll("-", "").slice(0, 17),
      fuel_type: "petrol", mileage: 5000,
    },
  });
  expect(vehicle.statusCode).toBe(201);
  return vehicleId;
}

describe("driving licenses (standalone module)", () => {
  it("creates, reads, and updates the caller's license", async () => {
    const { app, db } = await createTestApp();
    const owner = await signup(app, "lic-owner");

    const missing = await app.inject({ method: "GET", url: "/v1/users/me/license", headers: auth(owner.token) });
    expect(missing.statusCode).toBe(404);

    const missingFront = await app.inject({ method: "PUT", url: "/v1/users/me/license", headers: auth(owner.token), payload: {} });
    expect(missingFront.statusCode).toBe(422);
    const front = await storeWithQuota(db, app.media, { id: uuid(), owner: { userId: owner.id }, purpose: "license_front", bytes: Buffer.from([255,216,255]), contentType: "image/jpeg" });
    const created = await app.inject({
      method: "PUT",
      url: "/v1/users/me/license",
      headers: auth(owner.token),
      payload: {
        front_media_id: front.id,
        license_number: "AB123456",
        issuing_country: "US",
        expiry_date: "2030-05-20",
        categories: "B,C",
      },
    });
    expect(created.statusCode).toBe(200);
    const licenseId = created.json().id as string;

    const read = await app.inject({ method: "GET", url: "/v1/users/me/license", headers: auth(owner.token) });
    expect(read.statusCode).toBe(200);
    expect(read.json().license_number).toBe("AB123456");
    expect(read.json().expiry_date).toBe("2030-05-20");

    const updated = await app.inject({
      method: "PUT",
      url: "/v1/users/me/license",
      headers: auth(owner.token),
      payload: { license_number: "XY987654", issuing_country: "US", expiry_date: "2031-01-01", categories: "B" },
    });
    expect(updated.statusCode).toBe(200);
    expect(updated.json().id).toBe(licenseId);
    expect(updated.json().license_number).toBe("XY987654");

    const noExpiry = await app.inject({ method: "PUT", url: "/v1/users/me/license", headers: auth(owner.token), payload: { expiry_date: null } });
    expect(noExpiry.statusCode).toBe(200);
    expect(noExpiry.json().expiry_date).toBeNull();
    const impossibleDate = await app.inject({ method: "PUT", url: "/v1/users/me/license", headers: auth(owner.token), payload: { expiry_date: "2030-02-30" } });
    expect(impossibleDate.statusCode).toBe(400);

    const expired = await app.inject({
      method: "PUT",
      url: "/v1/users/me/license",
      headers: auth(owner.token),
      payload: { expiry_date: "2020-01-01" },
    });
    expect(expired.statusCode).toBe(400);
    const replacement = await storeWithQuota(db, app.media, { id: uuid(), owner: { userId: owner.id }, purpose: "license_front", bytes: Buffer.from([255,216,255,0]), contentType: "image/jpeg" });
    const replaced = await app.inject({ method: "PUT", url: "/v1/users/me/license", headers: auth(owner.token), payload: { front_media_id: replacement.id } });
    expect(replaced.statusCode, replaced.body).toBe(200);
    expect((await storageUsage(db, { userId: owner.id })).used_bytes).toBe(4);
    expect((await app.inject({ method: "DELETE", url: "/v1/users/me/license", headers: auth(owner.token) })).statusCode).toBe(204);
    expect((await storageUsage(db, { userId: owner.id })).used_bytes).toBe(0);
    expect((await app.inject({ method: "GET", url: "/v1/users/me/license", headers: auth(owner.token) })).statusCode).toBe(404);
  });

  it("keeps licenses private even with an active vehicle share", async () => {
    const { app, db } = await createTestApp();
    const admin = await adminToken(app);
    const owner = await signup(app, "lic-share-owner");
    const member = await signup(app, "lic-share-member");
    const stranger = await signup(app, "lic-share-stranger");

    await app.inject({
      method: "PATCH",
      url: `/v1/admin/users/${owner.id}`,
      headers: auth(admin),
      payload: { plan: "standard" },
    });

    const vehicleId = await createVehicle(app, owner.token, "LIC");
    const front = await storeWithQuota(db, app.media, { id: uuid(), owner: { userId: owner.id }, purpose: "license_front", bytes: Buffer.from([255,216,255]), contentType: "image/jpeg" });

    await app.inject({
      method: "PUT",
      url: "/v1/users/me/license",
      headers: auth(owner.token),
      payload: { front_media_id: front.id, license_number: "SH123456", issuing_country: "US", expiry_date: "2032-09-09" },
    });

    const strangerRead = await app.inject({
      method: "GET",
      url: `/v1/users/${owner.id}/license`,
      headers: auth(stranger.token),
    });
    expect(strangerRead.statusCode).toBe(403);

    const share = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
      payload: { method: "email", email: member.email, access_level: "view" },
    });
    expect(share.statusCode).toBe(201);
    const inviteToken = share.json().invite_token as string;

    const accept = await app.inject({
      method: "POST",
      url: "/v1/vehicles/shares/accept",
      headers: auth(member.token),
      payload: { token: inviteToken },
    });
    expect(accept.statusCode).toBe(200);

    const memberRead = await app.inject({
      method: "GET",
      url: `/v1/users/${owner.id}/license`,
      headers: auth(member.token),
    });
    expect(memberRead.statusCode).toBe(403);
    expect(memberRead.json().error.code).toBe("private_document");
    const detail = await app.inject({ method: "GET", url: `/v1/users/${owner.id}/detail`, headers: auth(member.token) });
    expect(detail.statusCode).toBe(200);
    expect(detail.json().driving_license).toBeNull();

    const selfRead = await app.inject({
      method: "GET",
      url: `/v1/users/${owner.id}/license`,
      headers: auth(owner.token),
    });
    expect(selfRead.statusCode).toBe(200);
  });
});
