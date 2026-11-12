import { sql } from 'drizzle-orm';
import type { AnyPgColumn } from 'drizzle-orm/pg-core';

/** Apply alongside vehicle/actor authorization, never as its replacement. */
export function currentRecord(table: { ownershipPeriodId: AnyPgColumn; vehicleId: AnyPgColumn }) {
  return sql`(
    EXISTS (SELECT 1 FROM vehicle_ownership_periods period
      WHERE period.id = ${table.ownershipPeriodId}
        AND period.vehicle_id = ${table.vehicleId} AND period.ended_at IS NULL)
    OR (${table.ownershipPeriodId} IS NULL
      AND EXISTS (SELECT 1 FROM vehicle_ownership_periods baseline
        WHERE baseline.vehicle_id = ${table.vehicleId} AND baseline.ended_at IS NULL
          AND baseline.origin = 'legacy_baseline')
      AND NOT EXISTS (SELECT 1 FROM transferred_vehicles transferred
        WHERE transferred.vehicle_id = ${table.vehicleId}))
  )`;
}

/** Historical organization access is read-only and requires an authenticated org role. */
export function organizationRecord(table: { ownershipPeriodId: AnyPgColumn; vehicleId: AnyPgColumn }, orgId: string) {
  return sql`EXISTS (SELECT 1 FROM vehicle_ownership_periods period
    WHERE period.id = ${table.ownershipPeriodId} AND period.vehicle_id = ${table.vehicleId}
      AND period.org_id = ${orgId} AND period.ended_at IS NOT NULL)`;
}
