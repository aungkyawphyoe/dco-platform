import { afterEach, describe, expect, it } from "vitest";
import { eq } from "drizzle-orm";
import { createTestApp, uuid } from "./helpers.js";
import { documents, documentLinks, serviceRecords, vehicles } from "../src/db/schema.js";
import { storeWithQuota, storageUsage } from "../src/lib/storage.js";

const opened: Awaited<ReturnType<typeof createTestApp>>[] = [];
afterEach(async () => { for (const ctx of opened.splice(0)) { await ctx.app.close(); await ctx.client.close(); } });

async function setup() {
  const ctx = await createTestApp(); opened.push(ctx);
  const signed = await ctx.app.inject({ method: "POST", url: "/v1/auth/signup", payload: { email: `${uuid()}@test.local`, password: "password1" } });
  const userId = signed.json().user.id as string;
  const headers = { authorization: `Bearer ${signed.json().access_token}` };
  const ids = [uuid(), uuid()];
  for (const id of ids) await ctx.db.insert(vehicles).values({ id, userId, name: "Car", make: "Toyota", model: "Corolla", year: 2020, licensePlate: uuid(), fuelType: "petrol", mileage: "0" });
  const services = [uuid(), uuid(), uuid()];
  for (let i = 0; i < services.length; i++) await ctx.db.insert(serviceRecords).values({ id: services[i], vehicleId: ids[i === 2 ? 1 : 0], createdBy: userId, servicedOn: "2026-10-20", odometer: "100", totalCost: "20" });
  return { ...ctx, userId, headers, vehicleId: ids[0], services };
}

describe("reusable document attachments", () => {
  it("links one file to multiple logs, unlinks without deleting bytes, and preserves documents when a log is deleted", async () => {
    const { app, db, userId, headers, vehicleId, services } = await setup();
    const media = await storeWithQuota(db, app.media, { id: uuid(), owner: { userId }, vehicleId, purpose: "document", bytes: Buffer.from("%PDF-1.7"), contentType: "application/pdf" });
    const id = uuid();
    const created = await app.inject({ method: "POST", url: `/v1/vehicles/${vehicleId}/documents`, headers,
      payload: { id, name: "Invoice", category: "invoice", media_id: media.id, links: services.slice(0, 2).map(record_id => ({ kind: "service_record", record_id })) } });
    expect(created.statusCode, created.body).toBe(201);
    expect(created.json().links).toHaveLength(2);
    expect((await storageUsage(db, { userId })).used_bytes).toBe(8);
    const unlinked = await app.inject({ method: "PATCH", url: `/v1/documents/${id}`, headers,
      payload: { links: [{ kind: "service_record", record_id: services[1] }] } });
    expect(unlinked.statusCode, unlinked.body).toBe(200);
    expect(unlinked.json().links).toHaveLength(1);
    expect((await storageUsage(db, { userId })).used_bytes).toBe(8);
    await db.delete(serviceRecords).where(eq(serviceRecords.id, services[1]));
    const read = await app.inject({ method: "GET", url: `/v1/documents/${id}`, headers });
    expect(read.json().links).toEqual([]);
    expect(read.json().media_id).toBe(media.id);
    expect((await storageUsage(db, { userId })).used_bytes).toBe(8);
  });

  it("rejects cross-vehicle links atomically and removes links on explicit document deletion", async () => {
    const { app, db, headers, vehicleId, services } = await setup();
    const id = uuid();
    const bad = await app.inject({ method: "POST", url: `/v1/vehicles/${vehicleId}/documents`, headers,
      payload: { id, name: "Bad link", category: "invoice", links: [{ kind: "service_record", record_id: services[2] }] } });
    expect(bad.statusCode).toBe(422);
    expect(await db.select().from(documents).where(eq(documents.id, id))).toHaveLength(0);
    const created = await app.inject({ method: "POST", url: `/v1/vehicles/${vehicleId}/documents`, headers,
      payload: { id, name: "Invoice", category: "invoice", links: [{ kind: "service_record", record_id: services[0] }] } });
    expect(created.statusCode).toBe(201);
    expect((await app.inject({ method: "DELETE", url: `/v1/documents/${id}`, headers })).statusCode).toBe(204);
    expect(await db.select().from(documentLinks).where(eq(documentLinks.documentId, id))).toHaveLength(0);
    expect(await db.select().from(serviceRecords).where(eq(serviceRecords.id, services[0]))).toHaveLength(1);
  });
});
