import { describe, expect, it } from "vitest";
import { createTestApp } from "./helpers.js";
import { PLAN_IDS } from "../src/lib/plans.js";

type PricingMoney = { mmk: number; usd: number };
type PricingPlan = {
  id: string;
  name: string;
  tagline: string;
  audience: "personal" | "fleet";
  highlighted: boolean;
  prices: { monthly: PricingMoney; annual: PricingMoney };
  limits: { vehicles: number | null; sharing: number | null; storage_bytes: number; ai_tier: string };
  features: string[];
};
type PricingResponse = {
  billing_periods: string[];
  currency: { primary: string; secondary: string };
  plans: PricingPlan[];
  feature_matrix: { category: string; rows: { label: string; values: Record<string, unknown> }[] }[];
};

describe("GET /v1/pricing", () => {
  it("is public and serves all four tiers with registry prices", async () => {
    const { app } = await createTestApp();
    const res = await app.inject({ method: "GET", url: "/v1/pricing" });
    expect(res.statusCode).toBe(200);
    const body = res.json() as PricingResponse;

    expect(body.billing_periods).toEqual(["monthly", "annual"]);
    expect(body.currency).toEqual({ primary: "MMK", secondary: "USD" });
    expect(body.plans.map((p) => p.id)).toEqual([...PLAN_IDS]);

    const byId = Object.fromEntries(body.plans.map((p) => [p.id, p]));
    expect(byId.free.prices).toEqual({ monthly: { mmk: 0, usd: 0 }, annual: { mmk: 0, usd: 0 } });
    expect(byId.lite.prices.monthly.mmk).toBe(3_000);
    expect(byId.lite.prices.annual.mmk).toBe(30_000);
    expect(byId.standard.prices.monthly.mmk).toBe(9_000);
    expect(byId.standard.prices.monthly.usd).toBe(2.99);
    expect(byId.fleet.prices.monthly.mmk).toBe(70_000);
    expect(byId.fleet.prices.annual.usd).toBe(149.99);

    expect(byId.free.limits.vehicles).toBe(1);
    expect(byId.fleet.limits.vehicles).toBeNull();
    expect(byId.standard.limits.sharing).toBeNull();
    expect(byId.fleet.audience).toBe("fleet");
    expect(byId.standard.highlighted).toBe(true);

    await app.close();
  });

  it("serves an as-built feature matrix with fleet-only rows gated off personal tiers", async () => {
    const { app } = await createTestApp();
    const res = await app.inject({ method: "GET", url: "/v1/pricing" });
    const body = res.json() as PricingResponse;

    const categories = body.feature_matrix.map((g) => g.category);
    expect(categories).toContain("Tracking");
    expect(categories).toContain("Maintenance");
    expect(categories).toContain("Garage and sharing");
    expect(categories).toContain("Fleet operations");

    const fleetGroup = body.feature_matrix.find((g) => g.category === "Fleet operations")!;
    for (const row of fleetGroup.rows) {
      expect(row.values.free).toBe(false);
      expect(row.values.lite).toBe(false);
      expect(row.values.standard).toBe(false);
      expect(row.values.fleet).toBe(true);
    }

    const vehiclesRow = body.feature_matrix
      .find((g) => g.category === "Garage and sharing")!
      .rows.find((r) => r.label === "Vehicles")!;
    expect(vehiclesRow.values).toEqual({ free: "1", lite: "3", standard: "10", fleet: "Unlimited" });

    await app.close();
  });

  it("requires no authorization header", async () => {
    const { app } = await createTestApp();
    const res = await app.inject({ method: "GET", url: "/v1/pricing" });
    expect(res.statusCode).toBe(200);
    expect(res.headers.authorization).toBeUndefined();
    await app.close();
  });
});
