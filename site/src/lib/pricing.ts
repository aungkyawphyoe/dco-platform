import { PRICING_FALLBACK } from "@/content/pricing-fallback";

export type BillingPeriod = "monthly" | "annual";

export type PricingMoney = { mmk: number; usd: number };

export type PricingLimits = {
  vehicles: number | null;
  sharing: number | null;
  storage_bytes: number;
  ai_tier: string;
};

export type PricingPlan = {
  id: string;
  name: string;
  tagline: string;
  audience: "personal" | "fleet";
  highlighted: boolean;
  prices: { monthly: PricingMoney; annual: PricingMoney };
  limits: PricingLimits;
  features: string[];
};

export type PricingFeatureRow = {
  label: string;
  values: Record<string, boolean | string>;
};

export type PricingFeatureGroup = {
  category: string;
  rows: PricingFeatureRow[];
};

export type PricingResponse = {
  billing_periods: BillingPeriod[];
  currency: { primary: string; secondary: string };
  plans: PricingPlan[];
  feature_matrix: PricingFeatureGroup[];
};

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8080/v1";

/**
 * Server-side fetch of the public pricing catalog. Falls back to a bundled
 * snapshot of docs/pricing.md so the marketing site never breaks when the
 * API is unreachable; revalidate keeps the dynamic path fresh.
 */
export async function getPricing(): Promise<{ data: PricingResponse; live: boolean }> {
  try {
    const res = await fetch(`${API_BASE}/pricing`, { next: { revalidate: 60 } });
    if (!res.ok) throw new Error(`pricing endpoint ${res.status}`);
    return { data: (await res.json()) as PricingResponse, live: true };
  } catch {
    return { data: PRICING_FALLBACK, live: false };
  }
}

/**
 * Translates catalog strings that match a known English source string. Plan
 * names and feature labels may come from the live API or the bundled snapshot;
 * anything unknown passes through unchanged.
 */
export function localizePricing(
  data: PricingResponse,
  catalog: Record<string, string>,
): PricingResponse {
  const translate = (value: string) => catalog[value] ?? value;

  return {
    ...data,
    plans: data.plans.map((plan) => ({
      ...plan,
      name: translate(plan.name),
      tagline: translate(plan.tagline),
      features: plan.features.map(translate),
    })),
    feature_matrix: data.feature_matrix.map((group) => ({
      category: translate(group.category),
      rows: group.rows.map((row) => ({
        label: translate(row.label),
        values: Object.fromEntries(
          Object.entries(row.values).map(([key, value]) => [
            key,
            typeof value === "string" ? translate(value) : value,
          ]),
        ),
      })),
    })),
  };
}

export function formatMmk(amount: number): string {
  return `${amount.toLocaleString("en-US")} MMK`;
}

export function formatUsd(amount: number): string {
  return amount === 0 ? "$0" : `$${amount.toFixed(2).replace(/\.00$/, "")}`;
}

export function formatStorage(bytes: number): string {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) {
    const value = bytes / gb;
    return `${Number.isInteger(value) ? value : value.toFixed(1)} GB`;
  }
  return `${Math.round(bytes / mb)} MB`;
}

export function formatLimit(value: number | null, unlimited = "Unlimited"): string {
  return value === null ? unlimited : String(value);
}
