import { and, eq } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import { drivingLicenses, mediaObjects, vehicleShares, vehicles } from "../db/schema.js";
import { newId } from "../lib/crypto.js";
import { dateOnly, iso, recordChange } from "../lib/dbx.js";
import { AppError } from "../lib/errors.js";
import { MEDIA_MAX_BYTES } from "../lib/media.js";
import { requireOwner } from "./auth.js";

const uuid = z.string().uuid();

export function publicDrivingLicense(row: typeof drivingLicenses.$inferSelect) {
  return {
    id: row.id,
    user_id: row.userId,
    license_number: row.licenseNumber,
    issuing_country: row.issuingCountry,
    expiry_date: dateOnly(row.expiryDate),
    categories: row.categories,
    front_media_id: row.frontMediaId,
    back_media_id: row.backMediaId,
    created_at: iso(row.createdAt),
    updated_at: iso(row.updatedAt),
  };
}

export async function getLicenseStatus(db: Db, userId: string): Promise<string | null> {
  const [license] = await db.select().from(drivingLicenses).where(eq(drivingLicenses.userId, userId)).limit(1);
  if (!license) return null;
  const today = new Date();
  const expiry = new Date(license.expiryDate);
  const diffDays = Math.ceil((expiry.getTime() - today.getTime()) / 86400000);
  if (diffDays < 0) return "expired";
  if (diffDays <= 14) return "expiring_soon";
  return "valid";
}

/**
 * True when the two users are connected through at least one vehicle share,
 * in either direction (requester owns a vehicle shared with the target, or
 * the other way round).
 */
async function sharesVehicleWith(db: Db, requesterId: string, targetId: string): Promise<boolean> {
  const requesterShares = await db
    .select({ vehicleId: vehicleShares.vehicleId })
    .from(vehicleShares)
    .where(and(eq(vehicleShares.userId, requesterId), eq(vehicleShares.status, "active")));
  const targetShares = await db
    .select({ vehicleId: vehicleShares.vehicleId })
    .from(vehicleShares)
    .where(and(eq(vehicleShares.userId, targetId), eq(vehicleShares.status, "active")));

  const requesterVehicleIds = new Set(requesterShares.map((s) => s.vehicleId));
  if (targetShares.some((s) => requesterVehicleIds.has(s.vehicleId))) return true;

  const [targetOwned] = await db
    .select({ id: vehicles.id })
    .from(vehicles)
    .where(eq(vehicles.userId, targetId))
    .limit(1);
  if (targetOwned && requesterVehicleIds.has(targetOwned.id)) return true;

  const [requesterOwned] = await db
    .select({ id: vehicles.id })
    .from(vehicles)
    .where(eq(vehicles.userId, requesterId))
    .limit(1);
  if (requesterOwned && new Set(targetShares.map((s) => s.vehicleId)).has(requesterOwned.id)) return true;

  return false;
}

export const licensesPlugin: FastifyPluginAsync = async (app) => {
  const db = () => app.db;
  const uid = (request: { authUser?: { sub: string } }) => request.authUser!.sub;

  app.get("/users/me/license", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const [license] = await db().select().from(drivingLicenses).where(eq(drivingLicenses.userId, userId)).limit(1);
    if (!license) throw new AppError(404, "license_not_found", "No driving license uploaded yet");
    return publicDrivingLicense(license);
  });

  app.put("/users/me/license", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const body = z
      .object({
        license_number: z.string().max(50).optional().nullable(),
        issuing_country: z.string().length(2).optional().nullable(),
        expiry_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
        categories: z.string().optional().nullable(),
        front_media_id: uuid.optional().nullable(),
        back_media_id: uuid.optional().nullable(),
      })
      .parse(request.body);

    const expiryDate = new Date(body.expiry_date);
    if (expiryDate < new Date()) {
      throw new AppError(400, "invalid_expiry_date", "Expiry date must be in the future");
    }

    const [existing] = await db().select().from(drivingLicenses).where(eq(drivingLicenses.userId, userId)).limit(1);
    let license;
    if (existing) {
      [license] = await db()
        .update(drivingLicenses)
        .set({
          licenseNumber: body.license_number,
          issuingCountry: body.issuing_country,
          expiryDate: body.expiry_date,
          categories: body.categories,
          frontMediaId: body.front_media_id,
          backMediaId: body.back_media_id,
          updatedAt: new Date(),
        })
        .where(eq(drivingLicenses.userId, userId))
        .returning();
    } else {
      [license] = await db()
        .insert(drivingLicenses)
        .values({
          id: newId(),
          userId,
          licenseNumber: body.license_number,
          issuingCountry: body.issuing_country,
          expiryDate: body.expiry_date,
          categories: body.categories,
          frontMediaId: body.front_media_id,
          backMediaId: body.back_media_id,
        })
        .returning();
    }

    await recordChange(db(), {
      userId,
      entityType: "driving_license",
      entityId: license.id,
      op: "upsert",
      payload: publicDrivingLicense(license),
    });

    return publicDrivingLicense(license);
  });

  app.post("/users/me/license/media", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const data = await request.file({ limits: { fileSize: MEDIA_MAX_BYTES } });
    if (!data) throw new AppError(400, "no_file", "No file uploaded");

    const fields = data.fields as unknown as Record<string, { value?: string } | string[] | undefined>;
    const rawSide = fields.side;
    const side = Array.isArray(rawSide) ? rawSide[0] : (rawSide as { value?: string } | undefined)?.value;
    if (side !== "front" && side !== "back") {
      throw new AppError(400, "invalid_side", "Side must be 'front' or 'back'");
    }

    const chunks: Buffer[] = [];
    let size = 0;
    for await (const chunk of data.file) {
      size += chunk.length;
      if (size > MEDIA_MAX_BYTES) throw new AppError(413, "payload_too_large", "File exceeds 15MB");
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    const bytes = Buffer.concat(chunks);

    const mediaId = newId();
    const stored = await app.media.put(`licenses/${userId}/${mediaId}`, bytes, data.mimetype);
    const [media] = await db()
      .insert(mediaObjects)
      .values({
        id: mediaId,
        userId,
        blobKey: stored.blobKey,
        contentType: data.mimetype,
        byteSize: stored.byteSize,
        sha256: stored.sha256,
        purpose: `license_${side}`,
      })
      .returning();

    return reply.code(201).send({ media_id: media.id });
  });

  app.get("/users/:userId/license", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const targetUserId = (request.params as { userId: string }).userId;

    if (targetUserId !== userId && !(await sharesVehicleWith(db(), userId, targetUserId))) {
      throw new AppError(403, "not_shared", "No shared vehicles between users");
    }

    const [license] = await db().select().from(drivingLicenses).where(eq(drivingLicenses.userId, targetUserId)).limit(1);
    if (!license) throw new AppError(404, "license_not_found", "No driving license uploaded");
    return publicDrivingLicense(license);
  });
};
