import { describe, expect, it } from "vitest";
import { createTestApp, uuid } from "./helpers.js";

describe("sync", () => {
  it("pushes a vehicle upsert and pulls the change log", async () => {
    const { app } = await createTestApp();
    const signup = await app.inject({
      method: "POST",
      url: "/v1/auth/signup",
      payload: { email: `s-${uuid()}@test.local`, password: "password1" },
    });
    const token = signup.json().access_token;
    const auth = { authorization: `Bearer ${token}` };
    const vehicleId = uuid();
    const push = await app.inject({
      method: "POST",
      url: "/v1/sync/push",
      headers: auth,
      payload: {
        operations: [
          {
            entity_type: "vehicle",
            entity_id: vehicleId,
            op: "upsert",
            client_ts: new Date().toISOString(),
            payload: {
              name: "Synced",
              make: "Honda",
              model: "Civic",
              year: 2019,
              license_plate: `SYN${vehicleId.slice(0, 4)}`,
              fuel_type: "petrol",
              mileage: 5000,
            },
          },
        ],
      },
    });
    expect(push.statusCode).toBe(200);
    expect(push.json().results[0].status).toMatch(/applied|idempotent/);

    const pull = await app.inject({
      method: "GET",
      url: "/v1/sync/changes?cursor=",
      headers: auth,
    });
    expect(pull.statusCode).toBe(200);
    expect(pull.json().changes.some((c: { entity_id: string }) => c.entity_id === vehicleId)).toBe(true);
    await app.close();
  });
});
