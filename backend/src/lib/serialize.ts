import type { users, vehicles } from "../db/schema.js";
import { dateOnly, iso, num, reqNum } from "./dbx.js";

type UserRow = typeof users.$inferSelect;
type VehicleRow = typeof vehicles.$inferSelect;

export function publicUser(row: UserRow) {
  return {
    id: row.id,
    email: row.email,
    display_name: row.displayName,
    role: row.role,
    plan: row.plan,
    status: row.status,
    email_verified: row.emailVerified,
    active_vehicle_id: row.activeVehicleId,
    vehicle_limit: row.plan === "free" ? 1 : null,
    created_at: iso(row.createdAt),
  };
}

export function publicVehicle(row: VehicleRow, nextMaintenance: unknown = null) {
  return {
    id: row.id,
    user_id: row.userId,
    name: row.name,
    nickname: row.nickname,
    make: row.make,
    model: row.model,
    year: row.year,
    license_plate: row.licensePlate,
    vin: row.vin,
    color: row.color,
    fuel_type: row.fuelType,
    mileage: reqNum(row.mileage),
    mileage_unit: row.mileageUnit,
    purchase_date: dateOnly(row.purchaseDate),
    purchase_price: num(row.purchasePrice),
    photo_media_id: row.photoMediaId,
    archived: row.archived,
    archived_at: iso(row.archivedAt),
    updated_at: iso(row.updatedAt),
    next_maintenance: nextMaintenance,
  };
}
