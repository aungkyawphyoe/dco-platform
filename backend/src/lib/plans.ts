/**
 * Plan registry — the single source of truth for tier definitions.
 *
 * Four owner tiers per `docs/pricing.md` (Free / Lite / Standard / Fleet).
 * `plans` table rows (migration 0011) mirror this registry as reference
 * data; tests assert they stay in sync. Enforcement code (share limits,
 * vehicle limits, entitlements, later the license claims) reads from here,
 * never from per-module constants.
 *
 * `null` limits mean unlimited. Fleet/Pro is never sold on the mobile owner
 * surface (`architecture/feature-gating.md` §4) — `fleet` exists as a plan
 * value for fleet-portal accounts.
 */

export const PLAN_IDS = ["free", "lite", "standard", "fleet"] as const;

export type Plan = (typeof PLAN_IDS)[number];

export type AiTier = "base" | "higher" | "highest" | "unlimited";

export type PlanDef = {
  readonly id: Plan;
  readonly name: string;
  /** Max active (non-archived) vehicles; null = unlimited. */
  readonly vehicleLimit: number | null;
  /**
   * Active share cap — one number for both per-vehicle and total, per the
   * pricing.md `sharing_limit` column (free 1, lite 3, null = unlimited).
   */
  readonly sharingLimit: number | null;
  readonly storageBytes: number;
  readonly aiTier: AiTier;
  readonly priceMonthlyMmk: number;
  readonly priceAnnualMmk: number;
  /** Plan-varying feature flags; surfaced in entitlements and license claims. */
  readonly features: Readonly<Record<string, boolean>>;
};

const MB = 1024 * 1024;
const GB = 1024 * MB;

export const PLANS: Record<Plan, PlanDef> = {
  free: {
    id: "free",
    name: "Free",
    vehicleLimit: 1,
    sharingLimit: 1,
    storageBytes: 50 * MB,
    aiTier: "base",
    priceMonthlyMmk: 0,
    priceAnnualMmk: 0,
    features: { data_import_general: false, api_access: false, priority_support: false },
  },
  lite: {
    id: "lite",
    name: "Lite",
    vehicleLimit: 3,
    sharingLimit: 3,
    storageBytes: 150 * MB,
    aiTier: "higher",
    priceMonthlyMmk: 3_000,
    priceAnnualMmk: 30_000,
    features: { data_import_general: true, api_access: false, priority_support: false },
  },
  standard: {
    id: "standard",
    name: "Standard",
    vehicleLimit: 10,
    sharingLimit: null,
    storageBytes: 500 * MB,
    aiTier: "highest",
    priceMonthlyMmk: 9_000,
    priceAnnualMmk: 90_000,
    features: { data_import_general: true, api_access: false, priority_support: true },
  },
  fleet: {
    id: "fleet",
    name: "Fleet/Pro",
    vehicleLimit: null,
    sharingLimit: null,
    storageBytes: 5 * GB,
    aiTier: "unlimited",
    priceMonthlyMmk: 70_000,
    priceAnnualMmk: 700_000,
    features: { data_import_general: true, api_access: true, priority_support: true },
  },
};

export function shareLimits(plan: Plan): { perVehicle: number | null; total: number | null } {
  const limit = PLANS[plan].sharingLimit;
  return { perVehicle: limit, total: limit };
}

export function vehicleLimit(plan: Plan): number | null {
  return PLANS[plan].vehicleLimit;
}

export function isPlan(value: string): value is Plan {
  return (PLAN_IDS as readonly string[]).includes(value);
}
