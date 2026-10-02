import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import {
  documents,
  expenseParts,
  expenses,
  fuelLogs,
  parts,
  planItems,
  serviceRecordItems,
  serviceRecordParts,
  serviceRecords,
} from "../db/schema.js";
import { dateOnly, num, reqNum } from "./dbx.js";

export function publicPlan(row: typeof planItems.$inferSelect) {
  return {
    id: row.id,
    vehicle_id: row.vehicleId,
    name: row.name,
    interval_days: row.intervalDays,
    interval_distance: num(row.intervalDistance),
    next_due_mileage: num(row.nextDueMileage),
    next_due_on: dateOnly(row.nextDueOn),
    enabled: row.enabled,
    notes: row.notes,
    catalog_key: row.catalogKey,
  };
}

export async function loadService(appDb: Db, id: string) {
  const [row] = await appDb.select().from(serviceRecords).where(eq(serviceRecords.id, id)).limit(1);
  if (!row) return null;
  const items = await appDb.select().from(serviceRecordItems).where(eq(serviceRecordItems.serviceRecordId, id));
  const assigned = await appDb.select().from(serviceRecordParts).where(eq(serviceRecordParts.serviceRecordId, id));
  return {
    id: row.id,
    vehicle_id: row.vehicleId,
    serviced_on: dateOnly(row.servicedOn),
    odometer: reqNum(row.odometer),
    total_cost: reqNum(row.totalCost),
    workshop_name: row.workshopName,
    notes: row.notes,
    receipt_media_id: row.receiptMediaId,
    items: items.map((i) => ({
      id: i.id,
      plan_item_id: i.planItemId,
      name: i.name,
      line_cost: num(i.lineCost),
    })),
    parts: assigned.map((p) => ({ id: p.id, part_id: p.partId, name: p.name })),
  };
}

export function publicPart(row: typeof parts.$inferSelect) {
  return {
    id: row.id,
    vehicle_id: row.vehicleId,
    name: row.name,
    brand: row.brand,
    part_number: row.partNumber,
    notes: row.notes,
  };
}

export function publicFuelLog(row: typeof fuelLogs.$inferSelect) {
  return {
    id: row.id,
    user_id: row.userId,
    vehicle_id: row.vehicleId,
    kind: row.kind,
    fuel_type_id: row.fuelTypeId,
    fuel_type_name: row.fuelTypeName,
    unit: row.unit,
    logged_on: dateOnly(row.loggedOn),
    amount: reqNum(row.amount),
    cost: reqNum(row.cost),
    odometer: row.odometer == null ? null : reqNum(row.odometer),
  };
}

export function publicDoc(row: typeof documents.$inferSelect) {
  return {
    id: row.id,
    vehicle_id: row.vehicleId,
    name: row.name,
    category: row.category,
    notes: row.notes,
    expires_on: dateOnly(row.expiresOn),
    media_id: row.mediaId,
    created_at: row.createdAt.toISOString(),
  };
}

export async function publicExpense(appDb: Db, id: string) {
  const [row] = await appDb.select().from(expenses).where(eq(expenses.id, id)).limit(1);
  if (!row) return null;
  const assigned = await appDb.select().from(expenseParts).where(eq(expenseParts.expenseId, id));
  return {
    id: row.id,
    vehicle_id: row.vehicleId,
    category: row.category,
    amount: reqNum(row.amount),
    incurred_on: dateOnly(row.incurredOn),
    notes: row.notes,
    receipt_media_id: row.receiptMediaId,
    parts: assigned.map((p) => ({ id: p.id, part_id: p.partId, name: p.name })),
  };
}
