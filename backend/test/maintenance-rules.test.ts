import { expect, it } from "vitest";
import { createTestApp, uuid } from "./helpers.js";

it("logs catalog services, applies calendar repeats, preserves manual targets and restores one-time reminders", async () => {
  const { app } = await createTestApp();
  try {
    const signup = await app.inject({ method: "POST", url: "/v1/auth/signup", payload: { email: `rules-${uuid()}@test.local`, password: "password1" } });
    const headers = { authorization: `Bearer ${signup.json().access_token}` };
    const vehicleId = uuid();
    const createdVehicle = await app.inject({ method: "POST", url: "/v1/vehicles", headers,
      payload: { id: vehicleId, name: "Daily", make: "Honda", model: "Wave", year: 2020, license_plate: vehicleId.slice(0,8), fuel_type: "petrol", mileage: 32000 } });
    expect(createdVehicle.statusCode).toBe(201);
    const planUrl = `/v1/vehicles/${vehicleId}/plan-items`;
    const serviceUrl = `/v1/vehicles/${vehicleId}/service-records`;
    const monthlyId = uuid();
    const monthly = await app.inject({ method: "POST", url: planUrl, headers, payload: {
      id: monthlyId, name: "Oil Change", catalog_key: "oil_change", time_count: 1, time_unit: "months",
      next_due_on: "2026-01-31", warning_days: 14, warning_distance: null,
    } });
    expect(monthly.statusCode).toBe(201);
    expect(monthly.json()).toMatchObject({ time_count: 1, time_unit: "months", warning_days: 14 });
    const oneTimeId = uuid();
    expect((await app.inject({ method: "POST", url: planUrl, headers, payload: {
      id: oneTimeId, name: "Battery", catalog_key: "battery", next_due_on: "2026-02-01",
    } })).statusCode).toBe(201);
    const serviceId = uuid();
    const service = await app.inject({ method: "POST", url: serviceUrl, headers, payload: {
      id: serviceId, serviced_on: "2026-01-31", odometer: null, total_cost: 20,
      items: [{ name: "Oil Change", catalog_key: "oil_change" }, { name: "Battery", catalog_key: "battery" }, { name: "Custom work" }],
    } });
    expect(service.statusCode).toBe(201);
    expect(service.json().odometer).toBeNull();
    const getPlan = async () => (await app.inject({ method: "GET", url: planUrl, headers })).json().items;
    let plans = await getPlan();
    expect(plans.find((row: { id: string }) => row.id === monthlyId).next_due_on).toBe("2026-02-28");
    expect(plans.find((row: { id: string }) => row.id === oneTimeId).enabled).toBe(false);
    const older = await app.inject({ method: "POST", url: serviceUrl, headers, payload: {
      id: uuid(), serviced_on: "2025-12-15", odometer: 10000, total_cost: 0,
      items: [{ name: "Oil Change", plan_item_id: monthlyId }],
    } });
    expect(older.statusCode).toBe(201);
    plans = await getPlan();
    expect(plans.find((row: { id: string }) => row.id === monthlyId).next_due_on).toBe("2026-02-28");
    expect((await app.inject({ method: "PATCH", url: `/v1/plan-items/${monthlyId}`, headers,
      payload: { next_due_on: "2027-01-01" } })).statusCode).toBe(200);
    expect((await app.inject({ method: "PATCH", url: `/v1/service-records/${serviceId}`, headers,
      payload: { serviced_on: "2026-01-30" } })).statusCode).toBe(200);
    plans = await getPlan();
    expect(plans.find((row: { id: string }) => row.id === monthlyId).next_due_on).toBe("2027-01-01");
    expect((await app.inject({ method: "DELETE", url: `/v1/service-records/${serviceId}`, headers })).statusCode).toBe(204);
    plans = await getPlan();
    expect(plans.find((row: { id: string }) => row.id === oneTimeId)).toMatchObject({ enabled: true, next_due_on: "2026-02-01" });
    const distanceId = uuid();
    expect((await app.inject({ method: "POST", url: planUrl, headers, payload: {
      id: distanceId, name: "Tires", interval_distance: 5000, next_due_mileage: 33000,
    } })).statusCode).toBe(201);
    expect((await app.inject({ method: "POST", url: serviceUrl, headers, payload: {
      id: uuid(), serviced_on: "2026-02-01", total_cost: 0, items: [{ name: "Tires", plan_item_id: distanceId }],
    } })).statusCode).toBe(422);
    expect((await app.inject({ method: "GET", url: `/v1/organizations/${uuid()}/maintenance-templates`, headers })).statusCode).toBe(404);
  } finally { await app.close(); }
});
