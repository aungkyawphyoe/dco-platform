import { eq } from "drizzle-orm";
import { expect, it } from "vitest";
import { documents, mediaObjects, organizationMembers } from "../src/db/schema.js";
import { deleteUnreferencedMedia } from "../src/lib/storage.js";
import { analyticsFixture } from "./analytics-fixture.js";

it("replays only the original incident submission and retains linked evidence during cleanup", async () => {
  const { app, client, db, headers, orgId, userId, vehicleId } = await analyticsFixture();
  try {
    const photoId = crypto.randomUUID();
    const unusedId = crypto.randomUUID();
    const freshId = crypto.randomUUID();
    const old = new Date("2020-01-01");
    const cutoff = new Date("2021-01-01");
    await db.insert(mediaObjects).values([photoId, unusedId, freshId].map(id => ({
      id, ownerOrgId: orgId, userId, vehicleId, purpose: "incident_photo",
      blobKey: `test/${id}`, contentType: "image/jpeg", byteSize: 1,
      createdAt: id === freshId ? new Date() : old,
    })));
    const url = `/v1/organizations/${orgId}/incidents`;
    const id = crypto.randomUUID();
    const payload = { id, vehicle_id: vehicleId, description: "Parking damage", category: "accident", photo_ids: [photoId] };
    const submit = (body = payload) => app.inject({ method: "POST", url, headers, payload: body });
    const first = await submit();
    expect(first.statusCode, first.body).toBe(201);
    expect(first.json()).not.toHaveProperty("submissionFingerprint");
    expect((await submit()).json()).toEqual(first.json());
    const changed = await submit({ ...payload, description: "Updated after losing the response" });
    expect(changed.statusCode).toBe(409);
    expect(changed.json().error.code).toBe("incident_id_conflict");
    const detail = await app.inject({ url: `${url}/${id}`, headers });
    expect(detail.json()).toMatchObject({ description: payload.description, photoIds: [photoId] });

    for (const mediaId of [photoId, unusedId, freshId]) {
      await db.transaction(tx => deleteUnreferencedMedia(tx, app.media, mediaId, cutoff));
    }
    expect(await db.select().from(mediaObjects).where(eq(mediaObjects.id, unusedId))).toEqual([]);
    expect(await db.select().from(mediaObjects).where(eq(mediaObjects.id, photoId))).toHaveLength(1);
    expect(await db.select().from(mediaObjects).where(eq(mediaObjects.id, freshId))).toHaveLength(1);
  } finally {
    await app.close();
    await client.close();
  }
}, 30000);

it("downloads the attached agreement file through its retained term after transfer", async () => {
  const { app, client, db, headers, orgId, userId, vehicleId } = await analyticsFixture();
  const mediaId = crypto.randomUUID();
  const blobKey = `test/${mediaId}`;
  const bytes = Buffer.from("%PDF-test");
  try {
    await app.media.put(blobKey, bytes, "application/pdf");
    await db.insert(mediaObjects).values({ id: mediaId, ownerOrgId: orgId, userId, vehicleId,
      purpose: "service_receipt", blobKey, contentType: "application/pdf", byteSize: bytes.length });
    const documentId = crypto.randomUUID();
    await db.insert(documents).values({ id: documentId, vehicleId, name: "Policy", category: "insurance", mediaId });
    const [member] = await db.select().from(organizationMembers).where(eq(organizationMembers.userId, userId));
    const base = `/v1/organizations/${orgId}/agreements`;
    const created = await app.inject({ method: "POST", url: base, headers, payload: {
      kind: "insurance_policy", responsible_member_id: member.id, provider: "Test insurer",
      starts_on: "2026-01-01", ends_on: "2027-01-01", reminder_lead_days: 30, document_id: documentId, vehicle_ids: [vehicleId],
    } });
    expect(created.statusCode, created.body).toBe(201);
    const agreementUrl = `${base}/${created.json().id}`;
    const info = await app.inject({ url: agreementUrl, headers });
    expect(info.statusCode, info.body).toBe(200);
    const [term] = info.json().terms;
    expect(term.document).toEqual({ id: documentId, name: "Policy", vehicleId, hasFile: true });
    await client.query("DELETE FROM organization_vehicles WHERE vehicle_id = $1", [vehicleId]);
    const response = await app.inject({ url: `${agreementUrl}/terms/${term.id}/document`, headers });
    expect(response.statusCode, response.body).toBe(200);
    expect(response.rawPayload).toEqual(bytes);
    const unrelatedTerm = await app.inject({ url: `${agreementUrl}/terms/${crypto.randomUUID()}/document`, headers });
    expect(unrelatedTerm.statusCode).toBe(404);
  } finally {
    await app.media.delete(blobKey);
    await app.close();
    await client.close();
  }
}, 30000);
