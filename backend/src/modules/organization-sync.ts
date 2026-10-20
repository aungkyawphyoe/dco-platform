import { isDeepStrictEqual } from "node:util";
import { createHash } from "node:crypto";
import { and, eq, gt, inArray, sql } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { documents, driverAssignments, expenses, fuelLogs, fuelTypes, organizationChanges, organizationReviews, organizationVehicles, parts, planItems, serviceRecords, vehicles } from "../db/schema.js";
import { AppError } from "../lib/errors.js";
import { publicVehicle } from "../lib/serialize.js";
import { loadService, publicDoc, publicExpense, publicFuelLog, publicPart, publicPlan } from "../lib/serialize-records.js";
import { requireFleetClient, requireFleetPortal, requireOwner } from "./auth.js";
import { assertPasswordChangeClear, getOrganizationAccess } from "./fleet.js";
import type { Db } from "../db/client.js";

const uuid = z.string().uuid();
const operationSchema = z.object({
  operation_id: uuid, entity_type: z.enum(["service_record", "expense", "fuel_log", "document", "part"]),
  entity_id: uuid, vehicle_id: uuid, op: z.enum(["upsert", "delete"]),
  expected_revision: z.number().int().positive().nullable(), payload: z.record(z.unknown()),
});
type Operation = z.infer<typeof operationSchema>;
const resources = { service_record: "service-records", expense: "expenses", fuel_log: "fuel-logs", document: "documents", part: "parts" };
const tables = { vehicle: vehicles, plan_item: planItems, service_record: serviceRecords, expense: expenses, fuel_log: fuelLogs, document: documents, part: parts };
type Kind = keyof typeof tables;

async function serialize(db: Db, kind: Kind, id: string): Promise<Record<string, unknown> | null> {
  if (kind === "service_record") return loadService(db, id);
  if (kind === "expense") return publicExpense(db, id);
  if (kind === "vehicle") { const [row] = await db.select().from(vehicles).where(eq(vehicles.id, id)); return row ? publicVehicle(row) : null; }
  if (kind === "plan_item") { const [row] = await db.select().from(planItems).where(eq(planItems.id, id)); return row ? publicPlan(row) : null; }
  if (kind === "fuel_log") { const [row] = await db.select().from(fuelLogs).where(eq(fuelLogs.id, id)); return row ? publicFuelLog(row) : null; }
  if (kind === "document") { const [row] = await db.select().from(documents).where(eq(documents.id, id)); return row ? publicDoc(db, row) : null; }
  const [row] = await db.select().from(parts).where(eq(parts.id, id)); return row ? publicPart(row) : null;
}

