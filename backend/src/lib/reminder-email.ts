import { and, eq, isNotNull, isNull, lt, or, sql } from "drizzle-orm";
import type { FastifyInstance } from "fastify";
import type { Db } from "../db/client.js";
import {
  organizationVehicles,
  planItems,
  reminderEmailDeliveries,
  users,
  vehicles,
} from "../db/schema.js";
import { newId } from "./crypto.js";
import type { Mailer } from "./mail.js";

type DeliveryRow = typeof reminderEmailDeliveries.$inferSelect;
export type ReminderEmailKind = "upcoming" | "due";

export const reminderEmailRetryMs = 60 * 60 * 1000;
export const reminderEmailMaxAttempts = 3;

export function reminderCycleKey(dueOn: string | null, dueMileage: number | null): string {
  return `${dueOn ?? ""}|${dueMileage ?? ""}`;
}

function addDays(value: string, days: number): string {
  const date = new Date(`${value}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

export type ReminderEmailCandidate = {
  userId: string;
  vehicleId: string;
  planItemId: string;
  recipient: string;
  vehicleName: string;
  mileage: number;
  mileageUnit: "mi" | "km";
  itemName: string;
  dueOn: string | null;
  dueMileage: number | null;
  leadDays: number;
};

export function reminderEmailKind(candidate: ReminderEmailCandidate, today: string): ReminderEmailKind | null {
  const dueByDate = candidate.dueOn != null && candidate.dueOn <= today;
  const dueByMileage = candidate.dueMileage != null && candidate.dueMileage <= candidate.mileage;
  if (dueByDate || dueByMileage) return "due";
  if (candidate.dueOn != null && today >= addDays(candidate.dueOn, -candidate.leadDays)) {
    return "upcoming";
  }
  return null;
}

async function claimDelivery(
  db: Db,
  candidate: ReminderEmailCandidate,
  kind: ReminderEmailKind,
  cycleKey: string,
  now: Date,
): Promise<DeliveryRow | null> {
  const [inserted] = await db
    .insert(reminderEmailDeliveries)
    .values({
      id: newId(),
      userId: candidate.userId,
      vehicleId: candidate.vehicleId,
      planItemId: candidate.planItemId,
      cycleKey,
      kind,
      recipient: candidate.recipient,
      attempts: 1,
      lastAttemptAt: now,
    })
    .onConflictDoNothing()
    .returning();
  if (inserted) return inserted;

  const [existing] = await db
    .select()
    .from(reminderEmailDeliveries)
    .where(and(
      eq(reminderEmailDeliveries.planItemId, candidate.planItemId),
      eq(reminderEmailDeliveries.cycleKey, cycleKey),
      eq(reminderEmailDeliveries.kind, kind),
    ))
    .limit(1);
  if (!existing) return null;

  // Conditional claim so concurrent scans (multiple API replicas) cannot both
  // send. Only the update that observes an unsent, still-retryable row wins.
  const [claimed] = await db
    .update(reminderEmailDeliveries)
    .set({
      recipient: candidate.recipient,
      attempts: sql`${reminderEmailDeliveries.attempts} + 1`,
      lastAttemptAt: now,
      lastError: null,
    })
    .where(and(
      eq(reminderEmailDeliveries.id, existing.id),
      isNull(reminderEmailDeliveries.sentAt),
      lt(reminderEmailDeliveries.attempts, reminderEmailMaxAttempts),
      or(
        isNull(reminderEmailDeliveries.lastAttemptAt),
        lt(
          reminderEmailDeliveries.lastAttemptAt,
          new Date(now.getTime() - reminderEmailRetryMs),
        ),
      ),
    ))
    .returning();
  return claimed ?? null;
}

export async function scanReminderEmails(input: {
  db: Db;
  mailer: Mailer;
  now?: Date;
}): Promise<{ sent: number; failed: number; skipped: number }> {
  const now = input.now ?? new Date();
  const today = now.toISOString().slice(0, 10);
  const rows = await input.db
    .select({
      userId: users.id,
      recipient: users.email,
      leadDays: users.emailReminderLeadDays,
      vehicleId: vehicles.id,
      vehicleName: vehicles.name,
      vehicleNickname: vehicles.nickname,
      mileage: vehicles.mileage,
      mileageUnit: vehicles.mileageUnit,
      planItemId: planItems.id,
      itemName: planItems.name,
      dueOn: planItems.nextDueOn,
      dueMileage: planItems.nextDueMileage,
    })
    .from(users)
    .innerJoin(vehicles, eq(vehicles.userId, users.id))
    .innerJoin(planItems, eq(planItems.vehicleId, vehicles.id))
    .leftJoin(organizationVehicles, eq(organizationVehicles.vehicleId, vehicles.id))
    .where(and(
      eq(users.emailRemindersEnabled, true),
      eq(users.emailVerified, true),
      eq(users.status, "active"),
      isNotNull(users.email),
      eq(vehicles.archived, false),
      eq(planItems.enabled, true),
      isNull(organizationVehicles.id),
    ));

  let sent = 0;
  let failed = 0;
  let skipped = 0;

  for (const row of rows) {
    if (!row.recipient) continue;
    const dueOn = row.dueOn ? row.dueOn.slice(0, 10) : null;
    const dueMileage = row.dueMileage == null ? null : Number(row.dueMileage);
    if (!dueOn && dueMileage == null) continue;

    const candidate: ReminderEmailCandidate = {
      userId: row.userId,
      vehicleId: row.vehicleId,
      planItemId: row.planItemId,
      recipient: row.recipient,
      vehicleName: row.vehicleNickname || row.vehicleName,
      mileage: Number(row.mileage),
      mileageUnit: row.mileageUnit,
      itemName: row.itemName,
      dueOn,
      dueMileage,
      leadDays: row.leadDays,
    };
    const kind = reminderEmailKind(candidate, today);
    if (!kind) continue;

    const cycleKey = reminderCycleKey(dueOn, dueMileage);
    const delivery = await claimDelivery(input.db, candidate, kind, cycleKey, now);
    if (!delivery) {
      skipped += 1;
      continue;
    }

    try {
      await input.mailer.sendMaintenanceReminder(candidate.recipient, {
        phase: kind,
        vehicleName: candidate.vehicleName,
        itemName: candidate.itemName,
        dueOn,
        dueMileage,
        currentMileage: candidate.mileage,
        mileageUnit: candidate.mileageUnit,
      });
      await input.db
        .update(reminderEmailDeliveries)
        .set({ sentAt: now, lastError: null })
        .where(eq(reminderEmailDeliveries.id, delivery.id));
      sent += 1;
    } catch (error) {
      failed += 1;
      await input.db
        .update(reminderEmailDeliveries)
        .set({ lastError: String(error instanceof Error ? error.message : error).slice(0, 500) })
        .where(eq(reminderEmailDeliveries.id, delivery.id));
    }
  }

  return { sent, failed, skipped };
}

export function startReminderEmailScheduler(app: FastifyInstance, intervalMs: number): () => void {
  let running = false;
  const run = async () => {
    if (running) return;
    running = true;
    try {
      const result = await scanReminderEmails({ db: app.db, mailer: app.mailer });
      if (result.sent > 0 || result.failed > 0) {
        app.log.info(result, "maintenance reminder email scan");
      }
    } catch (error) {
      app.log.error(error, "maintenance reminder email scan failed");
    } finally {
      running = false;
    }
  };

  void run();
  const timer = setInterval(() => void run(), intervalMs);
  timer.unref();
  return () => clearInterval(timer);
}
