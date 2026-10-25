import { inArray } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { plans } from "../db/schema.js";
import { PLAN_IDS, type Plan } from "../lib/plans.js";

/**
 * Public pricing endpoint for the marketing site (`site/`).
 *
 * Catalog prices are persisted and published through Admin Plans & Pricing.
 * Limits remain code-controlled reference values. Published prices are not
 * store checkout quotes; Android uses Google Play's localized product data.
 *
 * The feature matrix lists only as-built features per
 * product/production-scope.md + docs/mvp-as-built.md — planned items
 * (PDF reports, AI assistant, receipt scanning, insurance policies) are
 * intentionally omitted until they ship.
 */

type FeatureValue = boolean | string;

type MarketingPlan = {
  readonly tagline: string;
  readonly audience: "personal" | "fleet";
  readonly highlighted: boolean;
  readonly features: readonly string[];
};

const MARKETING: Record<Plan, MarketingPlan> = {
  free: {
    tagline: "Start free — forever",
    audience: "personal",
    highlighted: false,
    features: [
      "Digital garage for 1 vehicle",
      "Fuel and charging logs",
      "Maintenance plan and reminders",
      "Expense tracking",
      "Documents vault",
      "50 MB storage",
    ],
  },
  lite: {
    tagline: "More vehicles, more sharing",
    audience: "personal",
    highlighted: false,
    features: [
      "Everything in Free",
      "3 vehicles",
      "3 sharing invites",
      "150 MB storage",
      "Data import",
    ],
  },
  standard: {
    tagline: "The complete personal garage",
    audience: "personal",
    highlighted: true,
    features: [
      "Everything in Lite",
      "10 vehicles",
      "Unlimited sharing",
      "500 MB storage",
      "Priority support",
    ],
  },
  fleet: {
    tagline: "For businesses and fleets",
    audience: "fleet",
    highlighted: false,
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
};

const YES = true;
const NO = false;
const ALL: Record<Plan, FeatureValue> = { free: YES, lite: YES, standard: YES, fleet: YES };
const FLEET_ONLY: Record<Plan, FeatureValue> = { free: NO, lite: NO, standard: NO, fleet: YES };

const FEATURE_MATRIX = [
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
      {
        label: "Vehicles",
        values: { free: "1", lite: "3", standard: "10", fleet: "Unlimited" },
      },
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
      {
        label: "Priority support",
        values: { free: NO, lite: NO, standard: YES, fleet: YES },
      },
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
];

export const pricingPlugin: FastifyPluginAsync = async (app) => {
  app.get("/pricing", { config: { public: true } }, async (_request, reply) => {
    reply.header("Cache-Control", "no-store");
    const rows = await app.db.select().from(plans).where(inArray(plans.id, [...PLAN_IDS]));
    const byId = new Map(rows.map((row) => [row.id, row]));
    const ordered = PLAN_IDS.map((id) => byId.get(id)).filter((row) => row !== undefined);

    return {
      billing_periods: ["monthly", "annual"] as const,
      currency: { primary: "MMK", secondary: "USD" },
      plans: ordered.map((row) => {
        const marketing = MARKETING[row.id as Plan];
        return {
          id: row.id,
          name: row.name,
          tagline: marketing.tagline,
          audience: marketing.audience,
          highlighted: marketing.highlighted,
          prices: {
            monthly: { mmk: row.priceMonthlyMmk, usd: Number(row.priceMonthlyUsd) },
            annual: { mmk: row.priceAnnualMmk, usd: Number(row.priceAnnualUsd) },
          },
          limits: {
            vehicles: row.vehicleLimit,
            sharing: row.sharingLimit,
            storage_bytes: row.storageBytes,
            ai_tier: row.aiTier,
          },
          features: marketing.features,
        };
      }),
      feature_matrix: FEATURE_MATRIX,
    };
  });
};
