import { createHash } from "node:crypto";

export const DEFAULT_FUEL_TYPES = [
  { name: "95 Octane gasoline (petrol)", kind: "liquid" as const, unit: "L" },
  { name: "92 Octane gasoline (petrol)", kind: "liquid" as const, unit: "L" },
  { name: "Diesel", kind: "liquid" as const, unit: "L" },
  { name: "Premium Diesel", kind: "liquid" as const, unit: "L" },
  { name: "CNG", kind: "liquid" as const, unit: "L" },
  { name: "LPG", kind: "liquid" as const, unit: "L" },
  { name: "Electric (Fast)", kind: "electric" as const, unit: "kWh" },
  { name: "Electric (Slow)", kind: "electric" as const, unit: "kWh" },
];

// RFC 4122 UUID v5, DNS namespace; shared with mobile default seeding.
export function defaultFuelTypeId(userId: string, name: string): string {
  const bytes = createHash("sha1").update(Buffer.from("6ba7b8109dad11d180b400c04fd430c8", "hex"))
    .update(`autox:fuel:${userId}:${name}`).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 15) | 80;
  bytes[8] = (bytes[8] & 63) | 128;
  const hex = bytes.toString("hex");
  return `${hex.slice(0,8)}-${hex.slice(8,12)}-${hex.slice(12,16)}-${hex.slice(16,20)}-${hex.slice(20)}`;
}

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
