import { eq } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import { drivingLicenses, mediaObjects, mediaCleanup, users } from "../db/schema.js";
import { newId } from "../lib/crypto.js";
import { dateOnly, iso, recordChange } from "../lib/dbx.js";
import { AppError } from "../lib/errors.js";
import { documentContentType } from "../lib/document-files.js";
import { storeWithQuota, deleteUnreferencedMedia } from "../lib/storage.js";
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
  if (!license || !license.expiryDate) return null;
  const today = new Date();
  const expiry = new Date(license.expiryDate);
  const diffDays = Math.ceil((expiry.getTime() - today.getTime()) / 86400000);
  if (diffDays < 0) return "expired";
  if (diffDays <= 14) return "expiring_soon";
  return "valid";
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
        expiry_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional().nullable(),
        categories: z.string().optional().nullable(),
        front_media_id: uuid.optional().nullable(),
        back_media_id: uuid.optional().nullable(),
      })
      .parse(request.body);

    const expiryDate = body.expiry_date ? new Date(body.expiry_date) : null;
    if (expiryDate && (Number.isNaN(expiryDate.getTime()) || expiryDate.toISOString().slice(0, 10) !== body.expiry_date)) {
      throw new AppError(400, "invalid_expiry_date", "Enter a valid expiry date");
    }
    if (expiryDate && expiryDate < new Date()) {
      throw new AppError(400, "invalid_expiry_date", "Expiry date must be in the future");
    }

    const cleanup: string[] = [];
    const payload = await db().transaction(async tx => {
      await tx.select().from(users).where(eq(users.id, userId)).for("update");
      const [existing] = await tx.select().from(drivingLicenses).where(eq(drivingLicenses.userId, userId));
      const frontId = body.front_media_id === undefined ? existing?.frontMediaId : body.front_media_id;
      const backId = body.back_media_id === undefined ? existing?.backMediaId : body.back_media_id;
      if (!frontId) throw new AppError(422, "front_required", "Add the front of your driving license");
      for (const mediaId of [...new Set([frontId, backId].filter((id): id is string => !!id))].sort()) {
        const [media] = await tx.select().from(mediaObjects).where(eq(mediaObjects.id, mediaId)).for("update");
        if (!media || media.userId !== userId || media.ownerOrgId || media.vehicleId || !["driving_license", "license_front", "license_back"].includes(media.purpose ?? "")) {
          throw new AppError(422, "invalid_media", "Select your own driving license image");
        }
      }
      const values = { licenseNumber: body.license_number, issuingCountry: body.issuing_country,
        expiryDate: body.expiry_date ?? null, categories: body.categories,
        frontMediaId: frontId, backMediaId: backId ?? null, updatedAt: new Date() };
      const [license] = existing
        ? await tx.update(drivingLicenses).set(values).where(eq(drivingLicenses.id, existing.id)).returning()
        : await tx.insert(drivingLicenses).values({ ...values, id: newId(), userId }).returning();
      for (const id of new Set([existing?.frontMediaId, existing?.backMediaId])) {
        if (id && id !== frontId && id !== backId) {
          cleanup.push(id);
          await tx.insert(mediaCleanup).values({ mediaId: id }).onConflictDoNothing();
        }
      }
      const result = publicDrivingLicense(license);
      await recordChange(tx as unknown as Db, { userId, entityType: "driving_license", entityId: license.id, op: "upsert", payload: result });
      return result;
    });
    await cleanFiles(cleanup);
    return payload;
  });

  async function cleanFiles(ids: string[]) {
    for (const id of ids) {
      try { await db().transaction(tx => deleteUnreferencedMedia(tx as unknown as Db, app.media, id)); }
      catch (error) { app.log.warn({ err: error }, "License cleanup pending; storage remains charged"); }
    }
  }

  app.delete("/users/me/license", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const cleanup: string[] = [];
    await db().transaction(async tx => {
      await tx.select().from(users).where(eq(users.id, userId)).for("update");
      const [license] = await tx.select().from(drivingLicenses).where(eq(drivingLicenses.userId, userId));
      if (!license) return;
      await tx.delete(drivingLicenses).where(eq(drivingLicenses.id, license.id));
      for (const id of new Set([license.frontMediaId, license.backMediaId])) {
        if (id) { cleanup.push(id); await tx.insert(mediaCleanup).values({ mediaId: id }).onConflictDoNothing(); }
      }
      await recordChange(tx as unknown as Db, { userId, entityType: "driving_license", entityId: license.id, op: "delete", payload: { id: license.id } });
    });
    await cleanFiles(cleanup);
    return reply.code(204).send();
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
    if (data.file.truncated) throw new AppError(413, "payload_too_large", "File exceeds 15MB");
    const media = await storeWithQuota(db(), app.media, { id: mediaId, owner: { userId },
      bytes, contentType: documentContentType(bytes, true), purpose: `license_${side}` });

    return reply.code(201).send({ media_id: media.id });
  });

  app.get("/users/:userId/license", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const targetUserId = (request.params as { userId: string }).userId;

    if (targetUserId !== userId) {
      throw new AppError(403, "private_document", "Driving licenses are private");
    }

    const [license] = await db().select().from(drivingLicenses).where(eq(drivingLicenses.userId, targetUserId)).limit(1);
    if (!license) throw new AppError(404, "license_not_found", "No driving license uploaded");
    return publicDrivingLicense(license);
  });
};
