import { expect, it } from "vitest";
import { eq } from "drizzle-orm";
import { analyticsFixture } from "./analytics-fixture.js";
import { auditEvents, organizationMembers } from "../src/db/schema.js";

it("audits fleet document CRUD, rejects stale revisions and restricts other portal roles", async () => {
  const { app, db, client, headers, orgId, vehicleId, userId } = await analyticsFixture();
  try {
    const base = `/v1/organizations/${orgId}/records`;
    const id = crypto.randomUUID();
    const created = await app.inject({ method: "POST", url: `${base}/vehicles/${vehicleId}/documents`, headers,
      payload: { id, name: "Insurance", category: "insurance" } });
    expect(created.statusCode, created.body).toBe(201);
    const updated = await app.inject({ method: "PATCH", url: `${base}/documents/${id}`,
      headers: { ...headers, "if-match": String(created.json().revision) }, payload: { name: "Renewed insurance" } });
    expect(updated.statusCode, updated.body).toBe(200);
    expect(updated.json().admin_corrected_by).toBe(userId);
    const stale = await app.inject({ method: "DELETE", url: `${base}/documents/${id}`,
      headers: { ...headers, "if-match": String(created.json().revision) } });
    expect(stale.statusCode).toBe(409);
    const removed = await app.inject({ method: "DELETE", url: `${base}/documents/${id}`,
      headers: { ...headers, "if-match": String(updated.json().revision) } });
    expect(removed.statusCode, removed.body).toBe(204);
    const audits = await db.select().from(auditEvents).where(eq(auditEvents.adminUserId, userId));
    expect(audits.map(row => row.action)).toEqual(["fleet.document.post", "fleet.document.patch", "fleet.document.delete"]);
    expect(audits.every(row => (row.detail as { document_id: string }).document_id === id)).toBe(true);
    await db.update(organizationMembers).set({ role: "org_manager" }).where(eq(organizationMembers.userId, userId));
    expect((await app.inject({ url: `${base}/vehicles/${vehicleId}/documents`, headers })).statusCode).toBe(403);
  } finally { await app.close(); await client.close(); }
}, 30000);
