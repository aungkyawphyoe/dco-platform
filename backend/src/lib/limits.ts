import { and, eq, sql } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { vehicles } from "../db/schema.js";
import { AppError } from "./errors.js";
import { PLANS, PLAN_IDS, vehicleLimit, type Plan } from "./plans.js";

/**
 * Server-side plan limit enforcement (`architecture/feature-gating.md` §9).
 *
 * Limits themselves come from `plans.ts` (single source, mirrored by the
 * `plans` table); this module only counts and throws. The error contract
 * is `pricing.md` §Limit Check Response, wrapped in the platform envelope
 * `{ error: { code, message, details } }` — `code` is `LIMIT_EXCEEDED`,
 * the pricing fields live in `details`.
 *
 * Counting is active-only (decision 16): non-archived rows. Over-limit
 * data stays readable/editable — only new creates are blocked (decision 7).
 */

export const LIMIT_URL = "/pricing";

/** Active (non-archived) vehicles owned by the user. */
export async function countActiveVehicles(db: Db, userId: string): Promise<number> {
  const [row] = await db
    .select({ count: sql<number>`count(*)::int` })
    .from(vehicles)
    .where(and(eq(vehicles.userId, userId), eq(vehicles.archived, false)));
  return Number(row?.count ?? 0);
}

/** "Free plan allows 1 vehicle. Upgrade to Lite for 3 vehicles." (pricing.md) */
export function vehicleLimitMessage(plan: Plan, limit: number): string {
  const unit = (n: number) => (n === 1 ? "vehicle" : "vehicles");
  const next = PLAN_IDS.slice(PLAN_IDS.indexOf(plan) + 1)
    .map((id) => PLANS[id])
    .find((p) => p.vehicleLimit !== null && p.vehicleLimit > limit);
  const head = `${PLANS[plan].name} plan allows ${limit} ${unit(limit)}.`;
  return next && next.vehicleLimit !== null
    ? `${head} Upgrade to ${next.name} for ${next.vehicleLimit} ${unit(next.vehicleLimit)}.`
    : head;
}

export async function assertVehicleLimit(db: Db, userId: string, plan: Plan): Promise<void> {
  const limit = vehicleLimit(plan);
  if (limit === null) return; // unlimited tier
  const current = await countActiveVehicles(db, userId);
  if (current >= limit) {
    throw new AppError(403, "LIMIT_EXCEEDED", vehicleLimitMessage(plan, limit), {
      metric: "vehicles",
      current,
      limit,
      upgrade_url: LIMIT_URL,
    });
  }
}
