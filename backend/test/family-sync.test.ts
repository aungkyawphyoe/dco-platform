import { describe, expect, it } from "vitest";
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

interface PullResult {
  cursor: string;
  changes: Array<{ entity_type: string; entity_id: string; op: string; payload: Record<string, unknown> }>;
}

async function pull(app: { inject: Function }, token: string, cursor = ""): Promise<PullResult> {
  const response = await app.inject({
    method: "GET",
    url: `/v1/sync/changes?cursor=${cursor}`,
    headers: auth(token),
  });
  expect(response.statusCode).toBe(200);
  return response.json() as PullResult;
}

describe("family sync propagation", () => {
  it("grants on share and join, seeds history, and fans writes back to the family", async () => {
    const { app } = await createTestApp();
    const platformAdmin = await adminToken(app);
    const owner = await signup(app, "sync-owner");
    const memberA = await signup(app, "sync-member-a");
    const memberB = await signup(app, "sync-member-b");

    const premium = await app.inject({
      method: "PATCH",
      url: `/v1/admin/users/${owner.id}`,
      headers: auth(platformAdmin),
      payload: { plan: "premium" },
    });
    expect(premium.statusCode).toBe(200);

    // Owner builds a vehicle with a full history.
    const vehicleId = uuid();
    const vehicle = await app.inject({
      method: "POST",
      url: "/v1/vehicles",
      headers: auth(owner.token),
      payload: {
        id: vehicleId, name: "Shared Car", make: "Toyota", model: "Corolla", year: 2021,
        license_plate: `SYN${vehicleId.slice(0, 4)}`, vin: vehicleId.replaceAll("-", "").slice(0, 17),
        fuel_type: "petrol", mileage: 5000,
      },
    });
    expect(vehicle.statusCode).toBe(201);

    const planItemId = uuid();
    const planItem = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/plan-items`,
      headers: auth(owner.token),
      payload: { id: planItemId, name: "Oil change", interval_days: 180 },
    });
    expect(planItem.statusCode).toBe(201);

    const serviceRecordId = uuid();
    const service = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/service-records`,
      headers: auth(owner.token),
      payload: {
        id: serviceRecordId, serviced_on: "2026-08-01", odometer: 6000, total_cost: 120,
        items: [{ name: "Oil change", line_cost: 120 }],
      },
    });
    expect(service.statusCode).toBe(201);

    const partId = uuid();
    const part = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/parts`,
      headers: auth(owner.token),
      payload: { id: partId, name: "Oil filter" },
    });
    expect(part.statusCode).toBe(201);

    const expenseId = uuid();
    const expense = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/expenses`,
      headers: auth(owner.token),
      payload: { id: expenseId, category: "maintenance", amount: 50, incurred_on: "2026-08-01" },
    });
    expect(expense.statusCode).toBe(201);

    const documentId = uuid();
    const document = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/documents`,
      headers: auth(owner.token),
      payload: { id: documentId, name: "Insurance", category: "insurance" },
    });
    expect(document.statusCode).toBe(201);

    // Default fuel types are seeded at signup; reuse an existing liquid one.
    const fuelTypes = await app.inject({
      method: "GET",
      url: "/v1/fuel-types",
      headers: auth(owner.token),
    });
    expect(fuelTypes.statusCode).toBe(200);
    const fuelTypeId = (fuelTypes.json().items as Array<{ id: string; kind: string }>)
      .find((t) => t.kind === "liquid")!.id;

    const fuelLogId = uuid();
    const fuelLog = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/fuel-logs`,
      headers: auth(owner.token),
      payload: { id: fuelLogId, fuel_type_id: fuelTypeId, logged_on: "2026-08-05", amount: 40, cost: 60 },
    });
    expect(fuelLog.statusCode).toBe(201);

    // Member A joins BEFORE the share; member B joins AFTER it.
    const family = await app.inject({
      method: "POST",
      url: "/v1/families",
      headers: auth(owner.token),
      payload: { name: "Sync Family" },
    });
    expect(family.statusCode).toBe(201);
    const familyId = family.json().id as string;
    const shareCode = family.json().share_code as string;

    const joinA = await app.inject({
      method: "POST",
      url: `/v1/families/${familyId}/join`,
      headers: auth(memberA.token),
      payload: { code: shareCode.toLowerCase() },
    });
    expect(joinA.statusCode).toBe(200);

    const share = await app.inject({
      method: "POST",
      url: "/v1/families/me/vehicles",
      headers: auth(owner.token),
      payload: { vehicle_id: vehicleId },
    });
    expect(share.statusCode).toBe(201);

    const joinB = await app.inject({
      method: "POST",
      url: `/v1/families/${familyId}/join`,
      headers: auth(memberB.token),
      payload: { code: shareCode.toLowerCase() },
    });
    expect(joinB.statusCode).toBe(200);

    // Both members can see the shared vehicle with no manual grant step.
    for (const token of [memberA.token, memberB.token]) {
      const memberVehicles = await app.inject({
        method: "GET",
        url: "/v1/families/me/vehicles",
        headers: auth(token),
      });
      expect(memberVehicles.statusCode).toBe(200);
      expect(
        memberVehicles.json().items.some((v: { id: string }) => v.id === vehicleId),
      ).toBe(true);
    }

    // Baseline pulls: seeded history reaches both members.
    const historyIds = [vehicleId, planItemId, serviceRecordId, partId, expenseId, documentId, fuelLogId];
    const baselineA = await pull(app, memberA.token);
    const baselineB = await pull(app, memberB.token);
    for (const baseline of [baselineA, baselineB]) {
      for (const id of historyIds) {
        expect(baseline.changes.some((c) => c.entity_id === id)).toBe(true);
      }
    }

    // Member A logs a service record: owner and member B receive it.
    const memberServiceId = uuid();
    const memberService = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/service-records`,
      headers: auth(memberA.token),
      payload: {
        id: memberServiceId, serviced_on: "2026-09-01", odometer: 7000, total_cost: 80,
        items: [{ name: "Tire rotation", line_cost: 80 }],
      },
    });
    expect(memberService.statusCode).toBe(201);

    const ownerPull = await pull(app, owner.token);
    expect(ownerPull.changes.some((c) => c.entity_id === memberServiceId)).toBe(true);
    const afterServiceB = await pull(app, memberB.token, baselineB.cursor);
    expect(afterServiceB.changes.some((c) => c.entity_id === memberServiceId)).toBe(true);

    // Owner edits the vehicle: member A receives the upsert.
    const patch = await app.inject({
      method: "PATCH",
      url: `/v1/vehicles/${vehicleId}`,
      headers: auth(owner.token),
      payload: { name: "Renamed Car" },
    });
    expect(patch.statusCode).toBe(200);
    const afterPatchA = await pull(app, memberA.token, baselineA.cursor);
    const vehicleChange = afterPatchA.changes.find(
      (c) => c.entity_type === "vehicle" && c.entity_id === vehicleId,
    );
    expect(vehicleChange?.op).toBe("upsert");
    expect(vehicleChange?.payload.name).toBe("Renamed Car");

    // Member A can activate the shared vehicle...
    const activate = await app.inject({
      method: "PATCH",
      url: "/v1/me",
      headers: auth(memberA.token),
      payload: { active_vehicle_id: vehicleId },
    });
    expect(activate.statusCode).toBe(200);

    // ...but still cannot edit vehicle info (product rule).
    const forbidden = await app.inject({
      method: "PATCH",
      url: `/v1/vehicles/${vehicleId}`,
      headers: auth(memberA.token),
      payload: { name: "Hijacked" },
    });
    expect(forbidden.statusCode).toBe(404);

    await app.close();
  });

  it("returns 404 instead of 500 for a malformed user detail id", async () => {
    const { app } = await createTestApp();
    const user = await signup(app, "sync-malformed");
    const response = await app.inject({
      method: "GET",
      url: "/v1/users/edit/detail",
      headers: auth(user.token),
    });
    expect(response.statusCode).toBe(404);
    await app.close();
  });
});
