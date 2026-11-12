import { and, eq } from "drizzle-orm";
import { describe, expect, it } from "vitest";
import {
  changeLog,
  organizationMembers,
  planItems,
  serviceRecords,
  transferredVehicles,
  vehicleHandovers,
  workOrders,
} from "../src/db/schema.js";
import { createTestApp, grantTestFleet, testEnv, uuid } from "./helpers.js";

const auth = (token: string) => ({ authorization: `Bearer ${token}` });

async function signup(app: Awaited<ReturnType<typeof createTestApp>>["app"], label: string) {
  const email = `${label}-${uuid()}@test.local`;
  const response = await app.inject({ method: "POST", url: "/v1/auth/signup", payload: { email, password: "password1", display_name: label } });
  expect(response.statusCode, response.body).toBe(201);
  return { email, id: response.json().user.id as string, token: response.json().access_token as string };
}

async function adminToken(app: Awaited<ReturnType<typeof createTestApp>>["app"]) {
  const response = await app.inject({ method: "POST", url: "/v1/auth/login", payload: { email: testEnv.BOOTSTRAP_ADMIN_EMAIL, password: testEnv.BOOTSTRAP_ADMIN_PASSWORD } });
  return response.json().access_token as string;
}

async function showroom(app: Awaited<ReturnType<typeof createTestApp>>["app"]) {
  const platform = await adminToken(app);
  const seller = await signup(app, "handover-seller");
  const created = await app.inject({
    method: "POST", url: "/v1/admin/organizations", headers: auth(platform),
    payload: { name: `Handover showroom ${uuid().slice(0, 8)}`, type: "showroom", admin_email: seller.email },
  });
  expect(created.statusCode, created.body).toBe(201);
  const orgId = created.json().id as string;
  await grantTestFleet(app, platform, orgId);
  await app.inject({ method: "PATCH", url: `/v1/admin/organizations/${orgId}/status`, headers: auth(platform), payload: { status: "active" } });
  const login = await app.inject({ method: "POST", url: "/v1/auth/login", payload: { email: seller.email, password: "password1", surface: "fleet" } });
  expect(login.statusCode, login.body).toBe(200);
  return { platform, seller, orgId, token: login.json().access_token as string };
}

async function reservedVehicle(app: Awaited<ReturnType<typeof createTestApp>>["app"], orgId: string, token: string, mileage = 43000) {
  const vehicleId = uuid();
  const created = await app.inject({
    method: "POST", url: `/v1/organizations/${orgId}/vehicles`, headers: auth(token),
    payload: {
      id: vehicleId, name: "Handover car", make: "Honda", model: "Civic", year: 2023,
      license_plate: `HND${vehicleId.slice(0, 5)}`, vin: vehicleId.replaceAll("-", "").slice(0, 17),
      fuel_type: "petrol", mileage, lifecycle_template: "showroom",
    },
  });
  expect(created.statusCode, created.body).toBe(201);
  for (const status of ["listed", "reserved"]) {
    const changed = await app.inject({ method: "PATCH", url: `/v1/organizations/${orgId}/vehicles/${vehicleId}`, headers: auth(token), payload: { status } });
    expect(changed.statusCode, changed.body).toBe(200);
  }
  return vehicleId;
}

async function createDraft(
  app: Awaited<ReturnType<typeof createTestApp>>["app"],
  payload: Record<string, unknown>,
  orgId: string,
  token: string,
) {
  return app.inject({ method: "POST", url: `/v1/organizations/${orgId}/handovers`, headers: auth(token), payload });
}

