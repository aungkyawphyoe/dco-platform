import { createHash } from "node:crypto";
import type { FastifyPluginAsync } from "fastify";
import { eq } from "drizzle-orm";
import { mediaObjects } from "../db/schema.js";
import { AppError } from "../lib/errors.js";
import { recordChange } from "../lib/dbx.js";
import { MEDIA_MAX_BYTES } from "../lib/media.js";
import { requireOwner } from "./auth.js";

export const mediaPlugin: FastifyPluginAsync = async (app) => {
  app.post("/media", async (request, reply) => {
    requireOwner(request);
    const file = await request.file();
    if (!file) throw new AppError(422, "missing_file", "file is required");
    const fields = file.fields as Record<string, { value?: string } | undefined>;
    const id = fields.id?.value;
    const purpose = fields.purpose?.value;
    if (!id) throw new AppError(422, "missing_id", "id is required");
    const chunks: Buffer[] = [];
    let size = 0;
    for await (const chunk of file.file) {
      size += chunk.length;
      if (size > MEDIA_MAX_BYTES) throw new AppError(413, "payload_too_large", "File exceeds 15MB");
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    const bytes = Buffer.concat(chunks);
    const [existing] = await app.db.select().from(mediaObjects).where(eq(mediaObjects.id, id)).limit(1);
    if (existing) {
      return reply.code(201).send(toMediaJson(app, existing));
    }
    const blobKey = `${request.authUser!.sub}/${id}`;
    const stored = await app.media.put(blobKey, bytes, file.mimetype);
    const [row] = await app.db
      .insert(mediaObjects)
      .values({
        id,
        userId: request.authUser!.sub,
        blobKey: stored.blobKey,
        contentType: file.mimetype,
        byteSize: stored.byteSize,
        sha256: stored.sha256,
        purpose: purpose ?? null,
      })
      .returning();
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

  app.get("/media/:mediaId", async (request) => {
    const { mediaId } = request.params as { mediaId: string };
    const token = (request.query as { token?: string }).token;
    const [row] = await app.db.select().from(mediaObjects).where(eq(mediaObjects.id, mediaId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Media not found");
    if (token) {
      if (!app.media.verifyDownload(mediaId, token)) throw new AppError(401, "unauthorized", "Invalid download token");
    } else {
      requireOwner(request);
      if (row.userId !== request.authUser!.sub) throw new AppError(404, "not_found", "Media not found");
    }
    return toMediaJson(app, row);
  });

  app.get("/media/:mediaId/content", { config: { public: true } }, async (request, reply) => {
    const { mediaId } = request.params as { mediaId: string };
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
