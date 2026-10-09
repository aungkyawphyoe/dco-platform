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

    const standard = await app.inject({
      method: "PATCH",
      url: `/v1/admin/users/${owner.id}`,
      headers: auth(platformAdmin),
      payload: { plan: "standard" },
    });
    expect(standard.statusCode).toBe(200);

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
    expect(management.json().limits.per_vehicle).toBeNull();
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
    // Member A's log may already hold an earlier vehicle upsert (the mileage
    // fan-out from their own service entry), so assert on the rename itself.
    const vehicleChange = afterPatchA.changes.find(
      (c) => c.entity_type === "vehicle" && c.entity_id === vehicleId && c.payload.name === "Renamed Car",
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

  it("enforces plan share limits (per-vehicle and total)", async () => {
    const { app } = await createTestApp();
    const owner = await signup(app, "limit-owner");
    const first = await signup(app, "limit-first");
    const second = await signup(app, "limit-second");
    const third = await signup(app, "limit-third");
    const platformAdmin = await adminToken(app);

    const join = async (vehicleId: string, joiner: { token: string }) => {
      const codeShare = await app.inject({
        method: "POST",
        url: `/v1/vehicles/${vehicleId}/shares`,
        headers: auth(owner.token),
        payload: { method: "code_qr" },
      });
      expect(codeShare.statusCode).toBe(201);
      const joined = await app.inject({
        method: "POST",
        url: "/v1/vehicles/shares/join",
        headers: auth(joiner.token),
        payload: { code: codeShare.json().share_code },
      });
      expect(joined.statusCode).toBe(201);
    };

    const vehicleId = await createVehicle(app, owner.token, "LIM");
    await join(vehicleId, first);

    // Free plan allows one active share — a second code is refused.
    const overLimit = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
      payload: { method: "code_qr" },
    });
    expect(overLimit.statusCode).toBe(403);
    expect(overLimit.json().error.code).toBe("share_limit_reached");

    // Lite lifts both caps (3 vehicles / 3 shares); the kept share counts.
    await app.inject({
      method: "PATCH",
      url: `/v1/admin/users/${owner.id}`,
      headers: auth(platformAdmin),
      payload: { plan: "lite" },
    });

    // Fill to the lite total of 3 active shares on vehicle 1.
    await join(vehicleId, second);
    await join(vehicleId, third);

    // 4th share on a vehicle already at the per-vehicle cap → per-vehicle branch.
    const overVehicle = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
      payload: { method: "code_qr" },
    });
    expect(overVehicle.statusCode).toBe(403);
    expect(overVehicle.json().error.code).toBe("share_limit_reached");
    expect(overVehicle.json().error.message).toContain("per vehicle");

    // Total at 3/3: a share on another vehicle (itself at 0) is refused
    // by the total cap → total branch.
    const vehicle2 = await createVehicle(app, owner.token, "LI2");
    const overTotal = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicle2}/shares`,
      headers: auth(owner.token),
      payload: { method: "code_qr" },
    });
    expect(overTotal.statusCode).toBe(403);
    expect(overTotal.json().error.code).toBe("share_limit_reached");
    expect(overTotal.json().error.message).toContain("total active shares");

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
      payload: { plan: "standard" },
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

    // The owner has full control, so they can edit a member's log.
    const ownerPatch = await app.inject({
      method: "PATCH",
      url: `/v1/fuel-logs/${fuelLogId}`,
      headers: auth(owner.token),
      payload: { cost: 60 },
    });
    expect(ownerPatch.statusCode).toBe(200);
    expect(ownerPatch.json().cost).toBe(60);

    // A `view` sharee is read-only: they cannot create a log of their own...
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
      payload: { id: uuid(), fuel_type_id: viewerTypeId, logged_on: "2026-09-02", amount: 20, cost: 30, odometer: 5300 },
    });
    expect(viewerCreated.statusCode).toBe(403);
    expect(viewerCreated.json().error.code).toBe("insufficient_permission");

    // ...and cannot edit someone else's log either.
    const viewerForeignPatch = await app.inject({
      method: "PATCH",
      url: `/v1/fuel-logs/${fuelLogId}`,
      headers: auth(viewer.token),
      payload: { cost: 1 },
    });
    expect(viewerForeignPatch.statusCode).toBe(403);
    expect(viewerForeignPatch.json().error.code).toBe("insufficient_permission");

    // The editor keeps control of the log they created.
    const editorOwnPatch = await app.inject({
      method: "PATCH",
      url: `/v1/fuel-logs/${fuelLogId}`,
      headers: auth(editor.token),
      payload: { cost: 62 },
    });
    expect(editorOwnPatch.statusCode).toBe(200);
    expect(editorOwnPatch.json().cost).toBe(62);

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

  it("enforces the sharing permission matrix on every record type", async () => {
    const { app } = await createTestApp();
    const platformAdmin = await adminToken(app);
    const owner = await signup(app, "matrix-owner");
    const contributor = await signup(app, "matrix-contributor");
    const viewer = await signup(app, "matrix-viewer");

    await app.inject({
      method: "PATCH",
      url: `/v1/admin/users/${owner.id}`,
      headers: auth(platformAdmin),
      payload: { plan: "standard" },
    });

    const vehicleId = await createVehicle(app, owner.token, "MTX");

    // Owner seeds one record of each type.
    const ownerPlanItemId = uuid();
    expect((await app.inject({
      method: "POST", url: `/v1/vehicles/${vehicleId}/plan-items`, headers: auth(owner.token),
      payload: { id: ownerPlanItemId, name: "Oil change", interval_days: 180 },
    })).statusCode).toBe(201);

    const ownerServiceId = uuid();
    expect((await app.inject({
      method: "POST", url: `/v1/vehicles/${vehicleId}/service-records`, headers: auth(owner.token),
      payload: { id: ownerServiceId, serviced_on: "2026-08-01", odometer: 6000, total_cost: 120, items: [{ name: "Oil change" }] },
    })).statusCode).toBe(201);

    const ownerExpenseId = uuid();
    expect((await app.inject({
      method: "POST", url: `/v1/vehicles/${vehicleId}/expenses`, headers: auth(owner.token),
      payload: { id: ownerExpenseId, category: "maintenance", amount: 50, incurred_on: "2026-08-01" },
    })).statusCode).toBe(201);

    const ownerDocumentId = uuid();
    expect((await app.inject({
      method: "POST", url: `/v1/vehicles/${vehicleId}/documents`, headers: auth(owner.token),
      payload: { id: ownerDocumentId, name: "Insurance", category: "insurance" },
    })).statusCode).toBe(201);

    const ownerPartId = uuid();
    expect((await app.inject({
      method: "POST", url: `/v1/vehicles/${vehicleId}/parts`, headers: auth(owner.token),
      payload: { id: ownerPartId, name: "Oil filter" },
    })).statusCode).toBe(201);

    // Share the vehicle: contributor (add_edit_own) and viewer (view).
    for (const [member, access] of [[contributor, "add_edit_own"], [viewer, "view"]] as const) {
      const share = await app.inject({
        method: "POST", url: `/v1/vehicles/${vehicleId}/shares`, headers: auth(owner.token),
        payload: { method: "code_qr", access_level: access },
      });
      expect(share.statusCode).toBe(201);
      const joined = await app.inject({
        method: "POST", url: "/v1/vehicles/shares/join", headers: auth(member.token),
        payload: { code: share.json().share_code },
      });
      expect(joined.statusCode).toBe(201);
    }

    // ── Contributor: may create records of every collaborative type ──
    const contributorServiceId = uuid();
    expect((await app.inject({
      method: "POST", url: `/v1/vehicles/${vehicleId}/service-records`, headers: auth(contributor.token),
      payload: { id: contributorServiceId, serviced_on: "2026-09-01", odometer: 6500, total_cost: 80, items: [{ name: "Tire rotation" }] },
    })).statusCode).toBe(201);

    const contributorExpenseId = uuid();
    expect((await app.inject({
      method: "POST", url: `/v1/vehicles/${vehicleId}/expenses`, headers: auth(contributor.token),
      payload: { id: contributorExpenseId, category: "fuel", amount: 40, incurred_on: "2026-09-01" },
    })).statusCode).toBe(201);

    const contributorDocumentId = uuid();
    expect((await app.inject({
      method: "POST", url: `/v1/vehicles/${vehicleId}/documents`, headers: auth(contributor.token),
      payload: { id: contributorDocumentId, name: "Towing receipt", category: "receipt" },
    })).statusCode).toBe(201);

    // ── Contributor: never manages the maintenance plan or the vehicle ──
    const planCreate = await app.inject({
      method: "POST", url: `/v1/vehicles/${vehicleId}/plan-items`, headers: auth(contributor.token),
      payload: { id: uuid(), name: "Brake pads", interval_days: 90 },
    });
    expect(planCreate.statusCode).toBe(404);

    const planPatch = await app.inject({
      method: "PATCH", url: `/v1/plan-items/${ownerPlanItemId}`, headers: auth(contributor.token),
      payload: { interval_days: 30 },
    });
    expect(planPatch.statusCode).toBe(403);
    expect(planPatch.json().error.code).toBe("insufficient_permission");

    const planDelete = await app.inject({
      method: "DELETE", url: `/v1/plan-items/${ownerPlanItemId}`, headers: auth(contributor.token),
    });
    expect(planDelete.statusCode).toBe(403);

    const vehiclePatch = await app.inject({
      method: "PATCH", url: `/v1/vehicles/${vehicleId}`, headers: auth(contributor.token),
      payload: { name: "Hijacked" },
    });
    expect(vehiclePatch.statusCode).toBe(404);

    const archive = await app.inject({
      method: "POST", url: `/v1/vehicles/${vehicleId}/archive`, headers: auth(contributor.token),
    });
    expect(archive.statusCode).toBe(404);

    const sharesList = await app.inject({
      method: "GET", url: `/v1/vehicles/${vehicleId}/shares`, headers: auth(contributor.token),
    });
    expect(sharesList.statusCode).toBe(403);
    expect(sharesList.json().error.code).toBe("not_vehicle_owner");

    // ── Contributor: cannot touch records someone else created ──
    for (const [method, url, payload] of [
      ["PATCH", `/v1/service-records/${ownerServiceId}`, { notes: "edited by sharee" }],
      ["PATCH", `/v1/expenses/${ownerExpenseId}`, { amount: 1 }],
      ["PATCH", `/v1/documents/${ownerDocumentId}`, { name: "Renamed" }],
      ["PATCH", `/v1/parts/${ownerPartId}`, { name: "Renamed" }],
      ["DELETE", `/v1/expenses/${ownerExpenseId}`, undefined],
      ["DELETE", `/v1/documents/${ownerDocumentId}`, undefined],
    ] as const) {
      const response = await app.inject({ method, url, headers: auth(contributor.token), payload });
      expect(response.statusCode).toBe(403);
      expect(response.json().error.code).toBe("insufficient_permission");
    }

    // ── Contributor: full control over the records they created ──
    expect((await app.inject({
      method: "PATCH", url: `/v1/service-records/${contributorServiceId}`, headers: auth(contributor.token),
      payload: { notes: "my own edit" },
    })).statusCode).toBe(200);
    expect((await app.inject({
      method: "DELETE", url: `/v1/expenses/${contributorExpenseId}`, headers: auth(contributor.token),
    })).statusCode).toBe(204);

    // ── Owner: may edit or delete any record on their vehicle ──
    expect((await app.inject({
      method: "PATCH", url: `/v1/service-records/${contributorServiceId}`, headers: auth(owner.token),
      payload: { notes: "owner corrected this" },
    })).statusCode).toBe(200);
    expect((await app.inject({
      method: "DELETE", url: `/v1/documents/${contributorDocumentId}`, headers: auth(owner.token),
    })).statusCode).toBe(204);

    // ── Viewer: reads everything, writes nothing ──
    for (const url of [
      `/v1/vehicles/${vehicleId}/plan-items`,
      `/v1/vehicles/${vehicleId}/service-records`,
      `/v1/vehicles/${vehicleId}/expenses`,
      `/v1/vehicles/${vehicleId}/documents`,
      `/v1/vehicles/${vehicleId}/parts`,
      `/v1/vehicles/${vehicleId}/fuel-logs`,
      `/v1/vehicles/${vehicleId}/dashboard`,
    ]) {
      const read = await app.inject({ method: "GET", url, headers: auth(viewer.token) });
      expect(read.statusCode).toBe(200);
    }

    for (const [method, url, payload] of [
      ["POST", `/v1/vehicles/${vehicleId}/expenses`, { id: uuid(), category: "fuel", amount: 10, incurred_on: "2026-09-02" }],
      ["POST", `/v1/vehicles/${vehicleId}/documents`, { id: uuid(), name: "X", category: "other" }],
      ["POST", `/v1/vehicles/${vehicleId}/parts`, { id: uuid(), name: "X" }],
      ["POST", `/v1/vehicles/${vehicleId}/service-records`, { id: uuid(), serviced_on: "2026-09-02", odometer: 7000, total_cost: 10, items: [{ name: "X" }] }],
      ["POST", `/v1/vehicles/${vehicleId}/plan-items`, { id: uuid(), name: "X", interval_days: 30 }],
      ["PATCH", `/v1/expenses/${ownerExpenseId}`, { amount: 1 }],
      ["PATCH", `/v1/documents/${ownerDocumentId}`, { name: "Renamed" }],
      ["PATCH", `/v1/parts/${ownerPartId}`, { name: "Renamed" }],
      ["PATCH", `/v1/service-records/${ownerServiceId}`, { notes: "x" }],
    ] as const) {
      const response = await app.inject({ method, url, headers: auth(viewer.token), payload });
      expect([403, 404]).toContain(response.statusCode);
    }

    // ── Share roster: owner sees it, sharees never do ──
    const ownerDetail = await app.inject({
      method: "GET", url: `/v1/vehicles/${vehicleId}/detail`, headers: auth(owner.token),
    });
    expect(ownerDetail.statusCode).toBe(200);
    expect(ownerDetail.json().shares).toHaveLength(2);
    expect(ownerDetail.json().shared_users).toHaveLength(2);

    for (const token of [contributor.token, viewer.token]) {
      const detail = await app.inject({
        method: "GET", url: `/v1/vehicles/${vehicleId}/detail`, headers: auth(token),
      });
      expect(detail.statusCode).toBe(200);
      expect(detail.json().shares).toEqual([]);
      expect(detail.json().shared_users).toEqual([]);
    }

    // ── Mileage: a contributor's entry advances the shared vehicle ──
    const fuelTypes = await app.inject({
      method: "GET", url: "/v1/fuel-types", headers: auth(contributor.token),
    });
    const fuelTypeId = (fuelTypes.json().items as Array<{ id: string; kind: string }>)
      .find((t) => t.kind === "liquid")!.id;
    const fuelCreated = await app.inject({
      method: "POST", url: `/v1/vehicles/${vehicleId}/fuel-logs`, headers: auth(contributor.token),
      payload: { id: uuid(), fuel_type_id: fuelTypeId, logged_on: "2026-09-05", amount: 30, cost: 45, odometer: 7500 },
    });
    expect(fuelCreated.statusCode).toBe(201);

    const afterMileage = await app.inject({
      method: "GET", url: `/v1/vehicles/${vehicleId}`, headers: auth(owner.token),
    });
    expect(afterMileage.statusCode).toBe(200);
    expect(afterMileage.json().mileage).toBe(7500);

    await app.close();
  });
});
