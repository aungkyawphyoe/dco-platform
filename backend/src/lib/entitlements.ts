import { and, eq, inArray, isNull, sql } from "drizzle-orm";
import type { Plan } from "./crypto.js";
import type { Db } from "../db/client.js";
import { changeLog, refreshTokens, users, vehicleShares, vehicles } from "../db/schema.js";
import { AppError } from "./errors.js";

const SHARE_LIMITS = {
  free: { perVehicle: 1, total: 3 },
  premium: { perVehicle: 5, total: 20 },
} as const;

export async function changeUserPlan(db: Db, userId: string, nextPlan: Plan) {
  return db.transaction(async (tx) => {
    const [user] = await tx.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!user) throw new AppError(404, "not_found", "User not found");

    if (user.plan === "premium" && nextPlan === "free") {
      // When downgrading to free, revoke excess shares beyond free plan limits
      const limits = SHARE_LIMITS.free;

      // Get user's owned vehicles
      const ownedVehicles = await tx.select().from(vehicles).where(eq(vehicles.userId, userId));
      const ownedVehicleIds = ownedVehicles.map((v) => v.id);

      // Revoke excess shares per vehicle
      for (const vehicleId of ownedVehicleIds) {
        const shares = await tx
          .select()
          .from(vehicleShares)
          .where(and(eq(vehicleShares.vehicleId, vehicleId), eq(vehicleShares.status, "active")))
          .orderBy(sql`${vehicleShares.createdAt} ASC`);

        if (shares.length > limits.perVehicle) {
          const excessShares = shares.slice(limits.perVehicle);
          for (const share of excessShares) {
            await tx.insert(changeLog).values({
              userId: share.userId,
              entityType: "vehicle_share",
              entityId: share.id,
              op: "delete",
              payload: { vehicle_id: share.vehicleId, user_id: share.userId },
            });
            await tx.insert(changeLog).values({
              userId,
              entityType: "vehicle_share",
              entityId: share.id,
              op: "delete",
              payload: { vehicle_id: share.vehicleId, user_id: share.userId },
            });
          }
          await tx.delete(vehicleShares).where(
            inArray(vehicleShares.id, excessShares.map((s) => s.id)),
          );
        }
      }

      // Revoke excess total shares
      const allActiveShares = await tx
        .select({ id: vehicleShares.id, userId: vehicleShares.userId, vehicleId: vehicleShares.vehicleId })
        .from(vehicleShares)
        .innerJoin(vehicles, eq(vehicleShares.vehicleId, vehicles.id))
        .where(and(eq(vehicles.userId, userId), eq(vehicleShares.status, "active")))
        .orderBy(sql`${vehicleShares.createdAt} ASC`);

      if (allActiveShares.length > limits.total) {
        const excessShares = allActiveShares.slice(limits.total);
        for (const share of excessShares) {
          await tx.insert(changeLog).values({
            userId: share.userId,
            entityType: "vehicle_share",
            entityId: share.id,
            op: "delete",
            payload: { vehicle_id: share.vehicleId, user_id: share.userId },
          });
          await tx.insert(changeLog).values({
            userId,
            entityType: "vehicle_share",
            entityId: share.id,
            op: "delete",
            payload: { vehicle_id: share.vehicleId, user_id: share.userId },
          });
        }
        await tx.delete(vehicleShares).where(
          inArray(vehicleShares.id, excessShares.map((s: { id: string }) => s.id)),
        );
      }
    }

    const [updated] = await tx.update(users).set({ plan: nextPlan }).where(eq(users.id, userId)).returning();
    return updated;
  });
}
