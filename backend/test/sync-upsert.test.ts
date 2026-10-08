import { describe, expect, it } from "vitest";
import { createTestApp, uuid } from "./helpers.js";

const auth = (token: string) => ({ authorization: `Bearer ${token}` });

async function setup() {
  const { app } = await createTestApp();
  const signup = await app.inject({
    method: "POST",
    url: "/v1/auth/signup",
    payload: { email: `up-${uuid()}@test.local`, password: "password1" },
  });
  expect(signup.statusCode).toBe(201);
  const token = signup.json().access_token as string;

  const vehicleId = uuid();
  const vehicle = await app.inject({
    method: "POST",
    url: "/v1/vehicles",
    headers: auth(token),
    payload: {
      id: vehicleId,
      name: "Upsert Car",
      make: "Toyota",
      model: "Corolla",
      year: 2021,
      license_plate: `UPS${vehicleId.slice(0, 4)}`,
      fuel_type: "petrol",
      mileage: 5000,
    },
  });
  expect(vehicle.statusCode).toBe(201);
  return { app, token, vehicleId };
}

async function push(
  app: { inject: Function },
  token: string,
  operations: Array<Record<string, unknown>>,
) {
  const response = await app.inject({
    method: "POST",
    url: "/v1/sync/push",
    headers: auth(token),
    payload: { operations },
  });
  expect(response.statusCode).toBe(200);
  return response.json().results as Array<{ status: string }>;
}

function op(
  entityType: string,
  entityId: string,
  payload: Record<string, unknown>,
): Record<string, unknown> {
  return {
    entity_type: entityType,
    entity_id: entityId,
    op: "upsert",
    client_ts: new Date().toISOString(),
    payload,
  };
}

const ok = (status: string) => status === "applied" || status === "idempotent";