describe("showroom handover", () => {
  it("copies a reviewed plan, freezes warranty terms, delivers a clean history, and retries idempotently", async () => {
    const { app, db } = await createTestApp();
    const { platform, orgId, token, seller } = await showroom(app);
    const buyer = await signup(app, "handover-buyer");
    const vehicleId = await reservedVehicle(app, orgId, token);

    const partner = await app.inject({ method: "POST", url: "/v1/admin/partners", headers: auth(platform), payload: { name: "Approved Garage", type: "workshop", status: "verified" } });
    const partnerId = partner.json().id as string;
    expect((await app.inject({ method: "POST", url: `/v1/organizations/${orgId}/workshops`, headers: auth(token), payload: { partner_id: partnerId } })).statusCode).toBe(201);
    const template = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/warranty-templates`, headers: auth(token),
      payload: { name: "One year", duration_years: 1, mileage_limit_km: 20000, coverage_categories: ["Engine"], exclusions: "Wear items", approved_workshop_ids: [partnerId] },
    });
    expect(template.statusCode, template.body).toBe(201);

    await db.insert(serviceRecords).values({ id: uuid(), vehicleId, servicedOn: "2026-09-01", odometer: "42000", totalCost: "150", notes: "Showroom private", createdBy: seller.id });
    await db.insert(planItems).values({ id: uuid(), vehicleId, name: "Showroom oil", nextDueMileage: "45000", baselineDueMileage: "45000" });

    const byEmail = await app.inject({ method: "GET", url: `/v1/organizations/${orgId}/handover-buyers?email=${encodeURIComponent(buyer.email)}`, headers: auth(token) });
    expect(byEmail.statusCode, byEmail.body).toBe(200);
    expect(byEmail.json()).toMatchObject({ user_id: buyer.id, eligible: true });
    expect(byEmail.body).not.toContain(buyer.email);
    const byQr = await app.inject({ method: "GET", url: `/v1/organizations/${orgId}/handover-buyers/${buyer.id}`, headers: auth(token) });
    expect(byQr.json().user_id).toBe(buyer.id);

    const draft = await createDraft(app, {
      vehicle_id: vehicleId,
      buyer_user_id: buyer.id,
      sale_date: "2026-09-10",
      current_mileage_km: 43000,
      plan: [
        { name: "Oil change", interval_distance: 5000, next_due_mileage: 45000 },
        { name: "Brake inspection", initial_service_required: true },
      ],
      warranty_choice: "template",
      warranty_template_id: template.json().id,
    }, orgId, token);
    expect(draft.statusCode, draft.body).toBe(201);
    expect(draft.json().revision).toBe(1);
    expect(draft.json().reviewed_revision).toBeNull();

    const duplicate = await createDraft(app, { vehicle_id: vehicleId, buyer_user_id: buyer.id }, orgId, token);
    expect(duplicate.statusCode).toBe(409);
    expect(duplicate.json().error.code).toBe("handover_pending");

    const review = await app.inject({ method: "POST", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}/review`, headers: auth(token), payload: { revision: 1 } });
    expect(review.statusCode, review.body).toBe(200);
    expect(review.json().reviewed_revision).toBe(1);

    const completed = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}/complete`, headers: auth(token),
      payload: { reviewed_revision: 1, acknowledged: true },
    });
    expect(completed.statusCode, completed.body).toBe(201);
    expect(completed.json()).toMatchObject({ status: "completed", buyer_user_id: buyer.id, idempotent: false });
    expect(completed.json().plan_item_ids).toHaveLength(2);
    expect(completed.json().delivery.delivered).toBeGreaterThan(0);

    const buyerVehicle = await app.inject({ method: "GET", url: `/v1/vehicles/${vehicleId}`, headers: auth(buyer.token) });
    expect(buyerVehicle.statusCode, buyerVehicle.body).toBe(200);
    expect(buyerVehicle.json()).toMatchObject({ user_id: buyer.id, mileage: 43000, purchase_price: null, purchase_date: null, photo_media_id: null });
    expect((await app.inject({ method: "GET", url: `/v1/vehicles/${vehicleId}/service-records`, headers: auth(buyer.token) })).json().items).toEqual([]);
    const buyerPlan = await app.inject({ method: "GET", url: `/v1/vehicles/${vehicleId}/plan-items`, headers: auth(buyer.token) });
    expect(buyerPlan.json().items).toHaveLength(2);
    expect(buyerPlan.json().items).toEqual(expect.arrayContaining([
      expect.objectContaining({ name: "Oil change", next_due_mileage: 45000, initial_service_required: false }),
      expect.objectContaining({ name: "Brake inspection", initial_service_required: true }),
    ]));
    const buyerWarranty = await app.inject({ method: "GET", url: `/v1/vehicles/${vehicleId}/warranty`, headers: auth(buyer.token) });
    expect(buyerWarranty.statusCode, buyerWarranty.body).toBe(200);
    expect(buyerWarranty.json()).toMatchObject({
      status: "active", sale_date: "2026-09-10", sale_mileage_km: 43000,
      terms: expect.objectContaining({ name: "One year", exclusions: "Wear items", approved_workshops: [{ id: partnerId, name: "Approved Garage" }] }),
    });

    const transferred = await db.select().from(transferredVehicles).where(eq(transferredVehicles.vehicleId, vehicleId));
    expect(transferred).toHaveLength(1);
    expect(transferred[0].handoverId).toBe(draft.json().id);
    expect(transferred[0].serviceSnapshot).toHaveLength(1);
    expect(transferred[0].vehicleSnapshot).toMatchObject({ purchase_price: null });

    const changes = await app.inject({ method: "GET", url: "/v1/sync/changes?cursor=", headers: auth(buyer.token) });
    const types = changes.json().changes.map((row: { entity_type: string }) => row.entity_type);
    expect(types).toEqual(expect.arrayContaining(["vehicle", "plan_item", "warranty", "handover_receipt"]));
    expect(changes.json().changes.find((row: { entity_type: string }) => row.entity_type === "vehicle")?.payload.transfer_limit_exempt).toBe(true);

    const retry = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}/complete`, headers: auth(token),
      payload: { reviewed_revision: 1, acknowledged: true },
    });
    expect(retry.statusCode, retry.body).toBe(200);
    expect(retry.json().idempotent).toBe(true);
    expect(retry.json()).toMatchObject({ vehicle_id: vehicleId, buyer_user_id: buyer.id });
    expect(await db.select().from(transferredVehicles).where(eq(transferredVehicles.vehicleId, vehicleId))).toHaveLength(1);
    expect(await db.select().from(planItems).where(and(eq(planItems.vehicleId, vehicleId), eq(planItems.initialServiceRequired, true)))).toHaveLength(1);

    const legacy = await app.inject({ method: "POST", url: `/v1/organizations/${orgId}/vehicles/${vehicleId}/transfer`, headers: auth(token), payload: {} });
    expect(legacy.statusCode).toBe(410);
    expect(legacy.json().error.code).toBe("handover_required");
    await app.close();
  });

  it("blocks completion on review, plan, warranty and open repairs, and rechecks delegated permission", async () => {
    const { app, db } = await createTestApp();
    const { orgId, token, seller } = await showroom(app);
    const buyer = await signup(app, "blocked-buyer");
    const manager = await signup(app, "handover-manager");
    const vehicleId = await reservedVehicle(app, orgId, token);
    await db.insert(organizationMembers).values({ id: uuid(), orgId, userId: manager.id, role: "org_manager" });
    const managerLogin = await app.inject({ method: "POST", url: "/v1/auth/login", payload: { email: manager.email, password: "password1", surface: "fleet" } });
    expect(managerLogin.statusCode, managerLogin.body).toBe(200);
    const managerToken = managerLogin.json().access_token as string;

    const draft = await createDraft(app, { vehicle_id: vehicleId, buyer_user_id: buyer.id, sale_date: "2026-09-10", current_mileage_km: 43000 }, orgId, token);
    expect(draft.statusCode, draft.body).toBe(201);
    const unreviewed = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}/complete`, headers: auth(token),
      payload: { reviewed_revision: draft.json().revision, acknowledged: true },
    });
    expect(unreviewed.statusCode).toBe(409);
    expect(unreviewed.json().error.code).toBe("review_required");

    const invalidReview = await app.inject({ method: "POST", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}/review`, headers: auth(token), payload: { revision: draft.json().revision } });
    expect(invalidReview.statusCode).toBe(409);
    expect(invalidReview.json().error.details.issues.map((issue: { code: string }) => issue.code)).toEqual(expect.arrayContaining(["plan_empty", "warranty_choice_required"]));

    const patched = await app.inject({
      method: "PATCH", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}`, headers: auth(token),
      payload: { plan: [{ name: "Oil change", interval_distance: 5000, next_due_mileage: 45000 }], warranty_choice: "none" },
    });
    expect(patched.statusCode, patched.body).toBe(200);
    expect(patched.json().revision).toBe(2);
    expect(patched.json().reviewed_revision).toBeNull();

    const workOrderId = uuid();
    await db.insert(workOrders).values({ id: workOrderId, orgId, vehicleId, reportedBy: seller.id, odometerKm: 43000, issueType: "other", description: "Open repair", urgency: "low" });
    const repairReview = await app.inject({ method: "POST", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}/review`, headers: auth(token), payload: { revision: 2 } });
    expect(repairReview.statusCode).toBe(409);
    expect(repairReview.json().error.details.issues.some((issue: { code: string }) => issue.code === "open_repairs")).toBe(true);

    const cancelledRepair = await app.inject({ method: "PATCH", url: `/v1/organizations/${orgId}/work-orders/${workOrderId}`, headers: auth(token), payload: { status: "cancelled", cancellation_reason: "Resolved outside the showroom" } });
    expect(cancelledRepair.statusCode, cancelledRepair.body).toBe(200);
    expect(cancelledRepair.json()).toMatchObject({ status: "cancelled", cancellation_reason: "Resolved outside the showroom" });

    const review = await app.inject({ method: "POST", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}/review`, headers: auth(token), payload: { revision: 2 } });
    expect(review.statusCode, review.body).toBe(200);

    const denied = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}/complete`, headers: auth(managerToken),
      payload: { reviewed_revision: 2, acknowledged: true },
    });
    expect(denied.statusCode).toBe(403);
    expect(denied.json().error.code).toBe("transfer_permission_required");

    const granted = await app.inject({ method: "PATCH", url: `/v1/organizations/${orgId}/members/${manager.id}`, headers: auth(token), payload: { can_complete_handover: true } });
    expect(granted.statusCode, granted.body).toBe(200);
    expect(granted.json().can_complete_handover).toBe(true);

    const managerComplete = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}/complete`, headers: auth(managerToken),
      payload: { reviewed_revision: 2, acknowledged: true },
    });
    expect(managerComplete.statusCode, managerComplete.body).toBe(201);

    // A stale review revision cannot complete another vehicle after the draft changes.
    const secondVehicle = await reservedVehicle(app, orgId, token, 1000);
    const secondDraft = await createDraft(app, {
      vehicle_id: secondVehicle, buyer_user_id: buyer.id, sale_date: "2026-09-11", current_mileage_km: 1000,
      plan: [{ name: "Oil", initial_service_required: true }], warranty_choice: "none",
    }, orgId, token);
    const secondReview = await app.inject({ method: "POST", url: `/v1/organizations/${orgId}/handovers/${secondDraft.json().id}/review`, headers: auth(token), payload: { revision: 1 } });
    expect(secondReview.statusCode, secondReview.body).toBe(200);
    const secondPatch = await app.inject({ method: "PATCH", url: `/v1/organizations/${orgId}/handovers/${secondDraft.json().id}`, headers: auth(token), payload: { current_mileage_km: 1001 } });
    expect(secondPatch.json().revision).toBe(2);
    const stale = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/handovers/${secondDraft.json().id}/complete`, headers: auth(token),
      payload: { reviewed_revision: 1, acknowledged: true },
    });
    expect(stale.statusCode).toBe(409);
    expect(stale.json().error.code).toBe("review_required");
    await app.close();
  });

  it("cancels drafts without moving ownership and requires a new draft to change buyer", async () => {
    const { app, db } = await createTestApp();
    const { orgId, token } = await showroom(app);
    const buyerOne = await signup(app, "cancel-buyer-one");
    const buyerTwo = await signup(app, "cancel-buyer-two");
    const vehicleId = await reservedVehicle(app, orgId, token, 9000);

    const draft = await createDraft(app, { vehicle_id: vehicleId, buyer_user_id: buyerOne.id, sale_date: "2026-09-10", current_mileage_km: 9000 }, orgId, token);
    expect(draft.statusCode, draft.body).toBe(201);
    const buyerChange = await app.inject({ method: "PATCH", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}`, headers: auth(token), payload: { buyer_user_id: buyerTwo.id } });
    expect(buyerChange.statusCode).toBe(422);
    expect(buyerChange.json().error.code).toBe("buyer_change_requires_new_draft");

    const cancelled = await app.inject({ method: "POST", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}/cancel`, headers: auth(token), payload: { reason: "Buyer changed" } });
    expect(cancelled.statusCode, cancelled.body).toBe(200);
    expect(cancelled.json()).toMatchObject({ status: "cancelled", cancellation_reason: "Buyer changed" });
    const buyerCancelledView = await app.inject({ method: "GET", url: `/v1/vehicles/${vehicleId}`, headers: auth(buyerOne.token) });
    expect([403, 404]).toContain(buyerCancelledView.statusCode);

    const replacement = await createDraft(app, { vehicle_id: vehicleId, buyer_user_id: buyerTwo.id, sale_date: "2026-09-11", current_mileage_km: 9000, plan: [{ name: "Initial service", initial_service_required: true }], warranty_choice: "none" }, orgId, token);
    expect(replacement.statusCode, replacement.body).toBe(201);
    const reopened = await app.inject({ method: "POST", url: `/v1/organizations/${orgId}/handovers/${draft.json().id}/cancel`, headers: auth(token), payload: { reason: "Again" } });
    expect(reopened.statusCode).toBe(200);
    expect(reopened.json().status).toBe("cancelled");

    const replacementReview = await app.inject({ method: "POST", url: `/v1/organizations/${orgId}/handovers/${replacement.json().id}/review`, headers: auth(token), payload: { revision: replacement.json().revision } });
    expect(replacementReview.statusCode, replacementReview.body).toBe(200);
    const completed = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/handovers/${replacement.json().id}/complete`, headers: auth(token),
      payload: { reviewed_revision: replacementReview.json().revision, acknowledged: true },
    });
    expect(completed.statusCode, completed.body).toBe(201);
    expect(completed.json().buyer_user_id).toBe(buyerTwo.id);
    expect(await db.select().from(vehicleHandovers).where(and(eq(vehicleHandovers.orgId, orgId), eq(vehicleHandovers.status, "draft")))).toHaveLength(0);

    const completeAgain = await app.inject({ method: "POST", url: `/v1/organizations/${orgId}/handovers/${replacement.json().id}/cancel`, headers: auth(token), payload: { reason: "Third" } });
    expect(completeAgain.statusCode).toBe(409);
    expect(completeAgain.json().error.code).toBe("handover_completed");

    const changes = await db.select().from(changeLog).where(eq(changeLog.userId, buyerTwo.id));
    expect(changes.some((row) => row.entityType === "handover_receipt")).toBe(true);
    await app.close();
  });
});
