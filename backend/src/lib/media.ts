import { createHmac, createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { BlobServiceClient } from "@azure/storage-blob";
import type { Env } from "../config/env.js";

const MAX_BYTES = 15 * 1024 * 1024;

export type StoredMedia = { blobKey: string; sha256: string; byteSize: number };

export type MediaStore = {
  put(blobKey: string, bytes: Buffer, contentType: string): Promise<StoredMedia>;
  get(blobKey: string): Promise<Buffer>;
  signDownload(mediaId: string, ttlSec?: number): { token: string; expiresAt: Date };
  verifyDownload(mediaId: string, token: string): boolean;
};

export function createMediaStore(env: Env): MediaStore {
  const putLocal = async (blobKey: string, bytes: Buffer): Promise<StoredMedia> => {
    const path = join(env.MEDIA_LOCAL_DIR, blobKey);
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, bytes);
    return {
      blobKey,
      byteSize: bytes.length,
      sha256: createHash("sha256").update(bytes).digest("hex"),
    };
  };

  const getLocal = (blobKey: string) => readFile(join(env.MEDIA_LOCAL_DIR, blobKey));

  return {
    async put(blobKey, bytes, contentType) {
      if (bytes.length > MAX_BYTES) {
        const { AppError } = await import("./errors.js");
        throw new AppError(413, "payload_too_large", "File exceeds 15MB");
      }
      if (env.MEDIA_DRIVER === "azure_blob") {
        if (!env.AZURE_STORAGE_CONNECTION_STRING) {
          throw new Error("AZURE_STORAGE_CONNECTION_STRING required");
        }
        const service = BlobServiceClient.fromConnectionString(env.AZURE_STORAGE_CONNECTION_STRING);
        const container = service.getContainerClient(env.AZURE_BLOB_CONTAINER);
        await container.createIfNotExists();
        await container.getBlockBlobClient(blobKey).uploadData(bytes, {
          blobHTTPHeaders: { blobContentType: contentType },
        });
        return {
          blobKey,
          byteSize: bytes.length,
          sha256: createHash("sha256").update(bytes).digest("hex"),
        };
      }
      return putLocal(blobKey, bytes);
    },
    async get(blobKey) {
      if (env.MEDIA_DRIVER === "azure_blob") {
        if (!env.AZURE_STORAGE_CONNECTION_STRING) {
          throw new Error("AZURE_STORAGE_CONNECTION_STRING required");
        }
        const service = BlobServiceClient.fromConnectionString(env.AZURE_STORAGE_CONNECTION_STRING);
        const client = service.getContainerClient(env.AZURE_BLOB_CONTAINER).getBlockBlobClient(blobKey);
        return Buffer.from(await client.downloadToBuffer());
      }
      return getLocal(blobKey);
    },
    signDownload(mediaId, ttlSec = 900) {
      const expiresAt = new Date(Date.now() + ttlSec * 1000);
      const exp = Math.floor(expiresAt.getTime() / 1000);
      const token = `${exp}.${hmac(env, `${mediaId}:${exp}`)}`;
      return { token, expiresAt };
    },
    verifyDownload(mediaId, token) {
      const [expRaw, sig] = token.split(".");
      const exp = Number(expRaw);
      if (!exp || Date.now() / 1000 > exp) return false;
      return hmac(env, `${mediaId}:${exp}`) === sig;
    },
  };
}

function hmac(env: Env, value: string): string {
  return createHmac("sha256", env.MEDIA_SIGNING_KEY).update(value).digest("hex");
}

export const MEDIA_MAX_BYTES = MAX_BYTES;
