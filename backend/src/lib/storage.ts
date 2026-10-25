import { assertOrganizationWritable } from "./subscriptions.js";
import { assertPersonalVehicleWritable } from "./subscription-access.js";
import { effectiveSubscription } from "./gifts.js";
import { and, eq, isNull, sql } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { documents, drivingLicenses, expenses, mediaObjects, organizations, serviceRecords, users, vehicles } from "../db/schema.js";
import { AppError } from "./errors.js";
import { PLANS } from "./plans.js";
import type { MediaStore } from "./media.js";

export type StorageOwner = { userId: string; orgId?: string | null };
export const chargedPurpose = (purpose: string) => !["vehicle_photo", "profile_photo"].includes(purpose);

export async function storageUsage(db: Db, owner: StorageOwner) {
  const account = await effectiveSubscription(db, owner.userId);
  if (!account) throw new AppError(404, "not_found", "Account not found");
  const [usage] = await db.select({ bytes: sql<number>`coalesce(sum(${mediaObjects.byteSize}), 0)` }).from(mediaObjects).where(and(
    owner.orgId ? eq(mediaObjects.ownerOrgId, owner.orgId) : and(eq(mediaObjects.userId, owner.userId), isNull(mediaObjects.ownerOrgId)),
    sql`coalesce(${mediaObjects.purpose}, 'document') not in ('vehicle_photo', 'profile_photo')`,
  ));
  return { scope: owner.orgId ? "organization" : "personal", owner_id: owner.orgId ?? owner.userId,
    used_bytes: Number(usage.bytes), limit_bytes: PLANS[owner.orgId ? "fleet" : account.plan].storageBytes };
}

/** Serialize admission on the billing owner, including across API processes. */
export async function storeWithQuota(db: Db, store: MediaStore, input: {
  id: string; owner: StorageOwner; vehicleId?: string | null; purpose: string; bytes: Buffer; contentType: string;
}) {
  if (input.owner.orgId) await assertOrganizationWritable(db, input.owner.orgId);
  else if (input.vehicleId) await assertPersonalVehicleWritable(db, input.vehicleId);
  return db.transaction(async (tx) => {
    if (input.owner.orgId) await tx.select().from(organizations).where(eq(organizations.id, input.owner.orgId)).for("update");
    else await tx.select().from(users).where(eq(users.id, input.owner.userId)).for("update");
    const [existing] = await tx.select().from(mediaObjects).where(eq(mediaObjects.id, input.id));
    if (existing) {
      if (existing.userId !== input.owner.userId || existing.ownerOrgId !== (input.owner.orgId ?? null) || existing.vehicleId !== (input.vehicleId ?? null) || existing.purpose !== input.purpose) {
        throw new AppError(409, "id_conflict", "Media ID already exists");
      }
      return existing;
    }
    const usage = await storageUsage(tx as unknown as Db, input.owner);
    if (chargedPurpose(input.purpose) && usage.used_bytes + input.bytes.length > usage.limit_bytes) {
      throw new AppError(403, "LIMIT_EXCEEDED", "Storage is full. Free space before uploading this file.", {
        metric: "storage_bytes", ...usage, current: usage.used_bytes, limit: usage.limit_bytes, required_bytes: input.bytes.length,
      });
    }
    const stored = await store.put(`${input.owner.orgId ?? input.owner.userId}/${input.id}`, input.bytes, input.contentType);
    const [row] = await tx.insert(mediaObjects).values({ id: input.id, userId: input.owner.userId,
      ownerOrgId: input.owner.orgId ?? null, vehicleId: input.vehicleId ?? null, purpose: input.purpose,
      blobKey: stored.blobKey, byteSize: stored.byteSize, sha256: stored.sha256, contentType: input.contentType }).returning();
    return row;
  });
}

export async function assertDocumentMedia(db: Db, mediaId: string, vehicleId: string) {
  const [row] = await db.select().from(mediaObjects).where(eq(mediaObjects.id, mediaId)).for("update");
  if (!row || row.vehicleId !== vehicleId || !chargedPurpose(row.purpose ?? "document") ||
      ["driving_license", "license_front", "license_back"].includes(row.purpose ?? "")) {
    throw new AppError(422, "invalid_media", "Select a document uploaded for this vehicle");
  }
}


/** Delete only after the last live reference has been removed. Failed object-store
 * deletion retains the usage row, so a retry cannot release the allowance twice. */
export async function deleteUnreferencedMedia(db: Db, store: MediaStore, mediaId: string) {
  const [row] = await db.select().from(mediaObjects).where(eq(mediaObjects.id, mediaId)).for("update");
  if (!row) return;
  for (const [table, column] of [
    [documents, documents.mediaId], [serviceRecords, serviceRecords.receiptMediaId],
    [expenses, expenses.receiptMediaId], [vehicles, vehicles.photoMediaId],
    [users, users.profilePhotoMediaId], [drivingLicenses, drivingLicenses.frontMediaId],
    [drivingLicenses, drivingLicenses.backMediaId],
  ] as const) {
    const refs = await db.select({ id: table.id }).from(table).where(eq(column, mediaId)).limit(1);
    if (refs.length) return;
  }
  await store.delete(row.blobKey);
  await db.delete(mediaObjects).where(eq(mediaObjects.id, mediaId));
}
