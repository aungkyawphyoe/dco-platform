/** Plan tiers — mirrors backend src/lib/plans.ts (docs/pricing.md). */
export const PLAN_OPTIONS = [
  { value: "free", label: "Free" },
  { value: "lite", label: "Lite" },
  { value: "standard", label: "Standard" },
  { value: "fleet", label: "Fleet/Pro" },
] as const;

export type Plan = (typeof PLAN_OPTIONS)[number]["value"];