export const organizationSyncPlugin: FastifyPluginAsync = async (app) => {
  async function assigned(orgId: string, userId: string) {
    return app.db.select({ id: driverAssignments.id, vehicleId: driverAssignments.vehicleId }).from(driverAssignments)
      .innerJoin(organizationVehicles, and(eq(organizationVehicles.vehicleId, driverAssignments.vehicleId), eq(organizationVehicles.orgId, driverAssignments.orgId)))
      .where(and(eq(driverAssignments.orgId, orgId), eq(driverAssignments.driverId, userId), eq(driverAssignments.status, "active")));
  }

  app.get("/organizations/:id/sync/changes", async (request) => {
    requireOwner(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const userId = request.authUser!.sub;
    await getOrganizationAccess(app.db, userId, orgId, ["org_driver"]);
    await assertPasswordChangeClear(app.db, userId);
    const assignments = await assigned(orgId, userId);
    const vehicleIds = assignments.map(a => a.vehicleId);
    const signature = createHash("sha256").update(JSON.stringify(assignments.map(a => a.id).sort())).digest("hex");
    const raw = (request.query as { cursor?: string }).cursor ?? "";
    let after = 0;
    let priorSignature = "";
    if (raw) {
      try {
        const cursor = z.object({ seq: z.number().int().nonnegative(), scope: z.string() }).parse(JSON.parse(Buffer.from(raw, "base64url").toString()));
        after = cursor.seq; priorSignature = cursor.scope;
      } catch { throw new AppError(400, "invalid_cursor", "Invalid organization cursor"); }
    }
    const bootstrap = signature !== priorSignature;
    const [{ max }] = await app.db.select({ max: sql<number>`coalesce(max(${organizationChanges.seq}), 0)` }).from(organizationChanges).where(eq(organizationChanges.orgId, orgId));
    const changes: object[] = [];
    let next = Number(max);
    const append = async (kind: Kind, id: string, vehicleId: string) => {
      const payload = await serialize(app.db, kind, id);
      changes.push({ entity_type: kind, entity_id: id, op: payload ? "upsert" : "delete", payload: payload ?? { id, vehicle_id: vehicleId }, server_ts: new Date().toISOString() });
    };
    if (bootstrap && vehicleIds.length) {
      for (const vehicleId of vehicleIds) await append("vehicle", vehicleId, vehicleId);
      for (const kind of ["plan_item", "service_record", "expense", "fuel_log", "document", "part"] as const) {
        const table = tables[kind];
        const rows = await app.db.select({ id: table.id, vehicleId: table.vehicleId }).from(table).where(inArray(table.vehicleId, vehicleIds));
        for (const row of rows) await append(kind, row.id, row.vehicleId);
      }
    } else if (vehicleIds.length) {
      const rows = await app.db.select().from(organizationChanges).where(and(eq(organizationChanges.orgId, orgId), gt(organizationChanges.seq, after), inArray(organizationChanges.vehicleId, vehicleIds))).orderBy(organizationChanges.seq).limit(200);
      for (const row of rows) await append(row.entityType as Kind, row.entityId, row.vehicleId);
      if (rows.length === 200) next = rows[rows.length - 1].seq;
    }
    const catalog = await app.db.select().from(fuelTypes).where(eq(fuelTypes.userId, userId));
    for (const type of catalog) changes.push({ entity_type: "fuel_type", entity_id: type.id, op: "upsert",
      payload: { id: type.id, user_id: type.userId, name: type.name, kind: type.kind, unit: type.unit }, server_ts: new Date().toISOString() });
    // Complete access manifest allows clients to remove revoked cached vehicles,
    // even when no ordinary record changed since the last pull.
    return { cursor: Buffer.from(JSON.stringify({ seq: next, scope: signature })).toString("base64url"), changes,
      organization_id: orgId, assigned_vehicle_ids: vehicleIds, bootstrap };
  });

  async function apply(orgId: string, token: string, operation: Operation, reviewId?: string) {
    const resource = resources[operation.entity_type];
    const create = operation.op === "upsert" && operation.expected_revision === null;
    const url = create ? `vehicles/${operation.vehicle_id}/${resource}` : `${resource}/${operation.entity_id}`;
    return app.inject({ method: operation.op === "delete" ? "DELETE" : create ? "POST" : "PATCH",
      url: `/v1/organizations/${orgId}/records/${url}`,
      headers: { authorization: token, "idempotency-key": operation.operation_id,
        ...(reviewId ? { "x-review-id": reviewId } : {}),
        ...(operation.expected_revision !== null ? { "if-match": String(operation.expected_revision) } : {}) },
      ...(operation.op === "delete" ? {} : { payload: { ...operation.payload, id: operation.entity_id } }),
    });
  }

  app.post("/organizations/:id/sync/push", async (request) => {
    requireOwner(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const userId = request.authUser!.sub;
    await getOrganizationAccess(app.db, userId, orgId, ["org_driver"]);
    await assertPasswordChangeClear(app.db, userId);
    const { operations } = z.object({ operations: z.array(operationSchema).max(100) }).parse(request.body);
    const results = [];
    for (const operation of operations) {
      const [review] = await app.db.select().from(organizationReviews).where(eq(organizationReviews.id, operation.operation_id));
      if (review) {
        if (review.orgId !== orgId || review.userId !== userId || !isDeepStrictEqual(review.operation, operation)) {
          results.push({ entity_id: operation.entity_id, operation_id: operation.operation_id, status: "rejected", error: { error: { code: "operation_id_conflict", message: "Operation ID already used" } } }); continue;
        }
        results.push({ entity_id: operation.entity_id, operation_id: operation.operation_id, status: "review", review_id: review.id }); continue;
      }
      // Historical assignment is required even to submit for review. Client time
      // cannot grant access to a vehicle the server never assigned to this Driver.
      const [history] = await app.db.select().from(driverAssignments).where(and(eq(driverAssignments.orgId, orgId), eq(driverAssignments.driverId, userId), eq(driverAssignments.vehicleId, operation.vehicle_id)));
      if (!history) {
        results.push({ entity_id: operation.entity_id, operation_id: operation.operation_id, status: "rejected", error: { error: { code: "not_assigned_to_vehicle", message: "No assignment history" } } }); continue;
      }
      const table = tables[operation.entity_type];
      const [existing] = await app.db.select().from(table).where(eq(table.id, operation.entity_id));
      if (existing && existing.vehicleId !== operation.vehicle_id) {
        results.push({ entity_id: operation.entity_id, operation_id: operation.operation_id, status: "rejected", error: { error: { code: "vehicle_mismatch", message: "Record belongs to a different vehicle" } } }); continue;
      }
      const author = existing ? ("createdBy" in existing ? existing.createdBy : "userId" in existing ? existing.userId : null) : null;
      if (existing && author !== userId) {
        results.push({ entity_id: operation.entity_id, operation_id: operation.operation_id, status: "rejected", error: { error: { code: "insufficient_permission", message: "Can only change own records" } } }); continue;
      }
      const response = await apply(orgId, request.headers.authorization!, operation);
      if (response.statusCode < 300) {
        results.push({ entity_id: operation.entity_id, operation_id: operation.operation_id, status: "applied" }); continue;
      }
      const error = response.json();
      if (["not_assigned_to_vehicle", "admin_corrected", "revision_conflict", "invalid_plan_item"].includes(error.error?.code)) {
        const inserted = await app.db.insert(organizationReviews).values({ id: operation.operation_id, orgId, userId, vehicleId: operation.vehicle_id, operation, reason: error.error.code }).onConflictDoNothing().returning();
        if (!inserted.length) {
          const [prior] = await app.db.select().from(organizationReviews).where(eq(organizationReviews.id, operation.operation_id));
          if (!prior || prior.orgId !== orgId || prior.userId !== userId || !isDeepStrictEqual(prior.operation, operation)) {
            results.push({ entity_id: operation.entity_id, operation_id: operation.operation_id, status: "rejected", error: { error: { code: "operation_id_conflict", message: "Operation ID already used" } } }); continue;
          }
        }
        results.push({ entity_id: operation.entity_id, operation_id: operation.operation_id, status: "review", review_id: operation.operation_id });
      } else results.push({ entity_id: operation.entity_id, operation_id: operation.operation_id, status: "rejected", error });
    }
    return { results };
  });

  app.get("/organizations/:id/reviews", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const userId = request.authUser!.sub;
    const { membership } = await getOrganizationAccess(app.db, userId, orgId, ["org_admin", "org_driver"]);
    await assertPasswordChangeClear(app.db, userId);
    if (membership.role === "org_admin") requireFleetPortal(request); else requireOwner(request);
    const conditions = [eq(organizationReviews.orgId, orgId)];
    if (membership.role === "org_driver") conditions.push(eq(organizationReviews.userId, userId));
    const rows = await app.db.select().from(organizationReviews).where(and(...conditions));
    return { items: rows.map(row => ({ id: row.id, vehicle_id: row.vehicleId, submitted_by: row.userId,
      reason: row.reason, status: row.status, reviewer_note: row.reviewerNote, created_at: row.createdAt.toISOString(),
      ...(membership.role === "org_admin" ? { operation: row.operation } : {}) })) };
  });

  app.post("/organizations/:id/reviews/:reviewId/decision", async (request) => {
    requireFleetPortal(request);
    const { id: orgId, reviewId } = z.object({ id: uuid, reviewId: uuid }).parse(request.params);
    await getOrganizationAccess(app.db, request.authUser!.sub, orgId, ["org_admin"]);
    await assertPasswordChangeClear(app.db, request.authUser!.sub);
    const body = z.object({ decision: z.enum(["accept", "reject"]), note: z.string().max(2000).optional(), expected_revision: z.number().int().positive().nullable().optional() }).parse(request.body);
    const [review] = await app.db.select().from(organizationReviews).where(and(eq(organizationReviews.id, reviewId), eq(organizationReviews.orgId, orgId)));
    if (!review) throw new AppError(404, "review_not_found", "Review not found");
    if (review.status !== "pending") return { status: review.status };
    if (body.decision === "reject") {
      const [updated] = await app.db.update(organizationReviews).set({ status: "rejected", reviewedBy: request.authUser!.sub, reviewerNote: body.note ?? null })
        .where(and(eq(organizationReviews.id, reviewId), eq(organizationReviews.status, "pending"))).returning();
      if (!updated) throw new AppError(409, "review_changed", "Review already decided");
      return { status: updated.status };
    }
    const operation = operationSchema.parse(review.operation);
    const table = tables[operation.entity_type];
    const [current] = await app.db.select().from(table).where(eq(table.id, operation.entity_id));
    if (current && body.expected_revision !== current.revision) throw new AppError(409, "revision_conflict", "Refresh the current record before accepting");
    const response = await apply(orgId, request.headers.authorization!, { ...operation, expected_revision: current?.revision ?? null }, reviewId);
    if (response.statusCode >= 300) {
      const error = response.json().error;
      throw new AppError(response.statusCode, error.code, error.message);
    }
    return { status: "accepted" };
  });
};
