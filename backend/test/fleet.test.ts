import { describe, expect, it } from "vitest";
import { createTestApp, testEnv, uuid } from "./helpers.js";

async function signup(app: { inject: Function }, label: string) {
  const email = `${label}-${uuid()}@test.local`;
  const response = await app.inject({
    method: "POST",
    url: "/v1/auth/signup",
    payload: { email, password: "password1", display_name: label },
  }) as { statusCode: number; json: () => { access_token: string; user: { id: string; plan: string } } };
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

describe("Vehicle sharing entitlement", () => {
  it("shares within plan limits, exposes entitlements, and revokes excess shares on downgrade", async () => {
    const { app } = await createTestApp();
    const platformAdmin = await adminToken(app);
    const owner = await signup(app, "share-owner");
    const member = await signup(app, "share-member");
    const second = await signup(app, "share-second");

    const vehicleId = uuid();
    const vehicle = await app.inject({
      method: "POST",
      url: "/v1/vehicles",
      headers: auth(owner.token),
      payload: {
        id: vehicleId, name: "Shared Car", make: "Toyota", model: "Corolla", year: 2021,
        license_plate: `SHR${vehicleId.slice(0, 4)}`, vin: vehicleId.replaceAll("-", "").slice(0, 17),
        fuel_type: "petrol", mileage: 12000,
      },
    });
    expect(vehicle.statusCode).toBe(201);

    // Free plan can share, but only one share per vehicle.
    const share = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
      payload: { method: "code_qr", access_level: "add_edit_own" },
    });
    expect(share.statusCode).toBe(201);
    const joined = await app.inject({
      method: "POST",
      url: "/v1/vehicles/shares/join",
      headers: auth(member.token),
      payload: { code: share.json().share_code },
    });
    expect(joined.statusCode).toBe(201);

    const deniedSecond = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
      payload: { method: "code_qr" },
    });
    expect(deniedSecond.statusCode).toBe(403);
    expect(deniedSecond.json().error.code).toBe("share_limit_reached");

    const memberVehicles = await app.inject({
      method: "GET",
      url: "/v1/vehicles/shared",
      headers: auth(member.token),
    });
    expect(memberVehicles.statusCode).toBe(200);
    expect(
      memberVehicles.json().items.some((v: { id: string }) => v.id === vehicleId),
    ).toBe(true);

    const ownerEntitlements = await app.inject({ method: "GET", url: "/v1/me/entitlements", headers: auth(owner.token) });
    expect(ownerEntitlements.statusCode).toBe(200);
    expect(ownerEntitlements.json().plan).toBe("free");
    expect(ownerEntitlements.json().features.vehicle_sharing).toBe(true);
    expect(ownerEntitlements.json().vehicle_sharing.limits.per_vehicle).toBe(1);
    expect(ownerEntitlements.json().vehicle_sharing.active_shares).toBe(1);

    const service = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/service-records`,
      headers: auth(member.token),
      payload: {
        id: uuid(), serviced_on: "2026-09-10", odometer: 12100, total_cost: 125,
        workshop_name: "Local Garage", items: [{ name: "Oil change", line_cost: 125 }],
      },
    });
    expect(service.statusCode).toBe(201);

    // Lite raises the per-vehicle cap so a second member can join.
    const lite = await app.inject({
      method: "PATCH",
      url: `/v1/admin/users/${owner.id}`,
      headers: auth(platformAdmin),
      payload: { plan: "lite" },
    });
    expect(lite.statusCode).toBe(200);

    const liteEntitlements = await app.inject({ method: "GET", url: "/v1/me/entitlements", headers: auth(owner.token) });
    expect(liteEntitlements.json().vehicle_sharing.limits.per_vehicle).toBe(3);

    const shareSecond = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
      payload: { method: "code_qr", access_level: "view" },
    });
    expect(shareSecond.statusCode).toBe(201);
    const joinSecond = await app.inject({
      method: "POST",
      url: "/v1/vehicles/shares/join",
      headers: auth(second.token),
      payload: { code: shareSecond.json().share_code },
    });
    expect(joinSecond.statusCode).toBe(201);

    // Downgrading back to free revokes shares beyond the free cap.
    const downgraded = await app.inject({
      method: "PATCH",
      url: `/v1/admin/users/${owner.id}`,
      headers: auth(platformAdmin),
      payload: { plan: "free" },
    });
    expect(downgraded.statusCode).toBe(200);

    const afterDowngrade = await app.inject({ method: "GET", url: "/v1/me/entitlements", headers: auth(owner.token) });
    expect(afterDowngrade.json().vehicle_sharing.limits.per_vehicle).toBe(1);
    expect(afterDowngrade.json().vehicle_sharing.active_shares).toBe(1);

    const noLongerShared = await app.inject({
      method: "GET",
      url: `/v1/vehicles/${vehicleId}/plan-items`,
      headers: auth(second.token),
    });
    expect(noLongerShared.statusCode).toBe(403);

    const stillShared = await app.inject({
      method: "GET",
      url: `/v1/vehicles/${vehicleId}/plan-items`,
      headers: auth(member.token),
    });
    expect(stillShared.statusCode).toBe(200);
    await app.close();
  });
});

describe("Enterprise Fleet access", () => {
  it("provisions and activates an org, issues Fleet audience tokens, and enforces role-scoped operations", async () => {
    const { app } = await createTestApp();
    const platformAdmin = await adminToken(app);
    const fleetOwner = await signup(app, "fleet-owner");
    const driver = await signup(app, "driver");
    const mechanic = await signup(app, "mechanic");

    const created = await app.inject({
      method: "POST",
      url: "/v1/admin/organizations",
      headers: auth(platformAdmin),
      payload: { name: "Northside Taxi", type: "taxi_fleet", admin_email: fleetOwner.email },
    });
    expect(created.statusCode).toBe(201);
    const org = created.json();
    expect(org.plan).toBe("enterprise");
    expect(org.status).toBe("pending");

    const blockedLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: fleetOwner.email, password: "password1", surface: "fleet" },
    });
    expect(blockedLogin.statusCode).toBe(403);

    const activated = await app.inject({
      method: "PATCH",
      url: `/v1/admin/organizations/${org.id}/status`,
      headers: auth(platformAdmin),
      payload: { status: "active" },
    });
    expect(activated.statusCode).toBe(200);
    expect(activated.json().activated_by).toBeTruthy();

    const fleetLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: fleetOwner.email, password: "password1", surface: "fleet" },
    });
    expect(fleetLogin.statusCode).toBe(200);
    const fleetToken = fleetLogin.json().access_token as string;
    const personalRouteDenied = await app.inject({ method: "GET", url: "/v1/vehicles", headers: auth(fleetToken) });
    expect(personalRouteDenied.statusCode).toBe(403);
    const context = await app.inject({ method: "GET", url: "/v1/organizations/me", headers: auth(fleetToken) });
    expect(context.statusCode).toBe(200);
    expect(context.json().fleet_access).toBe(true);
    const refreshed = await app.inject({ method: "POST", url: "/v1/auth/refresh", payload: { refresh_token: fleetLogin.json().refresh_token } });
    expect(refreshed.statusCode).toBe(200);
    const refreshedContext = await app.inject({ method: "GET", url: "/v1/organizations/me", headers: auth(refreshed.json().access_token) });
    expect(refreshedContext.statusCode).toBe(200);

    const addDriver = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/members`,
      headers: auth(fleetToken),
      payload: { email: driver.email, role: "org_driver" },
    });
    expect(addDriver.statusCode).toBe(201);
    const addMechanic = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/members`,
      headers: auth(fleetToken),
      payload: { email: mechanic.email, role: "org_mechanic" },
    });
    expect(addMechanic.statusCode).toBe(201);
    const newStaffInvite = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/members`,
      headers: auth(fleetToken),
      payload: { email: `new-staff-${uuid()}@test.local`, role: "org_manager" },
    });
    expect(newStaffInvite.statusCode).toBe(201);
    expect(newStaffInvite.json().account_invitation_sent).toBe(true);
    expect(newStaffInvite.json().organization_invitation_sent).toBe(true);

    const vehicleId = uuid();
    const addedVehicle = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/vehicles`,
      headers: auth(fleetToken),
      payload: {
        id: vehicleId, name: "Taxi 1", make: "Toyota", model: "Camry", year: 2022,
        license_plate: `TAX${vehicleId.slice(0, 4)}`, vin: vehicleId.replaceAll("-", "").slice(0, 17),
        fuel_type: "hybrid_plugin", mileage: 100, lifecycle_template: "taxi_fleet",
      },
    });
    expect(addedVehicle.statusCode).toBe(201);
    expect(addedVehicle.json().status).toBe("available");

    const assignment = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/assignments`,
      headers: auth(fleetToken),
      payload: { vehicle_id: vehicleId, driver_id: driver.id },
    });
    expect(assignment.statusCode).toBe(201);

    const driverFleetLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: driver.email, password: "password1", surface: "fleet" },
    });
    expect(driverFleetLogin.statusCode).toBe(403);
    expect(driverFleetLogin.json().error.code).toBe("portal_access_restricted");

    const driverLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: driver.email, password: "password1" },
    });
    expect(driverLogin.statusCode).toBe(200);
    const driverToken = driverLogin.json().access_token as string;
    const driverVehicles = await app.inject({ method: "GET", url: `/v1/organizations/${org.id}/vehicles`, headers: auth(driverToken) });
    expect(driverVehicles.statusCode).toBe(403);
    expect(driverVehicles.json().error.code).toBe("forbidden");
    const driverVehicle = await app.inject({ method: "GET", url: "/v1/drivers/my-vehicle", headers: auth(driverToken) });
    expect(driverVehicle.statusCode).toBe(200);
    const workOrder = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/work-orders`,
      headers: auth(driverToken),
      payload: { vehicle_id: vehicleId, odometer_km: 120, issue_type: "wear_tear", description: "Brakes are squeaking", urgency: "medium" },
    });
    expect(workOrder.statusCode).toBe(201);
    const ownReports = await app.inject({ method: "GET", url: "/v1/drivers/my-work-orders", headers: auth(driverToken) });
    expect(ownReports.json().items).toHaveLength(1);

    const mechanicLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: mechanic.email, password: "password1", surface: "fleet" },
    });
    const service = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/vehicles/${vehicleId}/service-records`,
      headers: auth(mechanicLogin.json().access_token),
      payload: { serviced_on: "2026-09-10", odometer: 125, total_cost: 80, items: [{ name: "Brake inspection" }] },
    });
    expect(service.statusCode).toBe(201);

    const resolved = await app.inject({
      method: "PATCH",
      url: `/v1/organizations/${org.id}/work-orders/${workOrder.json().id}`,
      headers: auth(fleetToken),
      payload: { status: "in_progress", assigned_to: mechanic.id },
    });
    expect(resolved.statusCode).toBe(200);

    // Owner-audience tokens (the mobile app) may read shared fleet context but
    // must not reach management routes — those are Fleet Portal (dco-fleet) only.
    const mobileSurfaceLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: fleetOwner.email, password: "password1" },
    });
    expect(mobileSurfaceLogin.statusCode).toBe(200);
    const mobileStyleToken = mobileSurfaceLogin.json().access_token as string;
    const membersViaOwnerAudience = await app.inject({ method: "GET", url: `/v1/organizations/${org.id}/members`, headers: auth(mobileStyleToken) });
    expect(membersViaOwnerAudience.statusCode).toBe(403);
    expect(membersViaOwnerAudience.json().error.code).toBe("forbidden");
    const orgContextViaOwnerAudience = await app.inject({ method: "GET", url: "/v1/organizations/me", headers: auth(mobileStyleToken) });
    expect(orgContextViaOwnerAudience.statusCode).toBe(200);

    const suspended = await app.inject({
      method: "PATCH",
      url: `/v1/admin/organizations/${org.id}/status`,
      headers: auth(platformAdmin),
      payload: { status: "suspended" },
    });
    expect(suspended.statusCode).toBe(200);
    const afterSuspension = await app.inject({ method: "GET", url: `/v1/organizations/${org.id}/vehicles`, headers: auth(fleetToken) });
    expect(afterSuspension.statusCode).toBe(403);
    await app.close();
  });

  it("supports CSV inventory, shift mileage, inspections, and analytics", async () => {
    const { app } = await createTestApp();
    const platformAdmin = await adminToken(app);
    const fleetOwner = await signup(app, "ops-owner");
    const driver = await signup(app, "ops-driver");
    const created = await app.inject({
      method: "POST", url: "/v1/admin/organizations", headers: auth(platformAdmin),
      payload: { name: "Ops Fleet", type: "taxi_fleet", admin_email: fleetOwner.email },
    });
    const orgId = created.json().id as string;
    await app.inject({ method: "PATCH", url: `/v1/admin/organizations/${orgId}/status`, headers: auth(platformAdmin), payload: { status: "active" } });
    const ownerFleetLogin = await app.inject({ method: "POST", url: "/v1/auth/login", payload: { email: fleetOwner.email, password: "password1", surface: "fleet" } });
    const ownerToken = ownerFleetLogin.json().access_token as string;
    await app.inject({ method: "POST", url: `/v1/organizations/${orgId}/members`, headers: auth(ownerToken), payload: { email: driver.email, role: "org_driver" } });

    const boundary = "dco-fleet-csv-boundary";
    const vin = uuid().replaceAll("-", "").slice(0, 17);
    const csv = `name,make,model,year,plate,vin,fuel_type,mileage,lifecycle_template\nTaxi CSV,Toyota,Camry,2022,CSV123,${vin},petrol,100,taxi_fleet\n`;
    const csvPayload = `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="fleet.csv"\r\nContent-Type: text/csv\r\n\r\n${csv}\r\n--${boundary}--\r\n`;
    const imported = await app.inject({
      method: "POST",
      url: `/v1/organizations/${orgId}/vehicles/import`,
      headers: { ...auth(ownerToken), "content-type": `multipart/form-data; boundary=${boundary}` },
      payload: csvPayload,
    });
    expect(imported.statusCode).toBe(202);
    const importJobId = imported.json().job_id as string;
    let importResult = await app.inject({
      method: "GET", url: `/v1/organizations/${orgId}/vehicles/import/${importJobId}`, headers: auth(ownerToken),
    });
    for (let attempt = 0; attempt < 20 && importResult.json().status === "processing"; attempt += 1) {
      await new Promise((resolve) => setTimeout(resolve, 10));
      importResult = await app.inject({
        method: "GET", url: `/v1/organizations/${orgId}/vehicles/import/${importJobId}`, headers: auth(ownerToken),
      });
    }
    expect(importResult.json().status).toBe("completed");
    expect(importResult.json().success_count).toBe(1);
    const vehicleId = importResult.json().rows[0].vehicle_id as string;

    const assignment = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/assignments`, headers: auth(ownerToken),
      payload: { vehicle_id: vehicleId, driver_id: driver.id },
    });
    expect(assignment.statusCode).toBe(201);
    const driverLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: driver.email, password: "password1" },
    });
    expect(driverLogin.statusCode).toBe(200);
    const driverToken = driverLogin.json().access_token as string;
    const driverContext = await app.inject({ method: "GET", url: "/v1/drivers/my-vehicle", headers: auth(driverToken) });
    expect(driverContext.statusCode).toBe(200);
    expect(driverContext.json().vehicle.id).toBe(vehicleId);

    const template = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/inspection-templates`, headers: auth(ownerToken),
      payload: { name: "Pre-trip", items: [{ item_name: "Tires", required: true }, { item_name: "Lights", required: true }] },
    });
    expect(template.statusCode).toBe(201);
    const inspection = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/inspections`, headers: auth(driverToken),
      payload: { vehicle_id: vehicleId, template_id: template.json().id, inspection_type: "pre_trip" },
    });
    expect(inspection.statusCode).toBe(201);
    const incomplete = await app.inject({
      method: "PATCH", url: `/v1/organizations/${orgId}/inspections/${inspection.json().id}`, headers: auth(driverToken),
      payload: { items: [{ item_name: "Tires", result: "ok" }] },
    });
    expect(incomplete.statusCode).toBe(400);
    const failed = await app.inject({
      method: "PATCH", url: `/v1/organizations/${orgId}/inspections/${inspection.json().id}`, headers: auth(driverToken),
      payload: { items: [{ item_name: "Tires", result: "not_ok" }, { item_name: "Lights", result: "ok" }] },
    });
    expect(failed.statusCode).toBe(200);
    expect(failed.json().status).toBe("failed");
    const driverInspections = await app.inject({ method: "GET", url: "/v1/drivers/my-inspections", headers: auth(driverToken) });
    expect(driverInspections.json().items).toHaveLength(1);

    const shift = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/shift-mileage`, headers: auth(driverToken),
      payload: { vehicle_id: vehicleId, start_odometer_km: 100 },
    });
    expect(shift.statusCode).toBe(201);
    const endedShift = await app.inject({
      method: "PATCH", url: `/v1/organizations/${orgId}/shift-mileage/${shift.json().id}`, headers: auth(driverToken),
      payload: { end_odometer_km: 150 },
    });
    expect(endedShift.json().km_driven).toBe(50);
    const fleetAnalytics = await app.inject({ method: "GET", url: `/v1/organizations/${orgId}/analytics/fleet`, headers: auth(ownerToken) });
    expect(fleetAnalytics.statusCode).toBe(200);
    expect(fleetAnalytics.json().active_assignments).toBe(1);
    expect(fleetAnalytics.json().open_work_orders).toBe(1);
    const exportReport = await app.inject({ method: "GET", url: `/v1/organizations/${orgId}/reports/export?type=vehicles`, headers: auth(ownerToken) });
    expect(exportReport.statusCode).toBe(200);
    expect(exportReport.headers["content-type"]).toContain("text/csv");
    await app.close();
  });

  it("transfers showroom inventory to a buyer with warranty history", async () => {
    const { app } = await createTestApp();
    const platformAdmin = await adminToken(app);
    const fleetOwner = await signup(app, "dealer-owner");
    const buyer = await signup(app, "buyer");
    const created = await app.inject({
      method: "POST", url: "/v1/admin/organizations", headers: auth(platformAdmin),
      payload: { name: "Used Cars", type: "showroom", admin_email: fleetOwner.email },
    });
    const orgId = created.json().id as string;
    await app.inject({ method: "PATCH", url: `/v1/admin/organizations/${orgId}/status`, headers: auth(platformAdmin), payload: { status: "active" } });
    const fleetLogin = await app.inject({ method: "POST", url: "/v1/auth/login", payload: { email: fleetOwner.email, password: "password1", surface: "fleet" } });
    const fleetToken = fleetLogin.json().access_token as string;
    const vehicleId = uuid();
    const vehicle = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/vehicles`, headers: auth(fleetToken),
      payload: {
        id: vehicleId, name: "Showroom Car", make: "Honda", model: "Civic", year: 2023,
        license_plate: `SHW${vehicleId.slice(0, 4)}`, vin: vehicleId.replaceAll("-", "").slice(0, 17),
        fuel_type: "petrol", mileage: 1200, lifecycle_template: "showroom",
      },
    });
    expect(vehicle.json().status).toBe("inventory");
    await app.inject({ method: "PATCH", url: `/v1/organizations/${orgId}/vehicles/${vehicleId}`, headers: auth(fleetToken), payload: { status: "listed" } });
    await app.inject({ method: "PATCH", url: `/v1/organizations/${orgId}/vehicles/${vehicleId}`, headers: auth(fleetToken), payload: { status: "reserved" } });
    const template = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/warranty-templates`, headers: auth(fleetToken),
      payload: { name: "One year", duration_years: 1, mileage_limit_km: 20000, coverage_categories: ["Engine"] },
    });
    expect(template.statusCode).toBe(201);
    const transfer = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/vehicles/${vehicleId}/transfer`, headers: auth(fleetToken),
      payload: { buyer_email: buyer.email, sale_date: "2026-09-10", current_mileage_km: 1200, warranty_template_id: template.json().id },
    });
    expect(transfer.statusCode).toBe(201);
    const buyerVehicles = await app.inject({ method: "GET", url: "/v1/vehicles", headers: auth(buyer.token) });
    expect(buyerVehicles.json().items.map((item: { id: string }) => item.id)).toContain(vehicleId);
    const warranty = await app.inject({ method: "GET", url: `/v1/vehicles/${vehicleId}/warranty`, headers: auth(buyer.token) });
    expect(warranty.statusCode).toBe(200);
    expect(warranty.json().status).toBe("active");
    const transferred = await app.inject({ method: "GET", url: `/v1/organizations/${orgId}/transferred`, headers: auth(fleetToken) });
    expect(transferred.json().items).toHaveLength(1);
    await app.close();
  });
});

describe("Approved workshop warranty access", () => {
  it("provisions workshop accounts, scopes in-warranty vehicles, and logs service", async () => {
    const { app } = await createTestApp();
    const platformAdmin = await adminToken(app);
    const fleetOwner = await signup(app, "ws-owner");
    const buyer = await signup(app, "ws-buyer");
    const workshopUser = await signup(app, "ws-worker");

    const created = await app.inject({
      method: "POST", url: "/v1/admin/organizations", headers: auth(platformAdmin),
      payload: { name: "City Motors", type: "showroom", admin_email: fleetOwner.email },
    });
    const orgId = created.json().id as string;
    await app.inject({ method: "PATCH", url: `/v1/admin/organizations/${orgId}/status`, headers: auth(platformAdmin), payload: { status: "active" } });
    const fleetLogin = await app.inject({ method: "POST", url: "/v1/auth/login", payload: { email: fleetOwner.email, password: "password1", surface: "fleet" } });
    const fleetToken = fleetLogin.json().access_token as string;

    const partner = await app.inject({
      method: "POST", url: "/v1/admin/partners", headers: auth(platformAdmin),
      payload: { name: "Approved Garage", type: "workshop", status: "verified" },
    });
    expect(partner.statusCode).toBe(201);
    const partnerId = partner.json().id as string;
    const unverified = await app.inject({
      method: "POST", url: "/v1/admin/partners", headers: auth(platformAdmin),
      payload: { name: "Draft Garage", type: "workshop", status: "draft" },
    });
    const unverifiedId = unverified.json().id as string;

    const notVerified = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/workshops`, headers: auth(fleetToken), payload: { partner_id: unverifiedId },
    });
    expect(notVerified.statusCode).toBe(409);
    expect(notVerified.json().error.code).toBe("workshop_not_verified");

    const approved = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/workshops`, headers: auth(fleetToken), payload: { partner_id: partnerId },
    });
    expect(approved.statusCode).toBe(201);
    const duplicate = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/workshops`, headers: auth(fleetToken), payload: { partner_id: partnerId },
    });
    expect(duplicate.statusCode).toBe(409);
    const workshopList = await app.inject({ method: "GET", url: `/v1/organizations/${orgId}/workshops`, headers: auth(fleetToken) });
    expect(workshopList.json().items).toHaveLength(1);

    const unapprovedTemplate = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/warranty-templates`, headers: auth(fleetToken),
      payload: { name: "One year draft", duration_years: 1, mileage_limit_km: 1000, approved_workshop_ids: [unverifiedId] },
    });
    expect(unapprovedTemplate.statusCode).toBe(422);
    expect(unapprovedTemplate.json().error.code).toBe("workshop_not_approved");

    const blockedLogin = await app.inject({
      method: "POST", url: "/v1/auth/login", payload: { email: workshopUser.email, password: "password1", surface: "workshop" },
    });
    expect(blockedLogin.statusCode).toBe(403);
    expect(blockedLogin.json().error.code).toBe("workshop_access_required");

    const linked = await app.inject({
      method: "POST", url: `/v1/admin/partners/${partnerId}/workshop-accounts`, headers: auth(platformAdmin), payload: { email: workshopUser.email },
    });
    expect(linked.statusCode).toBe(201);
    expect(linked.json().account_invitation_sent).toBe(false);

    const workshopLogin = await app.inject({
      method: "POST", url: "/v1/auth/login", payload: { email: workshopUser.email, password: "password1", surface: "workshop" },
    });
    expect(workshopLogin.statusCode).toBe(200);
    const workshopToken = workshopLogin.json().access_token as string;
    const refreshed = await app.inject({ method: "POST", url: "/v1/auth/refresh", payload: { refresh_token: workshopLogin.json().refresh_token } });
    expect(refreshed.statusCode).toBe(200);
    const refreshedVehicles = await app.inject({ method: "GET", url: "/v1/workshops/my-vehicles", headers: auth(refreshed.json().access_token) });
    expect(refreshedVehicles.statusCode).toBe(200);

    const ownerOnWorkshopRoute = await app.inject({ method: "GET", url: "/v1/workshops/my-vehicles", headers: auth(fleetToken) });
    expect(ownerOnWorkshopRoute.statusCode).toBe(403);
    const workshopOnOwnerRoute = await app.inject({ method: "GET", url: "/v1/vehicles", headers: auth(workshopToken) });
    expect(workshopOnOwnerRoute.statusCode).toBe(403);
    const emptyBeforeSale = await app.inject({ method: "GET", url: "/v1/workshops/my-vehicles", headers: auth(workshopToken) });
    expect(emptyBeforeSale.json().items).toHaveLength(0);

    const template = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/warranty-templates`, headers: auth(fleetToken),
      payload: { name: "One year", duration_years: 1, mileage_limit_km: 1000, coverage_categories: ["Engine"], approved_workshop_ids: [partnerId] },
    });
    expect(template.statusCode).toBe(201);
    expect(template.json().approved_workshop_ids).toEqual([partnerId]);

    const vehicleId = uuid();
    const vehicle = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/vehicles`, headers: auth(fleetToken),
      payload: {
        id: vehicleId, name: "Showroom WS", make: "Honda", model: "Civic", year: 2023,
        license_plate: `WSH${vehicleId.slice(0, 4)}`, vin: vehicleId.replaceAll("-", "").slice(0, 17),
        fuel_type: "petrol", mileage: 1200, lifecycle_template: "showroom",
      },
    });
    expect(vehicle.statusCode).toBe(201);
    await app.inject({ method: "PATCH", url: `/v1/organizations/${orgId}/vehicles/${vehicleId}`, headers: auth(fleetToken), payload: { status: "listed" } });
    await app.inject({ method: "PATCH", url: `/v1/organizations/${orgId}/vehicles/${vehicleId}`, headers: auth(fleetToken), payload: { status: "reserved" } });
    const transfer = await app.inject({
      method: "POST", url: `/v1/organizations/${orgId}/vehicles/${vehicleId}/transfer`, headers: auth(fleetToken),
      payload: { buyer_email: buyer.email, sale_date: "2026-09-15", current_mileage_km: 1200, warranty_template_id: template.json().id },
    });
    expect(transfer.statusCode).toBe(201);
    const warranty = await app.inject({ method: "GET", url: `/v1/vehicles/${vehicleId}/warranty`, headers: auth(buyer.token) });
    expect(warranty.json().status).toBe("active");

    const inWarranty = await app.inject({ method: "GET", url: "/v1/workshops/my-vehicles", headers: auth(workshopToken) });
    expect(inWarranty.statusCode).toBe(200);
    expect(inWarranty.json().items).toHaveLength(1);
    expect(inWarranty.json().items[0].vehicle.id).toBe(vehicleId);
    expect(inWarranty.body).not.toContain(buyer.email);

    const regression = await app.inject({
      method: "POST", url: `/v1/workshops/${vehicleId}/service`, headers: auth(workshopToken),
      payload: { serviced_on: "2026-09-20", odometer_km: 1100, total_cost: 100, items: [{ name: "Oil change" }] },
    });
    expect(regression.statusCode).toBe(400);
    expect(regression.json().error.code).toBe("odometer_regression");
    const future = await app.inject({
      method: "POST", url: `/v1/workshops/${vehicleId}/service`, headers: auth(workshopToken),
      payload: { serviced_on: "2026-12-01", odometer_km: 1300, total_cost: 100, items: [{ name: "Oil change" }] },
    });
    expect(future.statusCode).toBe(422);

    const service = await app.inject({
      method: "POST", url: `/v1/workshops/${vehicleId}/service`, headers: auth(workshopToken),
      payload: { serviced_on: "2026-09-20", odometer_km: 1500, total_cost: 240, notes: "Warranty service", items: [{ name: "Oil change", line_cost: 140 }, { name: "Filter", line_cost: 100 }] },
    });
    expect(service.statusCode).toBe(201);
    expect(service.json().workshop_name).toBe("Approved Garage");
    const buyerRecords = await app.inject({ method: "GET", url: `/v1/vehicles/${vehicleId}/service-records`, headers: auth(buyer.token) });
    expect(buyerRecords.statusCode).toBe(200);
    expect(buyerRecords.json().items).toHaveLength(1);
    expect(buyerRecords.json().items[0].workshop_name).toBe("Approved Garage");
    const buyerVehicle = await app.inject({ method: "GET", url: `/v1/vehicles/${vehicleId}`, headers: auth(buyer.token) });
    expect(buyerVehicle.json().mileage).toBe(1500);

    const removed = await app.inject({
      method: "DELETE", url: `/v1/organizations/${orgId}/workshops/${partnerId}`, headers: auth(fleetToken),
    });
    expect(removed.statusCode).toBe(204);
    const afterRemoval = await app.inject({ method: "GET", url: `/v1/organizations/${orgId}/workshops`, headers: auth(fleetToken) });
    expect(afterRemoval.json().items).toHaveLength(0);
    const noLongerVisible = await app.inject({ method: "GET", url: "/v1/workshops/my-vehicles", headers: auth(workshopToken) });
    expect(noLongerVisible.json().items).toHaveLength(0);
    const noFurtherService = await app.inject({
      method: "POST", url: `/v1/workshops/${vehicleId}/service`, headers: auth(workshopToken),
      payload: { serviced_on: "2026-09-21", odometer_km: 1600, total_cost: 50, items: [{ name: "Check" }] },
    });
    expect(noFurtherService.statusCode).toBe(404);
    await app.close();
  });
});

describe("Driver provisioning", () => {
  it("creates driver accounts, deactivates, and reactivates them", async () => {
    const { app, db } = await createTestApp();
    const platformAdmin = await adminToken(app);
    const fleetOwner = await signup(app, "fleet-owner");

    const created = await app.inject({
      method: "POST",
      url: "/v1/admin/organizations",
      headers: auth(platformAdmin),
      payload: { name: "Driver Test Fleet", type: "taxi_fleet", admin_email: fleetOwner.email },
    });
    expect(created.statusCode).toBe(201);
    const org = created.json();

    await app.inject({
      method: "PATCH",
      url: `/v1/admin/organizations/${org.id}/status`,
      headers: auth(platformAdmin),
      payload: { status: "active" },
    });

    const fleetLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: fleetOwner.email, password: "password1", surface: "fleet" },
    });
    expect(fleetLogin.statusCode).toBe(200);
    const fleetToken = fleetLogin.json().access_token as string;

    const createDriver = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/drivers`,
      headers: auth(fleetToken),
      payload: { username: "driver_john", display_name: "John Doe", password: "InitialPass123" },
    });
    expect(createDriver.statusCode).toBe(201);
    const driver = createDriver.json();
    expect(driver.username).toBe("driver_john");
    expect(driver.must_change_password).toBe(true);
    expect(driver.membership.role).toBe("org_driver");
    const driverId = driver.id;

    const loginDriver = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: "driver_john", password: "InitialPass123" },
    });
    expect(loginDriver.statusCode).toBe(200);
    const driverToken = loginDriver.json().access_token as string;

    const fleetReject = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: "driver_john", password: "InitialPass123", surface: "fleet" },
    });
    expect(fleetReject.statusCode).toBe(403);
    expect(fleetReject.json().error.code).toBe("portal_access_restricted");

    const myVehicle = await app.inject({ method: "GET", url: "/v1/drivers/my-vehicle", headers: auth(driverToken) });
    expect(myVehicle.statusCode).toBe(403);
    expect(myVehicle.json().error.code).toBe("password_change_required");

    const changePw = await app.inject({
      method: "POST",
      url: "/v1/auth/change-password",
      headers: auth(driverToken),
      payload: { current_password: "InitialPass123", new_password: "NewPass456" },
    });
    expect(changePw.statusCode).toBe(204);

    const myVehicleAfter = await app.inject({ method: "GET", url: "/v1/drivers/my-vehicle", headers: auth(driverToken) });
    expect(myVehicleAfter.statusCode).toBe(200);
    expect(myVehicleAfter.json().assignment).toBeNull();

    const deactivate = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/members/${driverId}/status`,
      headers: auth(fleetToken),
      payload: { status: "deactivated" },
    });
    expect(deactivate.statusCode).toBe(200);
    expect(deactivate.json().status).toBe("deactivated");

    const loginDeactivated = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: "driver_john", password: "NewPass456" },
    });
    expect(loginDeactivated.statusCode).toBe(401);
    expect(loginDeactivated.json().error.code).toBe("deactivated");

    const reactivate = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/members/${driverId}/status`,
      headers: auth(fleetToken),
      payload: { status: "active" },
    });
    expect(reactivate.statusCode).toBe(200);
    expect(reactivate.json().status).toBe("active");

    const loginReactivated = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: "driver_john", password: "NewPass456" },
    });
    expect(loginReactivated.statusCode).toBe(200);

    const duplicate = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/drivers`,
      headers: auth(fleetToken),
      payload: { username: "driver_john", display_name: "Jane", password: "password1" },
    });
    expect(duplicate.statusCode).toBe(409);
    expect(duplicate.json().error.code).toBe("username_taken");

    await app.close();
  });
});

describe("Fleet maintenance templates", () => {
  it("lists global and org templates, snapshots plans once, and gates driver plan access", async () => {
    const { app } = await createTestApp();
    const platformAdmin = await adminToken(app);
    const fleetOwner = await signup(app, "tpl-owner");
    const driverA = await signup(app, "tpl-driver-a");
    const driverB = await signup(app, "tpl-driver-b");
    const personalOwner = await signup(app, "tpl-personal");

    const created = await app.inject({
      method: "POST",
      url: "/v1/admin/organizations",
      headers: auth(platformAdmin),
      payload: { name: "Template Fleet", type: "taxi_fleet", admin_email: fleetOwner.email },
    });
    expect(created.statusCode).toBe(201);
    const org = created.json();
    const activated = await app.inject({
      method: "PATCH",
      url: `/v1/admin/organizations/${org.id}/status`,
      headers: auth(platformAdmin),
      payload: { status: "active" },
    });
    expect(activated.statusCode).toBe(200);

    const fleetLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: fleetOwner.email, password: "password1", surface: "fleet" },
    });
    expect(fleetLogin.statusCode).toBe(200);
    const fleetToken = fleetLogin.json().access_token as string;

    // Global template list: 11 car + 10 motorcycle + 14 truck + 12 van.
    const list = await app.inject({
      method: "GET",
      url: `/v1/organizations/${org.id}/maintenance-templates`,
      headers: auth(fleetToken),
    });
    expect(list.statusCode).toBe(200);
    expect(list.json().items).toHaveLength(47);
    expect(list.json().items.every((item: { source: string }) => item.source === "global")).toBe(true);

    const truckList = await app.inject({
      method: "GET",
      url: `/v1/organizations/${org.id}/maintenance-templates?vehicle_class=truck`,
      headers: auth(fleetToken),
    });
    expect(truckList.json().items).toHaveLength(14);
    expect(truckList.json().items.every((item: { vehicle_class: string }) => item.vehicle_class === "truck")).toBe(true);

    const electricList = await app.inject({
      method: "GET",
      url: `/v1/organizations/${org.id}/maintenance-templates?fuel_type=electric`,
      headers: auth(fleetToken),
    });
    expect(electricList.json().items.length).toBeGreaterThan(0);
    expect(
      electricList.json().items.every((item: { fuel_types: string[] }) => item.fuel_types.includes("electric")),
    ).toBe(true);

    // Vehicle setup: petrol car in a taxi fleet, with driver A assigned.
    const vehicleId = uuid();
    const addedVehicle = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/vehicles`,
      headers: auth(fleetToken),
      payload: {
        id: vehicleId, name: "Taxi T1", make: "Toyota", model: "Camry", year: 2022,
        license_plate: `TPL${vehicleId.slice(0, 4)}`, vin: vehicleId.replaceAll("-", "").slice(0, 17),
        fuel_type: "petrol", mileage: 100, lifecycle_template: "taxi_fleet",
      },
    });
    expect(addedVehicle.statusCode).toBe(201);
    expect(addedVehicle.json().vehicle_class).toBe("car");

    const addDriverA = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/members`,
      headers: auth(fleetToken),
      payload: { email: driverA.email, role: "org_driver" },
    });
    expect(addDriverA.statusCode).toBe(201);
    const assignA = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/assignments`,
      headers: auth(fleetToken),
      payload: { vehicle_id: vehicleId, driver_id: driverA.id },
    });
    expect(assignA.statusCode).toBe(201);

    // A truck template must not attach to a car.
    const truckTemplateId = list.json().items.find(
      (item: { catalog_key: string }) => item.catalog_key === "truck_engine_oil_filter",
    ).id;
    const mismatched = await app.inject({
      method: "PUT",
      url: `/v1/organizations/${org.id}/vehicles/${vehicleId}/maintenance-template`,
      headers: auth(fleetToken),
      payload: { template_id: truckTemplateId },
    });
    expect(mismatched.statusCode).toBe(400);
    expect(mismatched.json().error.code).toBe("template_mismatch");

    // Global rows are read-only for organizations.
    const oilId = list.json().items.find((item: { catalog_key: string }) => item.catalog_key === "oil_change").id;
    const assignedOil = await app.inject({
      method: "PUT",
      url: `/v1/organizations/${org.id}/vehicles/${vehicleId}/maintenance-template`,
      headers: auth(fleetToken),
      payload: { template_id: oilId },
    });
    expect(assignedOil.statusCode).toBe(200);
    expect(assignedOil.json().maintenance_template_id).toBe(oilId);

    const patchGlobal = await app.inject({
      method: "PATCH",
      url: `/v1/organizations/${org.id}/maintenance-templates/${oilId}`,
      headers: auth(fleetToken),
      payload: { interval_days: 180 },
    });
    expect(patchGlobal.statusCode).toBe(403);
    expect(patchGlobal.json().error.code).toBe("global_template_readonly");
    const deleteGlobal = await app.inject({
      method: "DELETE",
      url: `/v1/organizations/${org.id}/maintenance-templates/${oilId}`,
      headers: auth(fleetToken),
    });
    expect(deleteGlobal.statusCode).toBe(403);

    // Org copy of a global template, with a per-fleet interval override.
    const copyResponse = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/maintenance-templates`,
      headers: auth(fleetToken),
      payload: { source_template_id: oilId, interval_distance: 8000 },
    });
    expect(copyResponse.statusCode).toBe(201);
    const copy = copyResponse.json();
    expect(copy.source).toBe("org");
    expect(copy.name).toBe("Oil Change");
    expect(copy.vehicle_class).toBe("car");
    expect(copy.interval_distance).toBe(8000);
    expect(copy.catalog_key).toMatch(/^oil_change__[a-z0-9]{5}$/);

    const patchedCopy = await app.inject({
      method: "PATCH",
      url: `/v1/organizations/${org.id}/maintenance-templates/${copy.id}`,
      headers: auth(fleetToken),
      payload: { interval_days: 180 },
    });
    expect(patchedCopy.statusCode).toBe(200);
    expect(patchedCopy.json().interval_days).toBe(180);

    const listWithCopy = await app.inject({
      method: "GET",
      url: `/v1/organizations/${org.id}/maintenance-templates`,
      headers: auth(fleetToken),
    });
    const copyInList = listWithCopy.json().items.find((item: { id: string }) => item.id === copy.id);
    expect(copyInList.source).toBe("org");

    // Assign the org copy, then deletion is blocked while referenced.
    const assignedCopy = await app.inject({
      method: "PUT",
      url: `/v1/organizations/${org.id}/vehicles/${vehicleId}/maintenance-template`,
      headers: auth(fleetToken),
      payload: { template_id: copy.id },
    });
    expect(assignedCopy.statusCode).toBe(200);
    expect(assignedCopy.json().maintenance_template_id).toBe(copy.id);
    const deleteAssigned = await app.inject({
      method: "DELETE",
      url: `/v1/organizations/${org.id}/maintenance-templates/${copy.id}`,
      headers: auth(fleetToken),
    });
    expect(deleteAssigned.statusCode).toBe(409);
    expect(deleteAssigned.json().error.code).toBe("template_assigned");

    // Generation without an assignment is rejected.
    const noTemplateVehicleId = uuid();
    const secondVehicle = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/vehicles`,
      headers: auth(fleetToken),
      payload: {
        id: noTemplateVehicleId, name: "Taxi T2", make: "Toyota", model: "Corolla", year: 2021,
        license_plate: `TPX${noTemplateVehicleId.slice(0, 4)}`, vin: noTemplateVehicleId.replaceAll("-", "").slice(0, 17),
        fuel_type: "petrol", mileage: 50, lifecycle_template: "taxi_fleet",
      },
    });
    expect(secondVehicle.statusCode).toBe(201);
    const generateUnassigned = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/vehicles/${noTemplateVehicleId}/maintenance-template/generate`,
      headers: auth(fleetToken),
    });
    expect(generateUnassigned.statusCode).toBe(400);
    expect(generateUnassigned.json().error.code).toBe("template_not_assigned");

    // One-time snapshot: 11 items (org copy overrides the global Oil Change row).
    const generated = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/vehicles/${vehicleId}/maintenance-template/generate`,
      headers: auth(fleetToken),
    });
    expect(generated.statusCode).toBe(200);
    expect(generated.json()).toEqual({ created: 11, skipped: 0 });

    const regenerate = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/vehicles/${vehicleId}/maintenance-template/generate`,
      headers: auth(fleetToken),
    });
    expect(regenerate.statusCode).toBe(200);
    expect(regenerate.json()).toEqual({ created: 0, skipped: 11 });

    // Driver A (owner-audience token) reads the snapshot plan and may extend it.
    const driverLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: driverA.email, password: "password1" },
    });
    expect(driverLogin.statusCode).toBe(200);
    const driverToken = driverLogin.json().access_token as string;

    const driverPlan = await app.inject({
      method: "GET",
      url: `/v1/drivers/vehicles/${vehicleId}/plan-items`,
      headers: auth(driverToken),
    });
    expect(driverPlan.statusCode).toBe(200);
    expect(driverPlan.json().items).toHaveLength(11);
    const oilItem = driverPlan.json().items.find((item: { name: string }) => item.name === "Oil Change");
    expect(oilItem.interval_distance).toBe(8000);
    expect(oilItem.next_due_mileage).toBe(8100);

    const extraId = uuid();
    const addExtra = await app.inject({
      method: "POST",
      url: `/v1/drivers/vehicles/${vehicleId}/plan-items`,
      headers: auth(driverToken),
      payload: { id: extraId, name: "Extra Check", interval_days: 30 },
    });
    expect(addExtra.statusCode).toBe(201);
    const addExtraAgain = await app.inject({
      method: "POST",
      url: `/v1/drivers/vehicles/${vehicleId}/plan-items`,
      headers: auth(driverToken),
      payload: { id: extraId, name: "Extra Check", interval_days: 30 },
    });
    expect(addExtraAgain.statusCode).toBe(201);
    const driverPlanAfter = await app.inject({
      method: "GET",
      url: `/v1/drivers/vehicles/${vehicleId}/plan-items`,
      headers: auth(driverToken),
    });
    expect(driverPlanAfter.json().items).toHaveLength(12);

    const addExtraNoInterval = await app.inject({
      method: "POST",
      url: `/v1/drivers/vehicles/${vehicleId}/plan-items`,
      headers: auth(driverToken),
      payload: { id: uuid(), name: "No Interval" },
    });
    expect(addExtraNoInterval.statusCode).toBe(422);
    expect(addExtraNoInterval.json().error.code).toBe("invalid_interval");

    // Suggested items derive from the assigned template set only (org copy wins by name).
    const driverSuggested = await app.inject({
      method: "GET",
      url: `/v1/drivers/vehicles/${vehicleId}/suggested-plan-items`,
      headers: auth(driverToken),
    });
    expect(driverSuggested.statusCode).toBe(200);
    expect(driverSuggested.json().items).toHaveLength(11);
    expect(
      driverSuggested.json().items.every((item: { vehicle_class: string }) => item.vehicle_class === "car"),
    ).toBe(true);
    expect(
      driverSuggested.json().items.filter((item: { name: string }) => item.name === "Oil Change"),
    ).toHaveLength(1);
    const suggestedOil = driverSuggested.json().items.find((item: { name: string }) => item.name === "Oil Change");
    expect(suggestedOil.interval_days).toBe(180);

    // No assignment on another vehicle → denied; portal routes reject owner surface.
    const unassignedVehicle = await app.inject({
      method: "GET",
      url: `/v1/drivers/vehicles/${uuid()}/suggested-plan-items`,
      headers: auth(driverToken),
    });
    expect(unassignedVehicle.statusCode).toBe(403);
    expect(unassignedVehicle.json().error.code).toBe("driver_not_assigned");
    const portalFromOwnerSurface = await app.inject({
      method: "GET",
      url: `/v1/organizations/${org.id}/maintenance-templates`,
      headers: auth(driverToken),
    });
    expect(portalFromOwnerSurface.statusCode).toBe(403);

    // Driver B on a vehicle without a template sees an empty suggestion list.
    const addDriverB = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/members`,
      headers: auth(fleetToken),
      payload: { email: driverB.email, role: "org_driver" },
    });
    expect(addDriverB.statusCode).toBe(201);
    const assignB = await app.inject({
      method: "POST",
      url: `/v1/organizations/${org.id}/assignments`,
      headers: auth(fleetToken),
      payload: { vehicle_id: noTemplateVehicleId, driver_id: driverB.id },
    });
    expect(assignB.statusCode).toBe(201);
    const driverBLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: driverB.email, password: "password1" },
    });
    const driverBToken = driverBLogin.json().access_token as string;
    const emptySuggested = await app.inject({
      method: "GET",
      url: `/v1/drivers/vehicles/${noTemplateVehicleId}/suggested-plan-items`,
      headers: auth(driverBToken),
    });
    expect(emptySuggested.statusCode).toBe(200);
    expect(emptySuggested.json().items).toHaveLength(0);
    const crossVehicle = await app.inject({
      method: "GET",
      url: `/v1/drivers/vehicles/${vehicleId}/plan-items`,
      headers: auth(driverBToken),
    });
    expect(crossVehicle.statusCode).toBe(403);
    expect(crossVehicle.json().error.code).toBe("driver_not_assigned");

    // Vehicle class can be corrected from the portal.
    const reclass = await app.inject({
      method: "PATCH",
      url: `/v1/organizations/${org.id}/vehicles/${noTemplateVehicleId}`,
      headers: auth(fleetToken),
      payload: { status: "available", vehicle_class: "van" },
    });
    expect(reclass.statusCode).toBe(200);
    expect(reclass.json().vehicle_class).toBe("van");

    // Admin catalog: create/patch global rows with the new fields; org copies stay invisible.
    const spark = await app.inject({
      method: "POST",
      url: "/v1/admin/maintenance-catalog",
      headers: auth(platformAdmin),
      payload: { name: "Spark Plug", fuel_types: ["petrol"], vehicle_class: "motorcycle", interval_days: 90 },
    });
    expect(spark.statusCode).toBe(201);
    expect(spark.json().vehicle_class).toBe("motorcycle");
    const sparkPatched = await app.inject({
      method: "PATCH",
      url: `/v1/admin/maintenance-catalog/${spark.json().id}`,
      headers: auth(platformAdmin),
      payload: { lifecycle_template: "rental" },
    });
    expect(sparkPatched.statusCode).toBe(200);
    expect(sparkPatched.json().lifecycle_template).toBe("rental");

    const adminList = await app.inject({
      method: "GET",
      url: "/v1/admin/maintenance-catalog",
      headers: auth(platformAdmin),
    });
    expect(adminList.json().items).toHaveLength(48);
    expect(
      adminList.json().items.some((item: { id: string }) => item.id === copy.id),
    ).toBe(false);
    const adminMotorcycles = await app.inject({
      method: "GET",
      url: "/v1/admin/maintenance-catalog?vehicle_class=motorcycle",
      headers: auth(platformAdmin),
    });
    expect(adminMotorcycles.json().items).toHaveLength(11);
    const adminPatchCopy = await app.inject({
      method: "PATCH",
      url: `/v1/admin/maintenance-catalog/${copy.id}`,
      headers: auth(platformAdmin),
      payload: { enabled: false },
    });
    expect(adminPatchCopy.statusCode).toBe(403);
    expect(adminPatchCopy.json().error.code).toBe("org_copy_readonly");

    // Personal owner: defaults to car class and only ever sees the car catalog.
    const personalVehicleId = uuid();
    const personalVehicle = await app.inject({
      method: "POST",
      url: "/v1/vehicles",
      headers: auth(personalOwner.token),
      payload: {
        id: personalVehicleId, name: "My Car", make: "Honda", model: "Fit", year: 2020,
        license_plate: `PRC${personalVehicleId.slice(0, 4)}`, vin: personalVehicleId.replaceAll("-", "").slice(0, 17),
        fuel_type: "petrol", mileage: 5000,
      },
    });
    expect(personalVehicle.statusCode).toBe(201);
    expect(personalVehicle.json().vehicle_class).toBe("car");
    const personalSuggested = await app.inject({
      method: "GET",
      url: `/v1/vehicles/${personalVehicleId}/suggested-plan-items`,
      headers: auth(personalOwner.token),
    });
    expect(personalSuggested.statusCode).toBe(200);
    expect(personalSuggested.json().items).toHaveLength(11);
    expect(
      personalSuggested.json().items.every((item: { vehicle_class: string }) => item.vehicle_class === "car"),
    ).toBe(true);

    // Cleanup: clear the assignment, then the org copy can be deleted.
    const cleared = await app.inject({
      method: "PUT",
      url: `/v1/organizations/${org.id}/vehicles/${vehicleId}/maintenance-template`,
      headers: auth(fleetToken),
      payload: { template_id: null },
    });
    expect(cleared.statusCode).toBe(200);
    expect(cleared.json().maintenance_template_id).toBeNull();
    const reassignGlobal = await app.inject({
      method: "PUT",
      url: `/v1/organizations/${org.id}/vehicles/${vehicleId}/maintenance-template`,
      headers: auth(fleetToken),
      payload: { template_id: oilId },
    });
    expect(reassignGlobal.statusCode).toBe(200);
    expect(reassignGlobal.json().maintenance_template_id).toBe(oilId);
    const deleteCopy = await app.inject({
      method: "DELETE",
      url: `/v1/organizations/${org.id}/maintenance-templates/${copy.id}`,
      headers: auth(fleetToken),
    });
    expect(deleteCopy.statusCode).toBe(204);

    await app.close();
  });
});
