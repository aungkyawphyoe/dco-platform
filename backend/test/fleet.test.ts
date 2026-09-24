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

describe("Family Premium entitlement", () => {
  it("gates family management, allows free invitees, and revokes access on owner downgrade", async () => {
    const { app } = await createTestApp();
    const platformAdmin = await adminToken(app);
    const owner = await signup(app, "family-owner");
    const member = await signup(app, "family-member");

    const denied = await app.inject({
      method: "POST",
      url: "/v1/families",
      headers: auth(owner.token),
      payload: { name: "Smith Family" },
    });
    expect(denied.statusCode).toBe(403);
    expect(denied.json().error.code).toBe("premium_required");

    const premium = await app.inject({
      method: "PATCH",
      url: `/v1/admin/users/${owner.id}`,
      headers: auth(platformAdmin),
      payload: { plan: "premium" },
    });
    expect(premium.statusCode).toBe(200);

    const vehicleId = uuid();
    const vehicle = await app.inject({
      method: "POST",
      url: "/v1/vehicles",
      headers: auth(owner.token),
      payload: {
        id: vehicleId, name: "Family Car", make: "Toyota", model: "Corolla", year: 2021,
        license_plate: `FAM${vehicleId.slice(0, 4)}`, vin: vehicleId.replaceAll("-", "").slice(0, 17),
        fuel_type: "petrol", mileage: 12000,
      },
    });
    expect(vehicle.statusCode).toBe(201);

    const createdFamily = await app.inject({
      method: "POST",
      url: "/v1/families",
      headers: auth(owner.token),
      payload: { name: "Smith Family" },
    });
    expect(createdFamily.statusCode).toBe(201);
    const family = createdFamily.json();
    const familyVehicle = await app.inject({
      method: "POST",
      url: "/v1/families/me/vehicles",
      headers: auth(owner.token),
      payload: { vehicle_id: vehicleId },
    });
    expect(familyVehicle.statusCode).toBe(201);

    const joined = await app.inject({
      method: "POST",
      url: `/v1/families/${family.id}/join`,
      headers: auth(member.token),
      payload: { code: family.share_code.toLowerCase() },
    });
    expect(joined.statusCode).toBe(200);
    const grant = await app.inject({
      method: "POST",
      url: `/v1/families/${family.id}/vehicle-grants`,
      headers: auth(owner.token),
      payload: { vehicle_id: vehicleId, user_id: member.id, permission: "full" },
    });
    expect(grant.statusCode).toBe(201);

    const entitlements = await app.inject({ method: "GET", url: "/v1/me/entitlements", headers: auth(member.token) });
    expect(entitlements.statusCode).toBe(200);
    expect(entitlements.json().plan).toBe("free");
    expect(entitlements.json().features.family).toBe(true);
    expect(entitlements.json().family.can_manage).toBe(false);

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

    const downgraded = await app.inject({
      method: "PATCH",
      url: `/v1/admin/users/${owner.id}`,
      headers: auth(platformAdmin),
      payload: { plan: "free" },
    });
    expect(downgraded.statusCode).toBe(200);

    const noLongerShared = await app.inject({
      method: "GET",
      url: `/v1/vehicles/${vehicleId}/service-records`,
      headers: auth(member.token),
    });
    expect(noLongerShared.statusCode).toBe(403);
    const familyEntitlements = await app.inject({ method: "GET", url: "/v1/me/entitlements", headers: auth(member.token) });
    expect(familyEntitlements.json().features.family).toBe(false);
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

    const driverLogin = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: driver.email, password: "password1", surface: "fleet" },
    });
    expect(driverLogin.statusCode).toBe(200);
    const driverToken = driverLogin.json().access_token as string;
    const driverVehicles = await app.inject({ method: "GET", url: `/v1/organizations/${org.id}/vehicles`, headers: auth(driverToken) });
    expect(driverVehicles.json().items).toHaveLength(1);
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
    const driverLogin = await app.inject({ method: "POST", url: "/v1/auth/login", payload: { email: driver.email, password: "password1", surface: "fleet" } });
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
