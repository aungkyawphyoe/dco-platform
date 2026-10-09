import { describe, expect, it } from "vitest";
import { createTestApp, testEnv, uuid } from "./helpers.js";

async function signup(app: { inject: Function }, label: string) {
  const email = `${label}-${uuid()}@test.local`;
  const res = await app.inject({
    method: "POST",
    url: "/v1/auth/signup",
    payload: { email, password: "password1" },
  }) as { statusCode: number; json: () => { access_token: string; user: { id: string } } };
  expect(res.statusCode).toBe(201);
  return { id: res.json().user.id, token: res.json().access_token };
}

async function adminToken(app: { inject: Function }) {
  const res = await app.inject({
    method: "POST",
    url: "/v1/auth/login",
    payload: { email: testEnv.BOOTSTRAP_ADMIN_EMAIL, password: testEnv.BOOTSTRAP_ADMIN_PASSWORD },
  }) as { statusCode: number; json: () => { access_token: string } };
  expect(res.statusCode).toBe(200);
  return res.json().access_token;
}

async function setPlan(app: { inject: Function }, userId: string, plan: string) {
  const res = await app.inject({
    method: "PATCH",
    url: `/v1/admin/users/${userId}`,
    headers: { authorization: `Bearer ${await adminToken(app)}` },
    payload: { plan },
  });
  expect(res.statusCode).toBe(200);
}

const auth = (token: string) => ({ authorization: `Bearer ${token}` });

function vehiclePayload(id = uuid()) {
  return {
    id,
    name: "Daily",
    make: "Toyota",
    model: "Camry",
    year: 2020,
    license_plate: `ABC${id.slice(0, 4)}`,
    fuel_type: "petrol",
    mileage: 10000,
  };
}

async function createVehicle(app: { inject: Function }, token: string, payload = vehiclePayload()) {
  const res = await app.inject({ method: "POST", url: "/v1/vehicles", headers: auth(token), payload });
  return { statusCode: res.statusCode, body: res.json() as Record<string, unknown>, payload };
}

describe("vehicle plan limit enforcement (POST /v1/vehicles)", () => {
  it("free: 403 LIMIT_EXCEEDED at the cap with pricing.md details, idempotent replay still passes", async () => {
    const { app } = await createTestApp();
    const owner = await signup(app, "lim-free");

    const first = await createVehicle(app, owner.token);
    expect(first.statusCode).toBe(201);

    const blocked = await createVehicle(app, owner.token);
    expect(blocked.statusCode).toBe(403);
    const error = blocked.body.error as { code: string; message: string; details: Record<string, unknown> };
    expect(error.code).toBe("LIMIT_EXCEEDED");
    expect(error.message).toBe("Free plan allows 1 vehicle. Upgrade to Lite for 3 vehicles.");
    expect(error.details).toEqual({
      metric: "vehicles",
      current: 1,
      limit: 1,
      upgrade_url: "/pricing",
    });

    const replay = await createVehicle(app, owner.token, first.payload);
    expect(replay.statusCode).toBe(201);
    await app.close();
  });

  it("archived vehicles do not count toward the cap", async () => {
    const { app } = await createTestApp();
    const owner = await signup(app, "lim-arch");

    const first = await createVehicle(app, owner.token);
    expect(first.statusCode).toBe(201);

    const archived = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${first.payload.id}/archive`,
      headers: auth(owner.token),
    });
    expect(archived.statusCode).toBe(200);

    const second = await createVehicle(app, owner.token);
    expect(second.statusCode).toBe(201);
    await app.close();
  });

  it("lite: caps at 3 with an upgrade message toward Standard", async () => {
    const { app } = await createTestApp();
    const owner = await signup(app, "lim-lite");
    await setPlan(app, owner.id, "lite");

    for (let i = 0; i < 3; i++) {
      expect((await createVehicle(app, owner.token)).statusCode).toBe(201);
    }

    const blocked = await createVehicle(app, owner.token);
    expect(blocked.statusCode).toBe(403);
    const error = blocked.body.error as { code: string; message: string; details: Record<string, unknown> };
    expect(error.code).toBe("LIMIT_EXCEEDED");
    expect(error.message).toBe("Lite plan allows 3 vehicles. Upgrade to Standard for 10 vehicles.");
    expect(error.details).toMatchObject({ current: 3, limit: 3 });
    await app.close();
  });

  it("unlimited tier passes far past any numeric cap", async () => {
    const { app } = await createTestApp();
    const owner = await signup(app, "lim-fleet");
    await setPlan(app, owner.id, "fleet");

    for (let i = 0; i < 12; i++) {
      expect((await createVehicle(app, owner.token)).statusCode).toBe(201);
    }
    await app.close();
  });

  it("sync push surfaces LIMIT_EXCEEDED as a rejected operation", async () => {
    const { app } = await createTestApp();
    const owner = await signup(app, "lim-sync");

    expect((await createVehicle(app, owner.token)).statusCode).toBe(201);

    const push = await app.inject({
      method: "POST",
      url: "/v1/sync/push",
      headers: auth(owner.token),
      payload: {
        operations: [
          {
            entity_type: "vehicle",
            entity_id: uuid(),
            op: "upsert",
            payload: vehiclePayload(),
            client_ts: new Date().toISOString(),
          },
        ],
      },
    });
    expect(push.statusCode).toBe(200);
    const [result] = (push.json() as { results: Array<{ status: string; error?: { error?: { code?: string } } }> }).results;
    expect(result.status).toBe("rejected");
    expect(result.error?.error?.code).toBe("LIMIT_EXCEEDED");
    await app.close();
  });
});
