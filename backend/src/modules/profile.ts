import { eq } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import {
  auditEvents,
  families,
  familyMemberships,
  familyVehicles,
  mediaObjects,
  refreshTokens,
  users,
  vehicleGrants,
  vehicles,
} from "../db/schema.js";
import { verifyPassword } from "../lib/crypto.js";
import { AppError } from "../lib/errors.js";
import { recordChange } from "../lib/dbx.js";
import { publicUser } from "../lib/serialize.js";
import { requireOwner } from "./auth.js";

const PROFILE_PHOTO_MAX_BYTES = 5 * 1024 * 1024;

export const profilePlugin: FastifyPluginAsync = async (app) => {
  app.get("/users/me/profile", async (request) => {
    requireOwner(request);
    const userId = request.authUser!.sub;
    const [u] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) throw new AppError(404, "not_found", "User not found");
    return publicUser(u);
  });

  app.patch("/users/me/profile", async (request) => {
    requireOwner(request);
    const userId = request.authUser!.sub;
    const body = z
      .object({
        display_name: z.string().max(50).optional(),
        contact_phone: z.string().max(20).optional().nullable(),
        address: z.string().max(500).optional().nullable(),
      })
      .parse(request.body ?? {});

    const set: Record<string, unknown> = {};
    if (body.display_name !== undefined) set.displayName = body.display_name;
    if (body.contact_phone !== undefined) set.contactPhone = body.contact_phone;
    if (body.address !== undefined) set.address = body.address;

    if (Object.keys(set).length === 0) {
      const [u] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
      if (!u) throw new AppError(404, "not_found", "User not found");
      return publicUser(u);
    }

    const [updated] = await app.db.update(users).set(set).where(eq(users.id, userId)).returning();
    await recordChange(app.db, {
      userId,
      entityType: "user",
      entityId: userId,
      op: "upsert",
      payload: publicUser(updated),
    });
    return publicUser(updated);
  });

  app.post("/users/me/profile/photo", async (request, reply) => {
    requireOwner(request);
    const userId = request.authUser!.sub;
    const file = await request.file();
    if (!file) throw new AppError(422, "missing_file", "file is required");

    const allowed = ["image/jpeg", "image/png", "image/webp"];
    if (!allowed.includes(file.mimetype)) {
      throw new AppError(400, "invalid_photo_format", "Photo must be JPEG, PNG, or WebP");
    }

    const chunks: Buffer[] = [];
    let size = 0;
    for await (const chunk of file.file) {
      size += chunk.length;
      if (size > PROFILE_PHOTO_MAX_BYTES) {
        throw new AppError(413, "photo_too_large", "Photo must be under 5 MB");
      }
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    const bytes = Buffer.concat(chunks);

    const [u] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) throw new AppError(404, "not_found", "User not found");

    const mediaId = u.profilePhotoMediaId ?? crypto.randomUUID();
    const blobKey = `${userId}/${mediaId}`;
    const stored = await app.media.put(blobKey, bytes, file.mimetype);

    const [existing] = await app.db.select().from(mediaObjects).where(eq(mediaObjects.id, mediaId)).limit(1);
    if (existing) {
      await app.db
        .update(mediaObjects)
        .set({
          blobKey: stored.blobKey,
          contentType: file.mimetype,
          byteSize: stored.byteSize,
          sha256: stored.sha256,
        })
        .where(eq(mediaObjects.id, mediaId));
    } else {
      await app.db.insert(mediaObjects).values({
        id: mediaId,
        userId,
        blobKey: stored.blobKey,
        contentType: file.mimetype,
        byteSize: stored.byteSize,
        sha256: stored.sha256,
        purpose: "profile_photo",
      });
    }

    const [updated] = await app.db
      .update(users)
      .set({ profilePhotoMediaId: mediaId })
      .where(eq(users.id, userId))
      .returning();

    await recordChange(app.db, {
      userId,
      entityType: "user",
      entityId: userId,
      op: "upsert",
      payload: publicUser(updated),
    });

    const signed = app.media.signDownload(mediaId);
    const base = app.env.PUBLIC_API_URL.replace(/\/$/, "");
    return {
      media_id: mediaId,
      url: `${base}/media/${mediaId}/content?token=${encodeURIComponent(signed.token)}`,
      expires_at: signed.expiresAt.toISOString(),
    };
  });

  app.post("/users/me/delete", async (request, reply) => {
    requireOwner(request);
    const userId = request.authUser!.sub;
    const body = z
      .object({
        password: z.string().min(1),
        reason: z.string().optional(),
      })
      .parse(request.body);

    const [u] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) throw new AppError(404, "not_found", "User not found");

    const valid = await verifyPassword(body.password, u.passwordHash);
    if (!valid) throw new AppError(401, "invalid_password", "Incorrect password");

    const [membership] = await app.db
      .select()
      .from(familyMemberships)
      .where(eq(familyMemberships.userId, userId))
      .limit(1);

    if (membership?.role === "primary_owner") {
      const otherMembers = await app.db
        .select()
        .from(familyMemberships)
        .where(eq(familyMemberships.familyId, membership.familyId));
      const hasOtherMembers = otherMembers.some((m) => m.userId !== userId);
      if (hasOtherMembers) {
        throw new AppError(409, "transfer_required", "Transfer ownership or dissolve your family before deleting");
      }
      await app.db.update(families).set({ status: "archived", archivedAt: new Date() }).where(eq(families.id, membership.familyId));
      await app.db.delete(familyMemberships).where(eq(familyMemberships.familyId, membership.familyId));
      await app.db.delete(familyVehicles).where(eq(familyVehicles.familyId, membership.familyId));
      await app.db.delete(vehicleGrants).where(eq(vehicleGrants.userId, userId));
    } else if (membership) {
      await app.db.delete(familyMemberships).where(eq(familyMemberships.userId, userId));
      await app.db.delete(vehicleGrants).where(eq(vehicleGrants.userId, userId));
    }

    const userVehicles = await app.db.select().from(vehicles).where(eq(vehicles.userId, userId));
    for (const v of userVehicles) {
      await app.db.update(vehicles).set({ archived: true, archivedAt: new Date() }).where(eq(vehicles.id, v.id));
    }

    await app.db.update(users).set({ status: "deactivated", familyId: null }).where(eq(users.id, userId));
    await app.db.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.userId, userId));

    return reply.code(204).send();
  });
};
