import { and, eq, lt, sql } from "drizzle-orm";
import type { Db } from "../db/client.js";
import {
  vehicleHandoverEvents,
  vehicleHandovers,
  vehicleWarranties,
  planItems,
  transferredVehicles,
} from "../db/schema.js";
import { recordChange } from "../lib/dbx.js";
import { publicVehicle } from "../lib/serialize.js";
import { publicPlan } from "../lib/serialize-records.js";

const MAX_ATTEMPTS = 10;
const BASE_BACKOFF_MS = 5_000;
const MAX_BACKOFF_MS = 300_000;

interface DeliveryWorkerDeps {
  db: Db;
  log: (level: "info" | "warn" | "error", message: string, meta?: Record<string, unknown>) => void;
}

interface VehicleSnapshot {
  name?: string;
  nickname?: string | null;
  make?: string;
  model?: string;
  year?: number;
  licensePlate?: string;
  vin?: string | null;
  color?: string | null;
  fuelType?: string;
}

export function createDeliveryWorker({ db, log }: DeliveryWorkerDeps) {
  async function runOnce(): Promise<number> {
    const now = new Date();
    const queued = await db
      .select()
      .from(vehicleHandoverEvents)
      .where(
        and(
          eq(vehicleHandoverEvents.status, "queued"),
          lt(vehicleHandoverEvents.attempts, MAX_ATTEMPTS),
        ),
      )
      .limit(100);

    if (queued.length === 0) return 0;

    let delivered = 0;
    for (const event of queued) {
      try {
        await deliverEvent(db, event);
        await db
          .update(vehicleHandoverEvents)
          .set({
            status: "delivered",
            attempts: sql`${vehicleHandoverEvents.attempts} + 1`,
            deliveredAt: new Date(),
          })
          .where(eq(vehicleHandoverEvents.id, event.id));
        delivered++;
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : String(err);
        const nextAttempt = event.attempts + 1;
        const backoffMs = Math.min(
          BASE_BACKOFF_MS * Math.pow(2, nextAttempt - 1),
          MAX_BACKOFF_MS,
        );
        await db
          .update(vehicleHandoverEvents)
          .set({
            status: nextAttempt >= MAX_ATTEMPTS ? "dead" : "queued",
            attempts: nextAttempt,
            lastError: errorMessage,
          })
          .where(eq(vehicleHandoverEvents.id, event.id));
        log("warn", "handover delivery failed", {
          eventId: event.id,
          handoverId: event.handoverId,
          attempt: nextAttempt,
          error: errorMessage,
          nextRetryInMs: nextAttempt < MAX_ATTEMPTS ? backoffMs : "max attempts reached",
        });
      }
    }
    return delivered;
  }

  async function deliverEvent(db: Db, event: typeof vehicleHandoverEvents.$inferSelect): Promise<void> {
    const [handover] = await db
      .select()
      .from(vehicleHandovers)
      .where(eq(vehicleHandovers.id, event.handoverId))
      .limit(1);
    if (!handover) throw new Error(`Handover ${event.handoverId} not found`);

    const buyerId = handover.buyerUserId;
    const vehicleId = handover.vehicleId;

    switch (event.eventType) {
      case "vehicle": {
        const vehicleSnapshot = (handover.vehicleSnapshot ?? {}) as VehicleSnapshot;
        const vehiclePayload = publicVehicle({
          id: vehicleId,
          userId: buyerId,
          orgId: null,
          name: vehicleSnapshot.name ?? "",
          nickname: vehicleSnapshot.nickname ?? null,
          make: vehicleSnapshot.make ?? "",
          model: vehicleSnapshot.model ?? "",
          year: vehicleSnapshot.year ?? 1900,
          licensePlate: vehicleSnapshot.licensePlate ?? "",
          vin: vehicleSnapshot.vin ?? null,
          color: vehicleSnapshot.color ?? null,
          fuelType: vehicleSnapshot.fuelType ?? "petrol",
          mileage: handover.currentMileageKm ?? 0,
          mileageUnit: "km",
          purchaseDate: handover.saleDate ?? null,
          purchasePrice: null,
          purchaseCurrency: "MMK",
          photoMediaId: null,
          archived: false,
          archivedAt: null,
          transferLimitExempt: false,
          updatedAt: handover.completedAt ?? new Date(),
          createdAt: handover.completedAt ?? new Date(),
        } as any);

        await recordChange(db, {
          userId: buyerId,
          entityType: "vehicle",
          entityId: vehicleId,
          op: "upsert",
          payload: vehiclePayload,
        });
        break;
      }
      case "plan": {
        const plans = await db
          .select()
          .from(planItems)
          .where(eq(planItems.vehicleId, vehicleId));
        for (const plan of plans) {
          await recordChange(db, {
            userId: buyerId,
            entityType: "plan_item",
            entityId: plan.id,
            op: "upsert",
            payload: publicPlan(plan),
          });
        }
        break;
      }
      case "warranty": {
        if (!handover.warrantySnapshot) break;
        const [warranty] = await db
          .select()
          .from(vehicleWarranties)
          .where(eq(vehicleWarranties.vehicleId, vehicleId))
          .limit(1);
        if (!warranty) break;
        await recordChange(db, {
          userId: buyerId,
          entityType: "warranty",
          entityId: warranty.id,
          op: "upsert",
          payload: {
            id: warranty.id,
            vehicle_id: vehicleId,
            sale_date: handover.saleDate ? String(handover.saleDate).split("T")[0] : null,
            sale_mileage_km: handover.currentMileageKm ?? null,
            status: "active",
            terms: handover.warrantySnapshot,
          },
        });
        break;
      }
      case "receipt": {
        if (!handover.resultSnapshot) break;
        await recordChange(db, {
          userId: buyerId,
          entityType: "handover_receipt",
          entityId: handover.id,
          op: "upsert",
          payload: { ...handover.resultSnapshot, id: handover.id, vehicle_id: vehicleId },
        });
        break;
      }
      default:
        log("warn", "unknown handover event type", { eventId: event.id, type: event.eventType });
    }
  }

  return { runOnce };
}

export function startDeliveryWorker(deps: DeliveryWorkerDeps, intervalMs = 30_000) {
  const { runOnce } = createDeliveryWorker(deps);
  let running = false;

  async function tick() {
    if (running) return;
    running = true;
    try {
      const delivered = await runOnce();
      if (delivered > 0) {
        deps.log("info", "handover delivery worker cycle completed", { delivered });
      }
    } catch (err) {
      deps.log("error", "handover delivery worker error", {
        error: err instanceof Error ? err.message : String(err),
      });
    } finally {
      running = false;
    }
  }

  const timer = setInterval(tick, intervalMs);
  // Run immediately on start
  void tick();

  return {
    stop: () => clearInterval(timer),
  };
}