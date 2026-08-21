export type Suggested = {
  catalog_key: string;
  name: string;
  interval_days: number | null;
  interval_distance: number | null;
  fuel_type: "petrol" | "electric" | "hybrid_plugin";
};

const ALL: Array<"petrol" | "electric" | "hybrid_plugin"> = ["petrol", "electric", "hybrid_plugin"];
const ENGINE: Array<"petrol" | "electric" | "hybrid_plugin"> = ["petrol", "hybrid_plugin"];

const RAW = [
  { catalog_key: "oil_change", name: "Oil Change", interval_days: 365, interval_distance: 15000, fuels: ENGINE },
  { catalog_key: "air_filter_cabin", name: "Air Filter (Cabin)", interval_days: 365, interval_distance: 15000, fuels: ALL },
  { catalog_key: "new_tires", name: "New Tires", interval_days: 365 * 5, interval_distance: 50000, fuels: ALL },
  { catalog_key: "brake_change", name: "Brake Change", interval_days: null, interval_distance: 30000, fuels: ALL },
  { catalog_key: "brake_fluid", name: "Brake Fluid", interval_days: 365 * 3, interval_distance: 30000, fuels: ALL },
  { catalog_key: "belts", name: "Belts", interval_days: 365 * 5, interval_distance: 80000, fuels: ENGINE },
  { catalog_key: "fuel_filter", name: "Fuel Filter", interval_days: null, interval_distance: 30000, fuels: ENGINE },
  { catalog_key: "wash", name: "Wash", interval_days: 14, interval_distance: null, fuels: ALL },
  { catalog_key: "battery", name: "Battery", interval_days: 365 * 3, interval_distance: 36000, fuels: ALL },
  { catalog_key: "air_conditioning", name: "Air Conditioning", interval_days: 365, interval_distance: null, fuels: ALL },
  { catalog_key: "rotate_tires", name: "Rotate Tires", interval_days: 365, interval_distance: 6000, fuels: ALL },
];

export function suggestedForFuel(fuel: "petrol" | "electric" | "hybrid_plugin"): Suggested[] {
  return RAW.filter((item) => item.fuels.includes(fuel)).map((item) => ({
    catalog_key: item.catalog_key,
    name: item.name,
    interval_days: item.interval_days,
    interval_distance: item.interval_distance,
    fuel_type: fuel,
  }));
}

export const DEFAULT_FUEL_TYPES = [
  { name: "Petrol", kind: "liquid" as const, unit: "L" },
  { name: "Diesel", kind: "liquid" as const, unit: "L" },
  { name: "Electricity", kind: "electric" as const, unit: "kWh" },
];
