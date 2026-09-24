import { and, eq, inArray } from "drizzle-orm";
import type { Plan } from "./crypto.js";
import type { Db } from "../db/client.js";
import { changeLog, families, familyMemberships, familyVehicles, refreshTokens, users, vehicleGrants } from "../db/schema.js";
import { AppError } from "./errors.js";

export async function changeUserPlan(db: Db, userId: string, nextPlan: Plan) {
  return db.transaction(async (tx) => {
    const [user] = await tx.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!user) throw new AppError(404, "not_found", "User not found");

    if (user.plan === "premium" && nextPlan === "free") {
      const primaryMemberships = await tx
        .select()
        .from(familyMemberships)
        .where(and(eq(familyMemberships.userId, userId), eq(familyMemberships.role, "primary_owner")));

      for (const membership of primaryMemberships) {
        const members = await tx.select().from(familyMemberships).where(eq(familyMemberships.familyId, membership.familyId));
        const familyVehicleRows = await tx.select().from(familyVehicles).where(eq(familyVehicles.familyId, membership.familyId));
        const memberIds = members.map((row) => row.userId);
        const vehicleIds = familyVehicleRows.map((row) => row.vehicleId);
        const grants = memberIds.length && vehicleIds.length
          ? await tx.select().from(vehicleGrants).where(and(
            inArray(vehicleGrants.userId, memberIds),
            inArray(vehicleGrants.vehicleId, vehicleIds),
          ))
          : [];

        await tx.update(families)
          .set({ status: "archived", archivedAt: new Date() })
          .where(and(eq(families.id, membership.familyId), eq(families.status, "active")));

        if (memberIds.length) {
          for (const familyMember of members) {
            await tx.insert(changeLog).values({
              userId: familyMember.userId,
              entityType: "family",
              entityId: membership.familyId,
              op: "archive",
              payload: { id: membership.familyId, status: "archived" },
            });
            await tx.insert(changeLog).values({
              userId: familyMember.userId,
              entityType: "family_membership",
              entityId: familyMember.id,
              op: "delete",
              payload: { family_id: membership.familyId, user_id: familyMember.userId },
            });
            for (const grant of grants.filter((item) => item.userId === familyMember.userId)) {
              await tx.insert(changeLog).values({
                userId: familyMember.userId,
                entityType: "vehicle_grant",
                entityId: grant.id,
                op: "delete",
                payload: { vehicle_id: grant.vehicleId, user_id: grant.userId },
              });
            }
          }
          await tx.delete(vehicleGrants).where(and(
            inArray(vehicleGrants.userId, memberIds),
            inArray(vehicleGrants.vehicleId, vehicleIds),
          ));
          await tx.update(users).set({ familyId: null }).where(inArray(users.id, memberIds));
          await tx.delete(familyMemberships).where(eq(familyMemberships.familyId, membership.familyId));
          await tx.update(refreshTokens).set({ revokedAt: new Date() }).where(inArray(refreshTokens.userId, memberIds));
        }
      }
    }

    const [updated] = await tx.update(users).set({ plan: nextPlan }).where(eq(users.id, userId)).returning();
    return updated;
  });
}
