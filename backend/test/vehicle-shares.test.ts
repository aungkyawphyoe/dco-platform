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

describe("vehicle share sync propagation", () => {
  it("shares by code and email, seeds history, and fans writes back to sharers", async () => {
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
    const vehicleId = await createVehicle(app, owner.token, "SYN");

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

    // Member A joins by share code; member B is invited by email.
    const codeShare = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
      payload: { method: "code_qr", access_level: "add_edit_own" },
    });
    expect(codeShare.statusCode).toBe(201);
    const shareCode = codeShare.json().share_code as string;
    expect(shareCode).toHaveLength(8);

    const preview = await app.inject({
      method: "GET",
      url: `/v1/vehicles/shares/${shareCode.toLowerCase()}`,
      headers: auth(memberA.token),
    });
    expect(preview.statusCode).toBe(200);
    expect(preview.json().license_plate).toBeTruthy();

    const joinA = await app.inject({
      method: "POST",
      url: "/v1/vehicles/shares/join",
      headers: auth(memberA.token),
      payload: { code: shareCode.toLowerCase() },
    });
    expect(joinA.statusCode).toBe(201);

    const emailInvite = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
      payload: { method: "email", email: memberB.email, access_level: "view" },
    });
    expect(emailInvite.statusCode).toBe(201);
    const inviteToken = emailInvite.json().invite_token as string;

    const acceptB = await app.inject({
      method: "POST",
      url: "/v1/vehicles/shares/accept",
      headers: auth(memberB.token),
      payload: { token: inviteToken },
    });
    expect(acceptB.statusCode).toBe(200);

    // Both members can see the shared vehicle with no manual grant step.
    for (const token of [memberA.token, memberB.token]) {
      const sharedVehicles = await app.inject({
        method: "GET",
        url: "/v1/vehicles/shared",
        headers: auth(token),
      });
      expect(sharedVehicles.statusCode).toBe(200);
      expect(
        sharedVehicles.json().items.some((v: { id: string }) => v.id === vehicleId),
      ).toBe(true);
    }

    // Owner's share management view lists both members and the limits.
    const management = await app.inject({
      method: "GET",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
    });
    expect(management.statusCode).toBe(200);
    expect(management.json().shares).toHaveLength(2);
    expect(management.json().limits.per_vehicle).toBe(5);
    expect(management.json().limits.active_on_vehicle).toBe(2);

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

    // Member B only has view access: reads are allowed, writes are refused.
    const readB = await app.inject({
      method: "GET",
      url: `/v1/vehicles/${vehicleId}/plan-items`,
      headers: auth(memberB.token),
    });
    expect(readB.statusCode).toBe(200);
    const writeB = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/service-records`,
      headers: auth(memberB.token),
      payload: {
        id: uuid(), serviced_on: "2026-09-05", odometer: 7200, total_cost: 90,
        items: [{ name: "Brake pads", line_cost: 90 }],
      },
    });
    expect(writeB.statusCode).toBe(403);
    expect(writeB.json().error.code).toBe("insufficient_permission");

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

    // Revoking member A removes their access immediately.
    const listed = await app.inject({
      method: "GET",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
    });
    const shareA = (listed.json().shares as Array<{ id: string; user_id: string }>)
      .find((s) => s.user_id === memberA.id)!;
    const revoked = await app.inject({
      method: "DELETE",
      url: `/v1/vehicles/${vehicleId}/shares/${shareA.id}`,
      headers: auth(owner.token),
    });
    expect(revoked.statusCode).toBe(204);

    const afterRevoke = await app.inject({
      method: "GET",
      url: `/v1/vehicles/${vehicleId}/plan-items`,
      headers: auth(memberA.token),
    });
    expect(afterRevoke.statusCode).toBe(403);

    await app.close();
  });

  it("enforces plan share limits on free accounts", async () => {
    const { app } = await createTestApp();
    const owner = await signup(app, "limit-owner");
    const first = await signup(app, "limit-first");
    const second = await signup(app, "limit-second");
    const third = await signup(app, "limit-third");

    const vehicleId = await createVehicle(app, owner.token, "LIM");

    const codeShare = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
      payload: { method: "code_qr" },
    });
    expect(codeShare.statusCode).toBe(201);
    const joinFirst = await app.inject({
      method: "POST",
      url: "/v1/vehicles/shares/join",
      headers: auth(first.token),
      payload: { code: codeShare.json().share_code },
    });
    expect(joinFirst.statusCode).toBe(201);

    // Free plan allows one share per vehicle; a second one is refused.
    const overLimit = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
      payload: { method: "code_qr" },
    });
    expect(overLimit.statusCode).toBe(403);
    expect(overLimit.json().error.code).toBe("share_limit_reached");

    // Fill the free plan's 3 active shares in total across vehicles.
    for (const [label, user] of [["second", second], ["third", third]] as const) {
      const nextVehicle = await createVehicle(app, owner.token, `L${label.slice(0, 2).toUpperCase()}`);
      const nextShare = await app.inject({
        method: "POST",
        url: `/v1/vehicles/${nextVehicle}/shares`,
        headers: auth(owner.token),
        payload: { method: "code_qr" },
      });
      expect(nextShare.statusCode).toBe(201);
      const joined = await app.inject({
        method: "POST",
        url: "/v1/vehicles/shares/join",
        headers: auth(user.token),
        payload: { code: nextShare.json().share_code },
      });
      expect(joined.statusCode).toBe(201);
    }

    // The fourth active share exceeds the free plan's total cap.
    const vehicle4 = await createVehicle(app, owner.token, "LIM");
    const overTotal = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicle4}/shares`,
      headers: auth(owner.token),
      payload: { method: "code_qr" },
    });
    expect(overTotal.statusCode).toBe(403);
    expect(overTotal.json().error.code).toBe("share_limit_reached");

    await app.close();
  });

  it("lets every shared user read a fuel log and only writers edit it", async () => {
    const { app } = await createTestApp();
    const platformAdmin = await adminToken(app);
    const owner = await signup(app, "fuel-owner");
    const editor = await signup(app, "fuel-editor");
    const viewer = await signup(app, "fuel-viewer");

    await app.inject({
      method: "PATCH",
      url: `/v1/admin/users/${owner.id}`,
      headers: auth(platformAdmin),
      payload: { plan: "premium" },
    });

    const vehicleId = await createVehicle(app, owner.token, "FUE");

    for (const [member, access] of [[editor, "add_edit_own"], [viewer, "view"]] as const) {
      const share = await app.inject({
        method: "POST",
        url: `/v1/vehicles/${vehicleId}/shares`,
        headers: auth(owner.token),
        payload: { method: "code_qr", access_level: access },
      });
      expect(share.statusCode).toBe(201);
      const joined = await app.inject({
        method: "POST",
        url: "/v1/vehicles/shares/join",
        headers: auth(member.token),
        payload: { code: share.json().share_code },
      });
      expect(joined.statusCode).toBe(201);
    }

    // The editor writes the log, so `fuel_logs.user_id` is the editor, not the owner.
    const fuelTypes = await app.inject({
      method: "GET",
      url: "/v1/fuel-types",
      headers: auth(editor.token),
    });
    const fuelTypeId = (fuelTypes.json().items as Array<{ id: string; kind: string }>)
      .find((t) => t.kind === "liquid")!.id;

    const fuelLogId = uuid();
    const created = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/fuel-logs`,
      headers: auth(editor.token),
      payload: { id: fuelLogId, fuel_type_id: fuelTypeId, logged_on: "2026-09-01", amount: 35, cost: 55, odometer: 5200 },
    });
    expect(created.statusCode).toBe(201);

    // The owner and the viewer can both open it by id.
    for (const token of [owner.token, viewer.token]) {
      const read = await app.inject({
        method: "GET",
        url: `/v1/fuel-logs/${fuelLogId}`,
        headers: auth(token),
      });
      expect(read.statusCode).toBe(200);
      expect(read.json().id).toBe(fuelLogId);
    }

    // The owner has add_edit_own by definition, so they can edit a member's log.
    const ownerPatch = await app.inject({
      method: "PATCH",
      url: `/v1/fuel-logs/${fuelLogId}`,
      headers: auth(owner.token),
      payload: { cost: 60 },
    });
    expect(ownerPatch.statusCode).toBe(200);
    expect(ownerPatch.json().cost).toBe(60);

    // The viewer may still edit their own row but not someone else's.
    const viewerLogId = uuid();
    const viewerTypes = await app.inject({
      method: "GET",
      url: "/v1/fuel-types",
      headers: auth(viewer.token),
    });
    const viewerTypeId = (viewerTypes.json().items as Array<{ id: string; kind: string }>)
      .find((t) => t.kind === "liquid")!.id;
    const viewerCreated = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/fuel-logs`,
      headers: auth(viewer.token),
      payload: { id: viewerLogId, fuel_type_id: viewerTypeId, logged_on: "2026-09-02", amount: 20, cost: 30, odometer: 5300 },
    });
    expect(viewerCreated.statusCode).toBe(201);

    const viewerOwnPatch = await app.inject({
      method: "PATCH",
      url: `/v1/fuel-logs/${viewerLogId}`,
      headers: auth(viewer.token),
      payload: { cost: 33 },
    });
    expect(viewerOwnPatch.statusCode).toBe(200);

    const viewerForeignPatch = await app.inject({
      method: "PATCH",
      url: `/v1/fuel-logs/${fuelLogId}`,
      headers: auth(viewer.token),
      payload: { cost: 1 },
    });
    expect(viewerForeignPatch.statusCode).toBe(403);
    expect(viewerForeignPatch.json().error.code).toBe("insufficient_permission");

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
