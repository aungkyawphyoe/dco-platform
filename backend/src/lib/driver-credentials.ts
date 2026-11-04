import { and, eq } from "drizzle-orm";
import { z } from "zod";
import type { Db } from "../db/client.js";
import { drivingLicenses, organizationMembers, users } from "../db/schema.js";
import { newId } from "../lib/crypto.js";
import { dateOnly, iso, recordChange } from "../lib/dbx.js";
import { AppError } from "../lib/errors.js";

export const licenseNumber = z.string().trim().min(1).max(50).regex(/^[A-Za-z0-9]+$/);
export const licenseExpiry = z.string().date();
export function expiryStatus(date: string | null) {
  if (!date) return null;
  const today = new Date().toISOString().slice(0,10);
  const days = (Date.parse(date) - Date.parse(today)) / 86400000;
  return days < 0 ? "expired" : days <= 30 ? "expiring_soon" : "valid";
}
export async function isDriver(db: Db, userId: string) {
  const [member] = await db.select({id:organizationMembers.id}).from(organizationMembers)
    .where(and(eq(organizationMembers.userId,userId),eq(organizationMembers.role,'org_driver'),eq(organizationMembers.status,'active')));
  return !!member;
}

export function publicDrivingLicense(row: typeof drivingLicenses.$inferSelect) {
  return {
    id: row.id,
    user_id: row.userId,
    license_number: row.licenseNumber,
    license_expiry_date: dateOnly(row.expiryDate),
    created_at: iso(row.createdAt),
    updated_at: iso(row.updatedAt),
  };
}

export const credentialFields = {
  license_number: licenseNumber.nullable().optional(),
  license_expiry_date: licenseExpiry.nullable().optional(),
};
export const credentialBody = z.object(credentialFields).strict();
export async function saveCredentials(tx: Db, userId: string, body: z.infer<typeof credentialBody>) {
  await tx.select().from(users).where(eq(users.id, userId)).for("update");
  const [existing] = await tx.select().from(drivingLicenses).where(eq(drivingLicenses.userId, userId));
  const values = {
    licenseNumber: body.license_number === undefined ? existing?.licenseNumber ?? null : body.license_number,
    expiryDate: body.license_expiry_date === undefined ? existing?.expiryDate ?? null : body.license_expiry_date,
    updatedAt: new Date(),
  };
  if (await isDriver(tx,userId) && (!values.licenseNumber || !values.expiryDate)) {
    throw new AppError(422,"driver_credentials_required","Fleet drivers must provide a license number and expiry date");
  }
  const [license] = existing
    ? await tx.update(drivingLicenses).set(values).where(eq(drivingLicenses.id, existing.id)).returning()
    : await tx.insert(drivingLicenses).values({ ...values, id: newId(), userId }).returning();
  const result = publicDrivingLicense(license);
  await recordChange(tx, { userId, entityType: "driving_license", entityId: license.id, op: "upsert", payload: result });
  return result;
}