describe("sync push upserts update existing rows", () => {
  it("creates then edits a service record (items included)", async () => {
    const { app, token, vehicleId } = await setup();
    const serviceId = uuid();
    const create = await push(app, token, [
      op("service_record", serviceId, {
        vehicle_id: vehicleId,
        serviced_on: "2026-08-01",
        odometer: 6000,
        total_cost: 100,
        workshop_name: null,
        notes: null,
        items: [{ id: uuid(), name: "Oil change", line_cost: 100 }],
        parts: [],
      }),
    ]);
    expect(ok(create[0].status)).toBe(true);

    const before = await app.inject({
      method: "GET",
      url: `/v1/service-records/${serviceId}`,
      headers: auth(token),
    });
    expect(before.statusCode).toBe(200);
    expect(before.json().total_cost).toBe(100);

    const edit = await push(app, token, [
      op("service_record", serviceId, {
        vehicle_id: vehicleId,
        serviced_on: "2026-08-01",
        odometer: 6000,
        total_cost: 150,
        workshop_name: "WS",
        notes: "edited",
        items: [{ id: uuid(), name: "Oil change 5w30", line_cost: 150 }],
        parts: [],
      }),
    ]);
    expect(ok(edit[0].status)).toBe(true);

    const after = await app.inject({
      method: "GET",
      url: `/v1/service-records/${serviceId}`,
      headers: auth(token),
    });
    expect(after.statusCode).toBe(200);
    expect(after.json().total_cost).toBe(150);
    expect(after.json().items[0].name).toBe("Oil change 5w30");
    expect(after.json().workshop_name).toBe("WS");
    await app.close();
  });

  it("creates then edits a plan item, preserving client due dates", async () => {
    const { app, token, vehicleId } = await setup();
    const planItemId = uuid();
    const create = await push(app, token, [
      op("plan_item", planItemId, {
        vehicle_id: vehicleId,
        name: "Oil change",
        interval_days: 180,
        interval_distance: null,
        next_due_on: "2027-04-06",
        next_due_mileage: null,
        enabled: true,
        notes: null,
        catalog_key: null,
      }),
    ]);
    expect(ok(create[0].status)).toBe(true);

    const list = await app.inject({
      method: "GET",
      url: `/v1/vehicles/${vehicleId}/plan-items`,
      headers: auth(token),
    });
    expect(list.statusCode).toBe(200);
    expect(list.json().items[0].next_due_on).toBe("2027-04-06");

    const edit = await push(app, token, [
      op("plan_item", planItemId, {
        vehicle_id: vehicleId,
        name: "Oil change 5w30",
        interval_days: 365,
        interval_distance: null,
        next_due_on: "2027-06-01",
        next_due_mileage: null,
        enabled: true,
        notes: "edited",
        catalog_key: null,
      }),
    ]);
    expect(ok(edit[0].status)).toBe(true);

    const after = await app.inject({
      method: "GET",
      url: `/v1/vehicles/${vehicleId}/plan-items`,
      headers: auth(token),
    });
    expect(after.json().items[0].name).toBe("Oil change 5w30");
    expect(after.json().items[0].interval_days).toBe(365);
    expect(after.json().items[0].next_due_on).toBe("2027-06-01");
    await app.close();
  });

  it("creates then edits an expense, replacing assigned parts", async () => {
    const { app, token, vehicleId } = await setup();
    const partId = uuid();
    const part = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/parts`,
      headers: auth(token),
      payload: { id: partId, name: "Oil filter", brand: "B", part_number: "P1" },
    });
    expect(part.statusCode).toBe(201);

    const expenseId = uuid();
    const create = await push(app, token, [
      op("expense", expenseId, {
        vehicle_id: vehicleId,
        category: "maintenance",
        amount: 50,
        incurred_on: "2026-08-01",
        notes: "first",
        parts: [{ id: uuid(), part_id: partId, name: "Oil filter" }],
      }),
    ]);
    expect(ok(create[0].status)).toBe(true);

    const edit = await push(app, token, [
      op("expense", expenseId, {
        vehicle_id: vehicleId,
        category: "maintenance",
        amount: 75,
        incurred_on: "2026-08-01",
        notes: "second",
        parts: [{ id: uuid(), part_id: partId, name: "Oil filter X" }],
      }),
    ]);
    expect(ok(edit[0].status)).toBe(true);

    const list = await app.inject({
      method: "GET",
      url: `/v1/vehicles/${vehicleId}/expenses`,
      headers: auth(token),
    });
    expect(list.statusCode).toBe(200);
    const expense = list.json().items[0];
    expect(expense.amount).toBe(75);
    expect(expense.notes).toBe("second");
    expect(expense.parts).toHaveLength(1);
    expect(expense.parts[0].name).toBe("Oil filter X");
    await app.close();
  });

  it("creates a same-day fuel log and then edits it", async () => {
    const { app, token, vehicleId } = await setup();
    const fuelType = await app.inject({
      method: "POST",
      url: "/v1/fuel-types",
      headers: auth(token),
      payload: { id: uuid(), name: `Petrol ${vehicleId.slice(0, 6)}`, kind: "liquid", unit: "L" },
    });
    expect(fuelType.statusCode).toBe(201);
    const fuelTypeId = fuelType.json().id as string;

    const logId = uuid();
    const today = new Date().toISOString();
    const create = await push(app, token, [
      op("fuel_log", logId, {
        vehicle_id: vehicleId,
        fuel_type_id: fuelTypeId,
        logged_on: today,
        amount: 40,
        cost: 60,
        odometer: 6000,
      }),
    ]);
    expect(ok(create[0].status)).toBe(true);

    const edit = await push(app, token, [
      op("fuel_log", logId, {
        vehicle_id: vehicleId,
        fuel_type_id: fuelTypeId,
        logged_on: today,
        amount: 45,
        cost: 70,
        odometer: 6000,
      }),
    ]);
    expect(ok(edit[0].status)).toBe(true);

    const after = await app.inject({
      method: "GET",
      url: `/v1/fuel-logs/${logId}`,
      headers: auth(token),
    });
    expect(after.statusCode).toBe(200);
    expect(after.json().amount).toBe(45);
    expect(after.json().cost).toBe(70);
    await app.close();
  });

  it("creates then edits a part", async () => {
    const { app, token, vehicleId } = await setup();
    const partId = uuid();
    const create = await push(app, token, [
      op("part", partId, {
        vehicle_id: vehicleId,
        name: "Oil filter",
        brand: "B",
        part_number: "P1",
        notes: null,
      }),
    ]);
    expect(ok(create[0].status)).toBe(true);

    const edit = await push(app, token, [
      op("part", partId, {
        vehicle_id: vehicleId,
        name: "Oil filter X",
        brand: "B",
        part_number: "P1",
        notes: "edited",
      }),
    ]);
    expect(ok(edit[0].status)).toBe(true);

    const list = await app.inject({
      method: "GET",
      url: `/v1/vehicles/${vehicleId}/parts`,
      headers: auth(token),
    });
    expect(list.statusCode).toBe(200);
    expect(list.json().items[0].name).toBe("Oil filter X");
    expect(list.json().items[0].notes).toBe("edited");
    await app.close();
  });
});
