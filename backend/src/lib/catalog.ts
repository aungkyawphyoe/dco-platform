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
