import { afterEach, describe, expect, it } from "vitest";
import { createTestApp, uuid } from "./helpers.js";
import { documents, mediaObjects, organizations, users, vehicles } from "../src/db/schema.js";
import { storeWithQuota, storageUsage } from "../src/lib/storage.js";
import { documentContentType } from "../src/lib/document-files.js";
import { eq } from "drizzle-orm";

const opened: Awaited<ReturnType<typeof createTestApp>>[] = [];
afterEach(async () => { for (const ctx of opened.splice(0)) { await ctx.app.close(); await ctx.client.close(); } });
async function setup() {
  const ctx = await createTestApp(); opened.push(ctx);
  const response = await ctx.app.inject({ method: "POST", url: "/v1/auth/signup", payload: { email: `${uuid()}@test.local`, password: "password1" } });
  return { ...ctx, userId: response.json().user.id as string, token: response.json().access_token as string };
}

describe("document storage", () => {
  it("uses file content instead of trusting extensions and rejects other formats", () => {
    expect(documentContentType(Buffer.from("%PDF-1.7\n"))).toBe("application/pdf");
    expect(() => documentContentType(Buffer.from("%PDF-1.7\n"), true)).toThrow();
    expect(() => documentContentType(Buffer.from("<html>pretend.pdf</html>"))).toThrow();
    expect(documentContentType(Buffer.from([255, 216, 255, 224]))).toBe("image/jpeg");
  });

  it("enforces actual stored usage, retries idempotently, and preserves reads after downgrade", async () => {
    const { app, db, userId, token } = await setup();
    const owner = { userId };
    const limit = 50 * 1024 * 1024;
    await db.insert(mediaObjects).values({ id: uuid(), userId, blobKey: "fixture", contentType: "application/pdf", byteSize: limit - 10, purpose: "document" });
    const input = { id: uuid(), owner, purpose: "document", bytes: Buffer.from("%PDF-1.7\n"), contentType: "application/pdf" };
    await storeWithQuota(db, app.media, input);
    await storeWithQuota(db, app.media, input);
    expect((await storageUsage(db, owner)).used_bytes).toBe(limit - 1);
    await expect(storeWithQuota(db, app.media, { ...input, id: uuid() })).rejects.toMatchObject({ code: "LIMIT_EXCEEDED" });
    const response = await app.inject({ method: "GET", url: "/v1/users/me/storage", headers: { authorization: `Bearer ${token}` } });
    expect(response.json().used_bytes).toBe(limit - 1);
    await db.update(users).set({ plan: "lite" }).where(eq(users.id, userId));
    await storeWithQuota(db, app.media, { ...input, id: uuid() });
    await db.update(users).set({ plan: "free" }).where(eq(users.id, userId));
    const read = await app.inject({ method: "GET", url: `/v1/media/${input.id}`, headers: { authorization: `Bearer ${token}` } });
    expect(read.statusCode).toBe(200);
  });

  it("releases storage only after file deletion and retries failed cleanup", async () => {
    const { app, db, userId, token } = await setup();
    const vehicleId = uuid();
    await db.insert(vehicles).values({ id: vehicleId, userId, name: "Car", make: "Toyota", model: "Corolla", year: 2020, licensePlate: uuid(), fuelType: "petrol", mileage: "0" });
    const media = await storeWithQuota(db, app.media, { id: uuid(), owner: { userId }, vehicleId, purpose: "document", bytes: Buffer.from("%PDF-1.7"), contentType: "application/pdf" });
    const documentId = uuid();
    await db.insert(documents).values({ id: documentId, vehicleId, name: "Receipt", category: "receipt", mediaId: media.id, createdBy: userId });
    const originalDelete = app.media.delete;
    app.media.delete = async () => { throw new Error("Temporary storage outage"); };
    const headers = { authorization: `Bearer ${token}` };
    expect((await app.inject({ method: "DELETE", url: `/v1/documents/${documentId}`, headers })).statusCode).toBe(204);
    expect((await storageUsage(db, { userId })).used_bytes).toBe(8);
    app.media.delete = originalDelete;
    const usage = await app.inject({ method: "GET", url: "/v1/users/me/storage", headers });
    expect(usage.json().used_bytes).toBe(0);
    expect((await app.inject({ method: "DELETE", url: `/v1/documents/${documentId}`, headers })).statusCode).toBe(204);
    expect((await storageUsage(db, { userId })).used_bytes).toBe(0);
  });

  it("serializes concurrent uploads and keeps organization usage separate", async () => {
    const { app, db, userId } = await setup();
    const orgId = uuid();
    await db.insert(organizations).values({ id: orgId, name: "Fleet", type: "taxi_fleet", adminUserId: userId, createdBy: userId });
    const owner = { userId, orgId };
    await db.insert(mediaObjects).values({ id: uuid(), userId, ownerOrgId: orgId, blobKey: "fixture-org", contentType: "application/pdf", byteSize: 1024 * 1024 * 1024, purpose: "document" });
    expect((await storageUsage(db, { userId })).used_bytes).toBe(0);
    expect((await storageUsage(db, owner)).limit_bytes).toBe(5 * 1024 ** 3);
    await db.insert(mediaObjects).values({ id: uuid(), userId, blobKey: "fixture-personal", contentType: "application/pdf", byteSize: 50 * 1024 ** 2 - 10, purpose: "document" });
    const results = await Promise.allSettled([1, 2].map(() => storeWithQuota(db, app.media, { id: uuid(), owner: { userId }, purpose: "document", bytes: Buffer.from("%PDF-1.7\n"), contentType: "application/pdf" })));
    expect(results.filter(r => r.status === "fulfilled")).toHaveLength(1);
  });
});
