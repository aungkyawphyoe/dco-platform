import { createHash } from "node:crypto";
import type { FastifyPluginAsync } from "fastify";
import { and, eq, isNull } from "drizzle-orm";
import { mediaObjects, mediaCleanup, documents, expenses, serviceRecords, vehicles, organizationVehicles, driverAssignments } from "../db/schema.js";
import { AppError } from "../lib/errors.js";
import { recordChange } from "../lib/dbx.js";
import { MEDIA_MAX_BYTES } from "../lib/media.js";
import { requireOwner, requireFleetClient, requireFleetPortal } from "./auth.js";
import { z } from "zod";
import { documentContentType } from "../lib/document-files.js";
import { storeWithQuota, storageUsage, deleteUnreferencedMedia } from "../lib/storage.js";
import { getVehicleAccessLevel } from "./vehicle-shares.js";
import { getOrganizationAccess, assertPasswordChangeClear } from "./fleet.js";

export const mediaPlugin: FastifyPluginAsync = async (app) => {
  async function mediaVehicles(mediaId: string) {
    return [
      ...await app.db.select({ vehicleId: documents.vehicleId }).from(documents).where(eq(documents.mediaId, mediaId)),
      ...await app.db.select({ vehicleId: expenses.vehicleId }).from(expenses).where(eq(expenses.receiptMediaId, mediaId)),
      ...await app.db.select({ vehicleId: serviceRecords.vehicleId }).from(serviceRecords).where(eq(serviceRecords.receiptMediaId, mediaId)),
      ...await app.db.select({ vehicleId: vehicles.id }).from(vehicles).where(eq(vehicles.photoMediaId, mediaId)),
    ];
  }
  async function assertPersonalMedia(mediaId: string) {
    const [media] = await app.db.select().from(mediaObjects).where(eq(mediaObjects.id, mediaId));
    if (media?.ownerOrgId) throw new AppError(403, "organization_media", "Use authenticated organization media access");
    for (const ref of await mediaVehicles(mediaId)) {
      const [link] = await app.db.select().from(organizationVehicles).where(eq(organizationVehicles.vehicleId, ref.vehicleId));
      if (link) throw new AppError(403, "organization_media", "Use authenticated organization media access");
    }
  }

  app.get("/organizations/:orgId/media/:mediaId/content", async (request, reply) => {
    requireFleetClient(request);
    const { orgId, mediaId } = request.params as { orgId: string; mediaId: string };
    const userId = request.authUser!.sub;
    const { membership } = await getOrganizationAccess(app.db, userId, orgId, ["org_admin", "org_driver"]);
    await assertPasswordChangeClear(app.db, userId);
    if (membership.role === "org_admin") requireFleetPortal(request); else requireOwner(request);
    const refs = await mediaVehicles(mediaId);
    let allowed = false;
    for (const ref of refs) {
      const [link] = await app.db.select().from(organizationVehicles).where(and(eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, ref.vehicleId)));
      if (!link) continue;
      if (membership.role === "org_admin") { allowed = true; break; }
      const [assignment] = await app.db.select().from(driverAssignments).where(and(eq(driverAssignments.orgId, orgId), eq(driverAssignments.vehicleId, ref.vehicleId), eq(driverAssignments.driverId, userId), eq(driverAssignments.status, "active")));
      if (assignment) { allowed = true; break; }
    }
    if (!allowed) throw new AppError(404, "not_found", "Media not found");
    const [row] = await app.db.select().from(mediaObjects).where(eq(mediaObjects.id, mediaId));
    if (!row) throw new AppError(404, "not_found", "Media not found");
    return reply.header("Cache-Control", "private, no-store").type(row.contentType).send(await app.media.get(row.blobKey));
  });

  app.post("/media", async (request, reply) => {
    requireFleetClient(request);
    const file = await request.file();
    if (!file) throw new AppError(422, "missing_file", "file is required");
    const fields = file.fields as Record<string, { value?: string } | undefined>;
    const id = fields.id?.value;
    const purpose = fields.purpose?.value;
    if (!id) throw new AppError(422, "missing_id", "id is required");
    z.string().uuid().parse(id);
    const mediaPurpose = z.enum(["vehicle_photo", "document", "service_receipt", "expense_receipt", "driving_license"]).parse(purpose);
    const vehicleId = fields.vehicle_id?.value;
    let orgId: string | null = null;
    let ownerId = request.authUser!.sub;
    if (vehicleId) {
      z.string().uuid().parse(vehicleId);
      const [vehicle] = await app.db.select().from(vehicles).where(eq(vehicles.id, vehicleId));
      if (!vehicle) throw new AppError(404, "not_found", "Vehicle not found");
      const [link] = await app.db.select().from(organizationVehicles).where(eq(organizationVehicles.vehicleId, vehicleId));
      if (link) {
        const { membership } = await getOrganizationAccess(app.db, ownerId, link.orgId, ["org_admin", "org_driver"]);
        await assertPasswordChangeClear(app.db, ownerId);
        if (membership.role === "org_admin") requireFleetPortal(request);
        else {
          requireOwner(request);
          const [assignment] = await app.db.select().from(driverAssignments).where(and(eq(driverAssignments.orgId, link.orgId), eq(driverAssignments.vehicleId, vehicleId), eq(driverAssignments.driverId, ownerId), eq(driverAssignments.status, "active")));
          if (!assignment) throw new AppError(403, "not_assigned_to_vehicle", "Vehicle access is required");
        }
        orgId = link.orgId;

      } else {
        requireOwner(request);
        if (vehicle.userId !== ownerId) throw new AppError(403, "insufficient_permission", "Only the vehicle owner can upload documents");
      }
    } else requireOwner(request);
    if (mediaPurpose === "driving_license" && vehicleId) throw new AppError(422, "invalid_scope", "Driving licenses are personal");
    if (["document", "service_receipt", "expense_receipt"].includes(mediaPurpose) && !vehicleId) throw new AppError(422, "missing_vehicle", "vehicle_id is required");
    const chunks: Buffer[] = [];
    let size = 0;
    for await (const chunk of file.file) {
      size += chunk.length;
      if (size > MEDIA_MAX_BYTES) throw new AppError(413, "payload_too_large", "File exceeds 15MB");
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    const bytes = Buffer.concat(chunks);
    if (file.file.truncated) throw new AppError(413, "payload_too_large", "File exceeds 15MB");
    const contentType = documentContentType(bytes, mediaPurpose === "driving_license" || mediaPurpose === "vehicle_photo");
    const row = await storeWithQuota(app.db, app.media, {
      id, owner: { userId: ownerId, orgId }, vehicleId, purpose: mediaPurpose, bytes, contentType,
    });
    const payload = toMediaJson(app, row);
    await recordChange(app.db, {
      userId: request.authUser!.sub,
      entityType: "media",
      entityId: row.id,
      op: "upsert",
      payload,
    });
    return reply.code(201).send(payload);
  });

  async function retryCleanup(userId: string, orgId?: string) {
    const pending = await app.db.select({ id: mediaObjects.id }).from(mediaCleanup)
      .innerJoin(mediaObjects, eq(mediaCleanup.mediaId, mediaObjects.id))
      .where(orgId ? eq(mediaObjects.ownerOrgId, orgId) : and(eq(mediaObjects.userId, userId), isNull(mediaObjects.ownerOrgId))).limit(50);
    for (const row of pending) {
      try { await app.db.transaction(tx => deleteUnreferencedMedia(tx as unknown as import("../db/client.js").Db, app.media, row.id)); }
      catch (error) { app.log.warn({ err: error }, "Media cleanup will retry"); }
    }
  }

  app.get("/users/me/storage", async (request) => {
    requireOwner(request);
    await retryCleanup(request.authUser!.sub);
    return storageUsage(app.db, { userId: request.authUser!.sub });
  });

  app.get("/organizations/:orgId/storage", async (request) => {
    requireFleetClient(request);
    const { orgId } = request.params as { orgId: string };
    await getOrganizationAccess(app.db, request.authUser!.sub, orgId, ["org_admin", "org_driver"]);
    await assertPasswordChangeClear(app.db, request.authUser!.sub);
    await retryCleanup(request.authUser!.sub, orgId);
    return storageUsage(app.db, { userId: request.authUser!.sub, orgId });
  });

  app.get("/media/:mediaId", async (request) => {
    const { mediaId } = request.params as { mediaId: string };
    await assertPersonalMedia(mediaId);
    const token = (request.query as { token?: string }).token;
    const [row] = await app.db.select().from(mediaObjects).where(eq(mediaObjects.id, mediaId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Media not found");
    if (token) {
      if (!app.media.verifyDownload(mediaId, token)) throw new AppError(401, "unauthorized", "Invalid download token");
    } else {
      requireOwner(request);
      if (row.userId !== request.authUser!.sub && (!row.vehicleId || !await getVehicleAccessLevel(app.db, request.authUser!.sub, row.vehicleId))) {
        throw new AppError(404, "not_found", "Media not found");
      }
    }
    return toMediaJson(app, row);
  });

  app.get("/media/:mediaId/content", { config: { public: true } }, async (request, reply) => {
    const { mediaId } = request.params as { mediaId: string };
    await assertPersonalMedia(mediaId);
    const token = (request.query as { token?: string }).token;
    if (!token || !app.media.verifyDownload(mediaId, token)) {
      throw new AppError(401, "unauthorized", "Invalid download token");
    }
    const [row] = await app.db.select().from(mediaObjects).where(eq(mediaObjects.id, mediaId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Media not found");
    const bytes = await app.media.get(row.blobKey);
    return reply.type(row.contentType).send(bytes);
  });
};

function toMediaJson(app: { env: { PUBLIC_API_URL: string }; media: import("../lib/media.js").MediaStore }, row: typeof mediaObjects.$inferSelect) {
  const signed = app.media.signDownload(row.id);
  const base = app.env.PUBLIC_API_URL.replace(/\/$/, "");
  return {
    id: row.id,
    blob_key: row.blobKey,
    content_type: row.contentType,
    byte_size: row.byteSize,
    sha256: row.sha256,
    download_url: `${base}/media/${row.id}/content?token=${encodeURIComponent(signed.token)}`,
    expires_at: signed.expiresAt.toISOString(),
  };
}

export function sha256Buffer(bytes: Buffer): string {
  return createHash("sha256").update(bytes).digest("hex");
}
