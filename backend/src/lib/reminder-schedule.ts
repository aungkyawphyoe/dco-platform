import { and, desc, eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { planItems, serviceRecordItems, serviceRecords } from "../db/schema.js";
import { dueFrom } from "./catalog.js";

export async function saveReminderBaseline(db: Db, id: string, manual: boolean) {
  const [plan] = await db.select().from(planItems).where(eq(planItems.id, id));
  if (!plan) return;
  const [last] = await db.select({ id: serviceRecords.id }).from(serviceRecords)
    .innerJoin(serviceRecordItems, eq(serviceRecordItems.serviceRecordId, serviceRecords.id))
    .where(eq(serviceRecordItems.planItemId, id))
    .orderBy(desc(serviceRecords.servicedOn), desc(serviceRecords.odometer), desc(serviceRecords.id)).limit(1);
  await db.update(planItems).set({ baselineDueOn: plan.nextDueOn, baselineDueMileage: plan.nextDueMileage,
    baselineEnabled: plan.enabled, manualOn: manual ? new Date().toISOString().slice(0, 10) : null,
    manualServiceId: manual ? last?.id ?? null : null }).where(eq(planItems.id, id));
}

export async function recalculateReminders(db: Db, vehicleId: string) {
  const plans = await db.select().from(planItems).where(eq(planItems.vehicleId, vehicleId)).for("update");
  const changed = [];
  for (const plan of plans) {
    const [last] = await db.select({ id: serviceRecords.id, on: serviceRecords.servicedOn, odometer: serviceRecords.odometer })
      .from(serviceRecords).innerJoin(serviceRecordItems, eq(serviceRecordItems.serviceRecordId, serviceRecords.id))
      .where(and(eq(serviceRecordItems.planItemId, plan.id), eq(serviceRecords.vehicleId, vehicleId)))
      .orderBy(desc(serviceRecords.servicedOn), desc(serviceRecords.odometer), desc(serviceRecords.id)).limit(1);
    const baseline = { nextDueOn: plan.baselineDueOn, nextDueMileage: plan.baselineDueMileage, enabled: plan.baselineEnabled };
    const preserveManual = plan.manualOn && last && (last.on < plan.manualOn || last.id === plan.manualServiceId);
    const recurring = Boolean(plan.timeCount || plan.intervalDays || plan.intervalDistance);
    let values = baseline;
    if (last && !preserveManual) {
      const due = dueFrom(plan.intervalDays, plan.intervalDistance == null ? null : Number(plan.intervalDistance),
        Number(last.odometer ?? 0), last.on, plan.timeCount, plan.timeUnit);
      values = { nextDueOn: recurring ? due.nextDueOn : plan.baselineDueOn,
        nextDueMileage: recurring && due.nextDueMileage != null ? String(due.nextDueMileage) : recurring ? null : plan.baselineDueMileage,
        enabled: recurring && plan.baselineEnabled };
    }
    if (values.enabled && plan.catalogKey && plans.some(other => other.id !== plan.id && other.catalogKey === plan.catalogKey && other.enabled)) {
      values.enabled = false;
    }
    const [updated] = await db.update(planItems).set(values).where(eq(planItems.id, plan.id)).returning();
    changed.push(updated);
  }
  return changed;
}
