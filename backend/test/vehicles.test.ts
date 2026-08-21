import { describe, expect, it } from "vitest";
import { createTestApp, uuid } from "./helpers.js";

async function ownerSession(app: { inject: Function }) {
  const email = `o-${uuid()}@test.local`;
  const res = await app.inject({
    method: "POST",
    url: "/v1/auth/signup",
    payload: { email, password: "password1" },
  });
  return { token: res.json().access_token as string, userId: res.json().user.id as string };
}

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

describe("vehicles", () => {
  it("creates a vehicle, rejects mileage decrease, and archives", async () => {
    const { app } = await createTestApp();
    const { token } = await ownerSession(app);
    const auth = { authorization: `Bearer ${token}` };
    const id = uuid();
    const created = await app.inject({
      method: "POST",
      url: "/v1/vehicles",
      headers: auth,
      payload: vehiclePayload(id),
    });
    expect(created.statusCode).toBe(201);
    expect(created.json().mileage).toBe(10000);

    const replay = await app.inject({
      method: "POST",
      url: "/v1/vehicles",
      headers: auth,
      payload: vehiclePayload(id),
    });
    expect(replay.statusCode).toBe(201);

    const down = await app.inject({
      method: "PATCH",
      url: `/v1/vehicles/${id}`,
      headers: auth,
      payload: { mileage: 9999 },
    });
    expect(down.statusCode).toBe(409);

    const archived = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${id}/archive`,
      headers: auth,
    });
    expect(archived.statusCode).toBe(200);
    expect(archived.json().archived).toBe(true);
    await app.close();
  });

  it("enforces unique plate per account", async () => {
    const { app } = await createTestApp();
    const { token } = await ownerSession(app);
    const auth = { authorization: `Bearer ${token}` };
    const plate = `UNIQ${uuid().slice(0, 4)}`;
    const first = await app.inject({
      method: "POST",
      url: "/v1/vehicles",
      headers: auth,
      payload: { ...vehiclePayload(), license_plate: plate },
    });
    expect(first.statusCode).toBe(201);
    const second = await app.inject({
      method: "POST",
      url: "/v1/vehicles",
      headers: auth,
      payload: { ...vehiclePayload(), license_plate: plate },
    });
    expect(second.statusCode).toBe(409);
    await app.close();
  });
});
