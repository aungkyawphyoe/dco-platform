
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
  servicedOn = new Date().toISOString().slice(0, 10),
  timeCount?: number | null,
  timeUnit?: string | null,
) {
  const base = new Date(`${servicedOn}T00:00:00Z`);
  if (timeCount && timeUnit) {
    const day = base.getUTCDate();
    if (timeUnit === "days") base.setUTCDate(day + timeCount);
    else {
      base.setUTCDate(1);
      base.setUTCMonth(base.getUTCMonth() + timeCount * (timeUnit === "years" ? 12 : 1));
      const lastDay = new Date(Date.UTC(base.getUTCFullYear(), base.getUTCMonth() + 1, 0)).getUTCDate();
      base.setUTCDate(Math.min(day, lastDay));
    }
  }
  const nextDueOn = timeCount && timeUnit ? base.toISOString().slice(0, 10) :
    intervalDays && intervalDays > 0
      ? new Date(Date.parse(`${servicedOn}T00:00:00Z`) + intervalDays * 86400000).toISOString().slice(0, 10)
      : null;
  const nextDueMileage =
    intervalDistance && intervalDistance > 0 ? mileage + intervalDistance : null;
  return { nextDueOn, nextDueMileage };
}
