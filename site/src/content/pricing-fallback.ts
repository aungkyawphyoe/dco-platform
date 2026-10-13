import type { PricingResponse } from "@/lib/pricing";

/**
 * Bundled snapshot of docs/pricing.md + backend/src/modules/pricing.ts.
 * Served when GET /v1/pricing is unreachable; keep in sync when tiers change.
 */
const YES = true;
const NO = false;
const ALL = { free: YES, lite: YES, standard: YES, fleet: YES };
const FLEET_ONLY = { free: NO, lite: NO, standard: NO, fleet: YES };
const MB = 1024 * 1024;
const GB = 1024 * MB;

export const PRICING_FALLBACK: PricingResponse = {
  billing_periods: ["monthly", "annual"],
  currency: { primary: "MMK", secondary: "USD" },
  plans: [
    {
      id: "free",
      name: "Free",
      tagline: "Start free — forever",
      audience: "personal",
      highlighted: false,
      prices: { monthly: { mmk: 0, usd: 0 }, annual: { mmk: 0, usd: 0 } },
      limits: { vehicles: 1, sharing: 1, storage_bytes: 50 * MB, ai_tier: "base" },
      features: [
        "Digital garage for 1 vehicle",
        "Fuel and charging logs",
        "Maintenance plan and reminders",
        "Expense tracking",
        "Documents vault",
        "50 MB storage",
      ],
    },
    {
      id: "lite",
      name: "Lite",
      tagline: "More vehicles, more sharing",
      audience: "personal",
      highlighted: false,
      prices: { monthly: { mmk: 3000, usd: 1 }, annual: { mmk: 30000, usd: 10 } },
      limits: { vehicles: 3, sharing: 3, storage_bytes: 150 * MB, ai_tier: "higher" },
      features: [
        "Everything in Free",
        "3 vehicles",
        "3 sharing invites",
        "150 MB storage",
        "Data import",
      ],
    },
    {
      id: "standard",
      name: "Standard",
      tagline: "The complete personal garage",
      audience: "personal",
      highlighted: true,
      prices: { monthly: { mmk: 9000, usd: 2.99 }, annual: { mmk: 90000, usd: 29.99 } },
      limits: { vehicles: 10, sharing: null, storage_bytes: 500 * MB, ai_tier: "highest" },
      features: [
        "Everything in Lite",
        "10 vehicles",
        "Unlimited sharing",
        "500 MB storage",
        "Priority support",
      ],
    },
    {
      id: "fleet",
      name: "Fleet/Pro",
      tagline: "For businesses and fleets",
      audience: "fleet",
      highlighted: false,
      prices: { monthly: { mmk: 70000, usd: 14.99 }, annual: { mmk: 700000, usd: 149.99 } },
      limits: { vehicles: null, sharing: null, storage_bytes: 5 * GB, ai_tier: "unlimited" },
      features: [
        "Everything in Standard",
        "Unlimited vehicles",
        "Organization workspace",
        "Work orders and inspections",
        "Driver assignments",
        "Fleet reports and CSV import",
        "API access",
        "5 GB storage",
      ],
    },
  ],
  feature_matrix: [
    {
      category: "Tracking",
      rows: [
        { label: "Fuel tracking", values: ALL },
        { label: "EV charging tracking", values: ALL },
        { label: "Mileage and odometer", values: ALL },
      ],
    },
    {
      category: "Maintenance",
      rows: [
        { label: "Maintenance tracker", values: ALL },
        { label: "Custom maintenance plan", values: ALL },
        { label: "Reminders (time and distance)", values: ALL },
      ],
    },
    {
      category: "Costs and records",
      rows: [
        { label: "Expense tracking", values: ALL },
        { label: "Receipt photos", values: ALL },
        { label: "Documents vault", values: ALL },
        { label: "CSV data export", values: ALL },
      ],
    },
    {
      category: "Garage and sharing",
      rows: [
        { label: "Vehicles", values: { free: "1", lite: "3", standard: "10", fleet: "Unlimited" } },
        {
          label: "Vehicle sharing",
          values: { free: "1 invite", lite: "3 invites", standard: "Unlimited", fleet: "Unlimited" },
        },
        { label: "Offline-first sync", values: ALL },
      ],
    },
    {
      category: "Support",
      rows: [
        { label: "Priority support", values: { free: NO, lite: NO, standard: YES, fleet: YES } },
      ],
    },
    {
      category: "Fleet operations",
      rows: [
        { label: "Organization workspace", values: FLEET_ONLY },
        { label: "Work orders", values: FLEET_ONLY },
        { label: "Inspections", values: FLEET_ONLY },
        { label: "Driver assignments", values: FLEET_ONLY },
        { label: "Workshop management", values: FLEET_ONLY },
        { label: "Warranty templates", values: FLEET_ONLY },
        { label: "Fleet reports", values: FLEET_ONLY },
        { label: "API access", values: FLEET_ONLY },
      ],
    },
  ],
};
