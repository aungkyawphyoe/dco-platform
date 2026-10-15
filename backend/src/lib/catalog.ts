import type { maintenanceCatalog } from "../db/schema.js";

export type Suggested = {
  catalog_key: string;
  name: string;
  interval_days: number | null;
  interval_distance: number | null;
  fuel_type: "petrol" | "electric" | "hybrid_plugin";
};

export const DEFAULT_FUEL_TYPES = [
  { name: "Petrol", kind: "liquid" as const, unit: "L" },
  { name: "Diesel", kind: "liquid" as const, unit: "L" },
  { name: "Electricity", kind: "electric" as const, unit: "kWh" },
];

export const VEHICLE_CLASSES = ["car", "motorcycle", "truck", "van", "bus"] as const;

export function dueFrom(
  intervalDays: number | null | undefined,
  intervalDistance: number | null | undefined,
  mileage: number,
) {
  const nextDueOn =
    intervalDays && intervalDays > 0
      ? new Date(Date.now() + intervalDays * 86400000).toISOString().slice(0, 10)
      : null;
  const nextDueMileage =
    intervalDistance && intervalDistance > 0 ? mileage + intervalDistance : null;
  return { nextDueOn, nextDueMileage };
}

/**
 * The maintenance template set for a vehicle: enabled catalog rows (global or
 * the org's own copies) whose vehicle class matches, whose optional lifecycle
 * narrowing is compatible, and whose fuel types include the vehicle's fuel.
 * Rows are deduplicated by name — an org copy overrides the global row it was
 * copied from (copies keep the original name unless renamed).
 */
export function templateSetRows(
  rows: (typeof maintenanceCatalog.$inferSelect)[],
  match: { vehicleClass: string; lifecycleTemplate: string; fuelType: string; orgId: string },
): (typeof maintenanceCatalog.$inferSelect)[] {
  const candidates = rows.filter(
    (row) =>
      row.enabled &&
      row.vehicleClass === match.vehicleClass &&
      (row.lifecycleTemplate == null || row.lifecycleTemplate === match.lifecycleTemplate) &&
      row.fuelTypes.includes(match.fuelType) &&
      (row.orgId == null || row.orgId === match.orgId),
  );
  const byName = new Map<string, typeof maintenanceCatalog.$inferSelect>();
  for (const row of candidates) {
    const key = row.name.trim().toLowerCase();
    const current = byName.get(key);
    if (!current || (current.orgId == null && row.orgId != null)) byName.set(key, row);
  }
  return [...byName.values()].sort(
    (a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name),
  );
}
