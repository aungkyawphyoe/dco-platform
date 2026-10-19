import { createHash } from "node:crypto";
import { AsyncLocalStorage } from "node:async_hooks";
import { and, asc, desc, eq, isNull, sql } from "drizzle-orm";
import type { FastifyPluginAsync, FastifyRequest } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import {
  documents,
  driverAssignments,
  organizationVehicles,
  organizationOperations,
  organizationReviews,
  expenseParts,
  expenses,
  fuelLogs,
  fuelTypes,
  maintenanceCatalog,
  mediaObjects,
  notificationFeed,
  parts,
  planItems,
  serviceRecordItems,
  serviceRecordParts,
  serviceRecords,
  vehicles,
} from "../db/schema.js";
import { newId } from "../lib/crypto.js";
import { dueFrom } from "../lib/catalog.js";
import { dateOnly, num, recordChange, reqNum } from "../lib/dbx.js";
import { AppError } from "../lib/errors.js";
import { assertPersonalGarageAllowed } from "../lib/personal-garage.js";
import {
  loadService,
  publicDoc,
  publicExpense,
  publicFuelLog,
  publicPart,
  publicPlan,
} from "../lib/serialize-records.js";
import { requireOwner as requirePersonalOwner, requireFleetClient, requireFleetPortal } from "./auth.js";
import { getOrganizationAccess, assertPasswordChangeClear } from "./fleet.js";
import { getVehicleAccessLevel as personalAccessLevel, getVehicleChangeAudience, fanOutVehicleChange } from "./vehicle-shares.js";
import { getAccessibleVehicle as personalAccessibleVehicle, getOwnedVehicle as personalOwnedVehicle } from "./vehicles.js";

const uuid = z.string().uuid();

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.entries(value).sort(([a], [b]) => a.localeCompare(b)).map(([key, child]) => `${JSON.stringify(key)}:${canonical(child)}`).join(",")}}`;
  return JSON.stringify(value) ?? "null";
}

export const ownerPlugin = createRecordPlugin(false);
export const organizationRecordsPlugin = createRecordPlugin(true);

/** Same record schemas and operations, with explicit organization access policy. */
function createRecordPlugin(organizationScoped: boolean): FastifyPluginAsync {
return async (app) => {
  const transaction = new AsyncLocalStorage<Db>();
  const reviewAuthor = new AsyncLocalStorage<string>();
  const requestedOrganization = new AsyncLocalStorage<string>();
  const requireOwner = organizationScoped ? requireFleetClient : requirePersonalOwner;

  async function getVehicleAccessLevel(db: Db, userId: string, vehicleId: string): Promise<"owner" | "view" | "add_edit_own" | null> {
    if (!organizationScoped) return personalAccessLevel(db, userId, vehicleId);
    const [link] = await db.select().from(organizationVehicles).where(eq(organizationVehicles.vehicleId, vehicleId));
    if (!link || (requestedOrganization.getStore() && link.orgId !== requestedOrganization.getStore())) return null;
    const { membership } = await getOrganizationAccess(db, userId, link.orgId, ["org_admin", "org_driver"]);
    if (membership.role === "org_admin") return "owner";
    const [assignment] = await db.select().from(driverAssignments).where(and(
      eq(driverAssignments.orgId, link.orgId), eq(driverAssignments.vehicleId, vehicleId),
      eq(driverAssignments.driverId, userId), eq(driverAssignments.status, "active"),
    ));
    return assignment ? "add_edit_own" : null;
  }

  async function getAccessibleVehicle(db: Db, userId: string, vehicleId: string, permission: "full" | "drive_only", includeArchived = false) {
    if (!organizationScoped) return personalAccessibleVehicle(db, userId, vehicleId, permission, includeArchived);
    const access = await getVehicleAccessLevel(db, userId, vehicleId);
    if (!access || (permission === "full" && access === "view")) throw new AppError(403, "not_assigned_to_vehicle", "Vehicle access is required");
    const [vehicle] = await db.select().from(vehicles).where(eq(vehicles.id, vehicleId));
    if (!vehicle || (!includeArchived && vehicle.archived)) throw new AppError(404, "not_found", "Vehicle not found");
    return vehicle;
  }

  async function getOwnedVehicle(db: Db, userId: string, vehicleId: string) {
    if (!organizationScoped) return personalOwnedVehicle(db, userId, vehicleId);
    if (await getVehicleAccessLevel(db, userId, vehicleId) !== "owner") throw new AppError(403, "plan_managed_by_admin", "Fleet Admin manages maintenance plans");
    return getAccessibleVehicle(db, userId, vehicleId, "full");
  }

/**
 * Fuel logs are vehicle-scoped and may be created by any user holding access to
 * the vehicle, so by-id reads must not be gated on `fuel_logs.user_id` — the
 * vehicle owner has to be able to open logs a shared user created.
 *
 * `read` needs any access level. `write` follows the sharing matrix: the owner
 * may edit any log on their vehicle, an `add_edit_own` sharee only logs they
 * created, and a `view` sharee never writes at all.
 */
async function loadFuelLogFor(db: Db, callerId: string, fuelLogId: string, mode: "read" | "write") {
  const [row] = await db.select().from(fuelLogs).where(eq(fuelLogs.id, fuelLogId)).limit(1);
  if (!row) throw new AppError(404, "not_found", "Fuel log not found");
  const access = await getVehicleAccessLevel(db, callerId, row.vehicleId);
  if (!access) throw new AppError(404, "not_found", "Fuel log not found");
  if (mode === "write" && access === "view") {
    throw new AppError(403, "insufficient_permission", "Full access required");
  }
  if (mode === "write" && access === "add_edit_own" && row.userId !== callerId) {
    throw new AppError(403, "insufficient_permission", "Can only edit own fuel logs");
  }
  if (organizationScoped && mode === "write" && access !== "owner" && row.adminCorrectedBy) {
    throw new AppError(409, "admin_corrected", "Updated by Fleet Admin; submit a correction for review");
  }
  return row;
}

/**
 * Load a plan item with permission check.
 * Read: any access level (view or add_edit_own)
 * Write: only owner (plan items are owner-managed)
 */
async function loadPlanItemFor(db: Db, callerId: string, planItemId: string, mode: "read" | "write") {
  const [row] = await db.select().from(planItems).where(eq(planItems.id, planItemId)).limit(1);
  if (!row) throw new AppError(404, "not_found", "Plan item not found");
  const access = await getVehicleAccessLevel(db, callerId, row.vehicleId);
  if (!access) throw new AppError(404, "not_found", "Plan item not found");
  if (mode === "write" && access !== "owner") {
    throw new AppError(403, "insufficient_permission", "Owner access required for plan items");
  }
  return row;
}

/**
 * Load a service record with permission check.
 * Read: any access level (view or add_edit_own)
 * Write: owner or author (for add_edit_own users, only their own records)
 */
async function loadServiceRecordFor(db: Db, callerId: string, serviceRecordId: string, mode: "read" | "write") {
  const [row] = await db.select().from(serviceRecords).where(eq(serviceRecords.id, serviceRecordId)).limit(1);
  if (!row) throw new AppError(404, "not_found", "Service record not found");
  const access = await getVehicleAccessLevel(db, callerId, row.vehicleId);
  if (!access) throw new AppError(404, "not_found", "Service record not found");
  if (mode === "write" && access === "view") {
    throw new AppError(403, "insufficient_permission", "Full access required");
  }
  if (mode === "write" && access === "add_edit_own" && row.createdBy !== callerId) {
    throw new AppError(403, "insufficient_permission", "Can only edit own service records");
  }
  if (organizationScoped && mode === "write" && access !== "owner" && row.adminCorrectedBy) {
    throw new AppError(409, "admin_corrected", "Updated by Fleet Admin; submit a correction for review");
  }
  return row;
}

/**
 * Load an expense with permission check.
 * Read: any access level (view or add_edit_own)
 * Write: owner or author (for add_edit_own users, only their own records)
 */
async function loadExpenseFor(db: Db, callerId: string, expenseId: string, mode: "read" | "write") {
  const [row] = await db.select().from(expenses).where(eq(expenses.id, expenseId)).limit(1);
  if (!row) throw new AppError(404, "not_found", "Expense not found");
  const access = await getVehicleAccessLevel(db, callerId, row.vehicleId);
  if (!access) throw new AppError(404, "not_found", "Expense not found");
  if (mode === "write" && access === "view") {
    throw new AppError(403, "insufficient_permission", "Full access required");
  }
  if (mode === "write" && access === "add_edit_own" && row.createdBy !== callerId) {
    throw new AppError(403, "insufficient_permission", "Can only edit own expenses");
  }
  if (organizationScoped && mode === "write" && access !== "owner" && row.adminCorrectedBy) {
    throw new AppError(409, "admin_corrected", "Updated by Fleet Admin; submit a correction for review");
  }
  return row;
}

/**
 * Load a document with permission check.
 * Read: any access level (view or add_edit_own)
 * Write: owner or author (for add_edit_own users, only their own records)
 */
async function loadDocumentFor(db: Db, callerId: string, documentId: string, mode: "read" | "write") {
  const [row] = await db.select().from(documents).where(eq(documents.id, documentId)).limit(1);
  if (!row) throw new AppError(404, "not_found", "Document not found");
  const access = await getVehicleAccessLevel(db, callerId, row.vehicleId);
  if (!access) throw new AppError(404, "not_found", "Document not found");
  if (mode === "write" && access === "view") {
    throw new AppError(403, "insufficient_permission", "Full access required");
  }
  if (mode === "write" && access === "add_edit_own" && row.createdBy !== callerId) {
    throw new AppError(403, "insufficient_permission", "Can only edit own documents");
  }
  if (organizationScoped && mode === "write" && access !== "owner" && row.adminCorrectedBy) {
    throw new AppError(409, "admin_corrected", "Updated by Fleet Admin; submit a correction for review");
  }
  return row;
}

/**
 * Load a part with permission check.
 * Read: any access level (view or add_edit_own)
 * Write: owner or author (for add_edit_own users, only their own records)
 */
async function loadPartFor(db: Db, callerId: string, partId: string, mode: "read" | "write") {
  const [row] = await db.select().from(parts).where(eq(parts.id, partId)).limit(1);
  if (!row) throw new AppError(404, "not_found", "Part not found");
  const access = await getVehicleAccessLevel(db, callerId, row.vehicleId);
  if (!access) throw new AppError(404, "not_found", "Part not found");
  if (mode === "write" && access === "view") {
    throw new AppError(403, "insufficient_permission", "Full access required");
  }
  if (mode === "write" && access === "add_edit_own" && row.createdBy !== callerId) {
    throw new AppError(403, "insufficient_permission", "Can only edit own parts");
  }
  if (organizationScoped && mode === "write" && access !== "owner" && row.adminCorrectedBy) {
    throw new AppError(409, "admin_corrected", "Updated by Fleet Admin; submit a correction for review");
  }
  return row;
}

/**
 * Record a change under the acting user, and also under every other user in
 * the vehicle's change audience (the vehicle owner plus users holding an
 * active share). This keeps shared vehicles and their history in sync
 * across everyone who can access them.
 */
async function recordVehicleScopedChange(
  appDb: Db,
  params: {
    actorUserId: string;
    vehicleId: string;
    entityType: string;
    entityId: string;
    op: string;
    payload: Record<string, unknown> | null;
  },
) {
  if (!params.payload) return;

  await recordChange(appDb, {
    userId: params.actorUserId,
    entityType: params.entityType,
    entityId: params.entityId,
    op: params.op as "upsert" | "archive" | "delete",
    payload: params.payload,
  });

  const audience = await getVehicleChangeAudience(appDb, params.vehicleId);
  for (const userId of audience) {
    if (userId === params.actorUserId) continue;
    await recordChange(appDb, {
      userId,
      entityType: params.entityType,
      entityId: params.entityId,
      op: params.op as "upsert" | "archive" | "delete",
      payload: params.payload,
    });
  }
}


  const db = () => transaction.getStore() ?? app.db;
  const uid = (request: { authUser?: { sub: string } }) => request.authUser!.sub;
  async function checkRevision(request: FastifyRequest) {
    if (request.method !== "PATCH" && request.method !== "DELETE") return;
    const params = request.params as Record<string, string>;
    const tables = { serviceRecordId: serviceRecords, expenseId: expenses, documentId: documents, fuelLogId: fuelLogs, partId: parts };
    for (const [key, table] of Object.entries(tables)) {
      if (!params[key]) continue;
      const [row] = await db().select().from(table).where(eq(table.id, uuid.parse(params[key]))).for("update");
      if (!row) return;
      await getAccessibleVehicle(db(), uid(request), row.vehicleId, "full");
      const access = await getVehicleAccessLevel(db(), uid(request), row.vehicleId);
      const author = "createdBy" in row ? row.createdBy : "userId" in row ? row.userId : null;
      if (access !== "owner" && author !== uid(request)) throw new AppError(403, "insufficient_permission", "Can only edit own records");
      if (access !== "owner" && row.adminCorrectedBy) throw new AppError(409, "admin_corrected", "Updated by Fleet Admin; submit a correction for review");
      if ("sourceId" in row && row.sourceId) throw new AppError(409, "derived_expense", "Change the linked service or fuel log to correct this expense");
      const expected = request.headers["if-match"];
      if (expected === undefined) throw new AppError(428, "revision_required", "Send the record revision in If-Match");
      if (String(row.revision) !== expected) throw new AppError(409, "revision_conflict", "Record changed; submit a correction for review");
    }
  }

  const guard = async (request: { authUser?: { sub: string } }) => {
    if (!organizationScoped && request.authUser?.sub) await assertPersonalGarageAllowed(db(), request.authUser.sub);
  };
  if (organizationScoped) {
    app.addHook("onRoute", (route) => {
      const handler = route.handler;
      route.handler = async function(request, reply) {
        return app.db.transaction(async (tx) => transaction.run(tx as Db, () => requestedOrganization.run(uuid.parse((request.params as { organizationId: string }).organizationId), async () => {
          requireFleetClient(request);
          const orgId = uuid.parse((request.params as { organizationId: string }).organizationId);
          const { membership } = await getOrganizationAccess(db(), uid(request), orgId, ["org_admin", "org_driver"]);
          if (membership.role === "org_admin") {
            requireFleetPortal(request);
            await db().execute(sql`select set_config('autox.record_admin', ${uid(request)}, true)`);
          }
          await assertPasswordChangeClear(db(), uid(request));
          const operationId = request.headers["idempotency-key"];
          const fingerprint = createHash("sha256").update(canonical([request.method, request.url, request.headers["if-match"], request.body])).digest("hex");
          if (operationId) {
            const id = uuid.parse(operationId);
            const inserted = await db().insert(organizationOperations).values({ id, orgId, userId: uid(request), fingerprint }).onConflictDoNothing().returning();
            if (!inserted.length) {
              const [previous] = await db().select().from(organizationOperations).where(eq(organizationOperations.id, id));
              if (previous.userId !== uid(request) || previous.orgId !== orgId || previous.fingerprint !== fingerprint) throw new AppError(409, "operation_id_conflict", "Operation ID already used");
              reply.code(previous.statusCode ?? 200);
              return previous.result;
            }
          }
          const reviewId = request.headers["x-review-id"];
          let approvedReview;
          if (reviewId) {
            requireFleetPortal(request);
            const [review] = await db().select().from(organizationReviews).where(and(eq(organizationReviews.id, uuid.parse(reviewId)), eq(organizationReviews.orgId, orgId))).for("update");
            if (!review || review.status !== "pending" || membership.role !== "org_admin") throw new AppError(409, "review_changed", "Review is no longer pending");
            const operation = review.operation as { entity_id: string; vehicle_id: string };
            const params = request.params as Record<string, string>;
            if (!Object.values(params).includes(operation.entity_id) && (request.body as { id?: string })?.id !== operation.entity_id) throw new AppError(422, "review_mismatch", "Review does not match this record");
            const [link] = await db().select().from(organizationVehicles).where(and(eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, operation.vehicle_id)));
            if (!link) throw new AppError(409, "vehicle_no_longer_in_org", "Cannot accept records for a transferred vehicle");
            approvedReview = review;
          }
          await checkRevision(request);
          let scheduleVehicle: string | undefined;
          if (["POST", "PATCH", "DELETE"].includes(request.method) && request.routeOptions.url?.includes("service-records")) {
            const params = request.params as Record<string, string>;
            scheduleVehicle = params.vehicleId;
            if (params.serviceRecordId) {
              const [service] = await db().select().from(serviceRecords).where(eq(serviceRecords.id, params.serviceRecordId));
              scheduleVehicle = service?.vehicleId;
            }
            if (scheduleVehicle) await db().execute(sql`insert into plan_schedule_baselines (plan_item_id, next_due_on, next_due_mileage)
              select id, next_due_on, next_due_mileage from plan_items where vehicle_id = ${scheduleVehicle}
              on conflict do nothing`);
          }
          const runHandler = async () => {
            await validateOrganizationRequest(request);
            return handler.call(this, request, reply);
          };
          const result = approvedReview
            ? await reviewAuthor.run(approvedReview.userId, runHandler)
            : await runHandler();
          if (scheduleVehicle) {
            const plans = await db().select().from(planItems).where(eq(planItems.vehicleId, scheduleVehicle));
            for (const plan of plans) {
              const [last] = await db().select({ servicedOn: serviceRecords.servicedOn, odometer: serviceRecords.odometer })
                .from(serviceRecordItems).innerJoin(serviceRecords, eq(serviceRecords.id, serviceRecordItems.serviceRecordId))
                .where(and(eq(serviceRecordItems.planItemId, plan.id), eq(serviceRecords.vehicleId, scheduleVehicle)))
                .orderBy(desc(serviceRecords.servicedOn), desc(serviceRecords.odometer), desc(serviceRecords.id)).limit(1);
              if (last) {
                await db().update(planItems).set({
                  nextDueOn: plan.intervalDays ? new Date(Date.parse(last.servicedOn) + plan.intervalDays * 86400000).toISOString().slice(0, 10) : null,
                  nextDueMileage: plan.intervalDistance ? String(Number(last.odometer) + Number(plan.intervalDistance)) : null,
                }).where(eq(planItems.id, plan.id));
              } else {
                await db().execute(sql`update plan_items p set next_due_on = b.next_due_on, next_due_mileage = b.next_due_mileage
                  from plan_schedule_baselines b where p.id = b.plan_item_id and p.id = ${plan.id}`);
              }
            }
          }
          if (approvedReview) await db().update(organizationReviews).set({ status: "accepted", reviewedBy: uid(request) }).where(eq(organizationReviews.id, approvedReview.id));
          if (operationId) await db().update(organizationOperations).set({ statusCode: reply.statusCode, result: result ?? null }).where(eq(organizationOperations.id, String(operationId)));
          return result;
        })));
      };
    });
    async function validateOrganizationRequest(request: FastifyRequest) {
      requireFleetClient(request);
      const userId = uid(request);
      const orgId = uuid.parse((request.params as { organizationId: string }).organizationId);
      const { membership } = await getOrganizationAccess(db(), userId, orgId, ["org_admin", "org_driver"]);
      await assertPasswordChangeClear(db(), userId);
      // Mobile org data is a Driver surface. Admin record changes use the portal.
      if (membership.role === "org_admin") requireFleetPortal(request);
      const params = request.params as Record<string, string>;
      const body = (request.body ?? {}) as Record<string, unknown>;
      // Existing UUIDs must never turn idempotent creates into cross-vehicle reads.
      const recordTables = { "plan-items": planItems, "service-records": serviceRecords,
        "parts": parts, "fuel-logs": fuelLogs, "documents": documents, "expenses": expenses };
      const resource = request.routeOptions.url?.split("/").reverse().find((segment) => segment in recordTables);
      if (request.method === "POST" && resource && typeof body.id === "string") {
        const table = recordTables[resource as keyof typeof recordTables];
        const [existing] = await db().select().from(table).where(eq(table.id, uuid.parse(body.id)));
        if (existing && existing.vehicleId !== params.vehicleId) throw new AppError(409, "id_conflict", "Record ID already exists");
        if (existing && membership.role === "org_driver") {
          const author = "createdBy" in existing ? existing.createdBy : "userId" in existing ? existing.userId : null;
          if (author !== userId) throw new AppError(409, "id_conflict", "Record ID already exists");
        }
      }
      let vehicleId = params.vehicleId;
      let currentMedia: string | null = null;
      for (const [key, table] of Object.entries({ serviceRecordId: serviceRecords, expenseId: expenses, documentId: documents })) {
        if (!params[key]) continue;
        const [record] = await db().select().from(table).where(eq(table.id, uuid.parse(params[key])));
        vehicleId = record?.vehicleId;
        if (record) currentMedia = "mediaId" in record ? record.mediaId : record.receiptMediaId;
      }
      for (const mediaId of [body.media_id, body.receipt_media_id]) {
        if (typeof mediaId !== "string" || mediaId === currentMedia) continue;
        const [media] = await db().select().from(mediaObjects).where(eq(mediaObjects.id, uuid.parse(mediaId)));
        if (!media || media.userId !== (reviewAuthor.getStore() ?? userId)) throw new AppError(422, "invalid_media", "Attachment must belong to the submitter");
      }
      if (Array.isArray(body.parts)) {
        for (const ref of body.parts as { part_id?: string }[]) {
          if (!ref.part_id) continue;
          const [part] = await db().select().from(parts).where(eq(parts.id, uuid.parse(ref.part_id)));
          if (!part || part.vehicleId !== vehicleId) throw new AppError(422, "invalid_part", "Part must belong to this vehicle");
        }
      }
      if (Array.isArray(body.items)) {
        for (const item of body.items as { plan_item_id?: string }[]) {
          if (!item.plan_item_id) continue;
          const [plan] = await db().select().from(planItems).where(eq(planItems.id, uuid.parse(item.plan_item_id)));
          if (!plan || (!vehicleId || plan.vehicleId !== vehicleId)) throw new AppError(422, "invalid_plan_item", "Plan item must belong to this vehicle");
          await getAccessibleVehicle(db(), userId, plan.vehicleId, "full");
        }
      }

    }
  }

  app.get("/vehicles/:vehicleId/plan-items", async (request) => {
    await guard(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getAccessibleVehicle(db(), uid(request), vehicleId, "drive_only", true);
    const items = await db().select().from(planItems).where(eq(planItems.vehicleId, vehicleId));
    return { items: items.map(publicPlan) };
  });

  app.post("/vehicles/:vehicleId/plan-items", async (request, reply) => {
    await guard(request);
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const vehicle = await getOwnedVehicle(db(), uid(request), vehicleId);
    const body = z
      .object({
        id: uuid,
        name: z.string().min(1).max(80),
        interval_days: z.number().int().optional().nullable(),
        interval_distance: z.number().optional().nullable(),
        next_due_on: z.string().optional().nullable(),
        next_due_mileage: z.number().optional().nullable(),
        notes: z.string().optional().nullable(),
        catalog_key: z.string().optional().nullable(),
        enabled: z.boolean().optional(),
      })
      .parse(request.body);
    if (!body.interval_days && !body.interval_distance && body.next_due_on == null && body.next_due_mileage == null) {
      throw new AppError(422, "invalid_interval", "Provide a time interval, a distance interval, or both");
    }
    const [existing] = await db().select().from(planItems).where(eq(planItems.id, body.id)).limit(1);
    if (existing) { reply.code(201); return publicPlan(existing); }
    const computed = dueFrom(body.interval_days, body.interval_distance, reqNum(vehicle.mileage));
    const due = {
      nextDueOn: body.next_due_on ?? computed.nextDueOn,
      nextDueMileage: body.next_due_mileage ?? computed.nextDueMileage,
    };
    const [row] = await db()
      .insert(planItems)
      .values({
        id: body.id,
        vehicleId,
        name: body.name,
        intervalDays: body.interval_days ?? null,
        intervalDistance: body.interval_distance != null ? String(body.interval_distance) : null,
        nextDueOn: due.nextDueOn,
        nextDueMileage: due.nextDueMileage != null ? String(due.nextDueMileage) : null,
        notes: body.notes ?? null,
        catalogKey: body.catalog_key ?? null,
        enabled: body.enabled ?? true,
        createdBy: reviewAuthor.getStore() ?? uid(request),
      })
      .returning();
    const payload = publicPlan(row);
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId, entityType: "plan_item", entityId: row.id, op: "upsert", payload });
    reply.code(201); return payload;
  });

  app.get("/vehicles/:vehicleId/suggested-plan-items", async (request) => {
    await guard(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const vehicle = await getAccessibleVehicle(db(), uid(request), vehicleId, "drive_only");
    const rows = await db()
      .select()
      .from(maintenanceCatalog)
      .where(and(
        sql`${vehicle.fuelType} = ANY(${maintenanceCatalog.fuelTypes})`,
        eq(maintenanceCatalog.enabled, true),
        eq(maintenanceCatalog.vehicleClass, vehicle.vehicleClass),
        isNull(maintenanceCatalog.orgId),
      ))
      .orderBy(maintenanceCatalog.sortOrder);
    return {
      items: rows.map((row) => ({
        catalog_key: row.catalogKey,
        name: row.name,
        interval_days: row.intervalDays,
        interval_distance: row.intervalDistance != null ? Number(row.intervalDistance) : null,
        vehicle_class: row.vehicleClass,
        fuel_type: vehicle.fuelType,
      })),
    };
  });

  app.patch("/plan-items/:planItemId", async (request) => {
    await guard(request);
    requireOwner(request);
    const { planItemId } = request.params as { planItemId: string };
    await loadPlanItemFor(db(), uid(request), planItemId, "write");
    const body = z
      .object({
        name: z.string().optional(),
        interval_days: z.number().int().nullable().optional(),
        interval_distance: z.number().nullable().optional(),
        next_due_on: z.string().nullable().optional(),
        next_due_mileage: z.number().nullable().optional(),
        notes: z.string().optional().nullable(),
        enabled: z.boolean().optional(),
      })
      .parse(request.body ?? {});
    const [updated] = await db()
      .update(planItems)
      .set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.interval_days !== undefined ? { intervalDays: body.interval_days } : {}),
        ...(body.interval_distance !== undefined
          ? { intervalDistance: body.interval_distance != null ? String(body.interval_distance) : null }
          : {}),
        ...(body.next_due_on !== undefined ? { nextDueOn: body.next_due_on } : {}),
        ...(body.next_due_mileage !== undefined
          ? { nextDueMileage: body.next_due_mileage != null ? String(body.next_due_mileage) : null }
          : {}),
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
        ...(body.enabled !== undefined ? { enabled: body.enabled } : {}),
      })
      .where(eq(planItems.id, planItemId))
      .returning();
    const payload = publicPlan(updated);
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId: updated.vehicleId, entityType: "plan_item", entityId: updated.id, op: "upsert", payload });
    return payload;
  });

  app.delete("/plan-items/:planItemId", async (request, reply) => {
    await guard(request);
    requireOwner(request);
    const { planItemId } = request.params as { planItemId: string };
    const [row] = await db().select().from(planItems).where(eq(planItems.id, planItemId)).limit(1);
    if (!row) { reply.code(204); return null; }
    await loadPlanItemFor(db(), uid(request), planItemId, "write");
    await db().delete(planItems).where(eq(planItems.id, planItemId));
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId: row.vehicleId, entityType: "plan_item", entityId: planItemId, op: "delete", payload: { id: planItemId } });
    reply.code(204); return null;
  });

  if (organizationScoped) {
    app.delete("/service-records/:serviceRecordId", async (request, reply) => {
      const { serviceRecordId } = request.params as { serviceRecordId: string };
      await loadServiceRecordFor(db(), uid(request), serviceRecordId, "write");
      await db().delete(serviceRecordItems).where(eq(serviceRecordItems.serviceRecordId, serviceRecordId));
      await db().delete(serviceRecordParts).where(eq(serviceRecordParts.serviceRecordId, serviceRecordId));
      await db().delete(serviceRecords).where(eq(serviceRecords.id, serviceRecordId));
      reply.code(204); return null;
    });
    app.delete("/fuel-logs/:fuelLogId", async (request, reply) => {
      const { fuelLogId } = request.params as { fuelLogId: string };
      await loadFuelLogFor(db(), uid(request), fuelLogId, "write");
      await db().delete(fuelLogs).where(eq(fuelLogs.id, fuelLogId));
      reply.code(204); return null;
    });
  }

  const serviceBody = z.object({
    id: uuid,
    serviced_on: z.string(),
    odometer: z.number().min(0),
    total_cost: z.number().min(0),
    workshop_name: z.string().optional().nullable(),
    notes: z.string().optional().nullable(),
    receipt_media_id: uuid.optional().nullable(),
    items: z.array(z.object({
      id: uuid.optional(),
      plan_item_id: uuid.optional().nullable(),
      name: z.string(),
      line_cost: z.number().optional().nullable(),
    })).min(1),
    parts: z.array(z.object({ part_id: uuid, name: z.string(), id: uuid.optional() })).optional(),
  });

  app.get("/vehicles/:vehicleId/service-records", async (request) => {
    await guard(request);
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getAccessibleVehicle(db(), uid(request), vehicleId, "drive_only", true);
    const rows = await db().select().from(serviceRecords).where(eq(serviceRecords.vehicleId, vehicleId)).orderBy(desc(serviceRecords.servicedOn));
    const items = [];
    for (const row of rows) items.push(await loadService(db(), row.id));
    return { items };
  });

  app.post("/vehicles/:vehicleId/service-records", async (request, reply) => {
    await guard(request);
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const vehicle = await getAccessibleVehicle(db(), uid(request), vehicleId, "full");
    const body = serviceBody.parse(request.body);
    const [existing] = await db().select().from(serviceRecords).where(eq(serviceRecords.id, body.id)).limit(1);
    if (existing) { reply.code(201); return await loadService(db(), existing.id); }
    if (!organizationScoped && body.odometer < reqNum(vehicle.mileage)) {
      throw new AppError(422, "mileage_decrease", "Service odometer cannot be below vehicle mileage");
    }
    await db().insert(serviceRecords).values({
      id: body.id,
      vehicleId,
      servicedOn: body.serviced_on,
      odometer: String(body.odometer),
      totalCost: String(body.total_cost),
      workshopName: body.workshop_name ?? null,
      notes: body.notes ?? null,
      receiptMediaId: body.receipt_media_id ?? null,
      createdBy: reviewAuthor.getStore() ?? uid(request),
    });
    for (const item of body.items) {
      await db().insert(serviceRecordItems).values({
        id: item.id ?? newId(),
        serviceRecordId: body.id,
        planItemId: item.plan_item_id ?? null,
        name: item.name,
        lineCost: item.line_cost != null ? String(item.line_cost) : null,
      });
      if (item.plan_item_id) {
        const [plan] = await db().select().from(planItems).where(eq(planItems.id, item.plan_item_id)).limit(1);
        if (plan) {
          const due = dueFrom(plan.intervalDays, num(plan.intervalDistance), body.odometer);
          await db()
            .update(planItems)
            .set({
              nextDueOn: due.nextDueOn,
              nextDueMileage: due.nextDueMileage != null ? String(due.nextDueMileage) : null,
            })
            .where(eq(planItems.id, plan.id));
        }
      }
    }
    for (const part of body.parts ?? []) {
      await db().insert(serviceRecordParts).values({
        id: part.id ?? newId(),
        serviceRecordId: body.id,
        partId: part.part_id,
        name: part.name,
      });
    }
    if (body.odometer > reqNum(vehicle.mileage)) {
      await db().update(vehicles).set({ mileage: String(body.odometer), updatedAt: new Date() }).where(eq(vehicles.id, vehicleId));
      await fanOutVehicleChange(db(), { vehicleId, entityType: "vehicle", entityId: vehicleId, op: "upsert", payload: { id: vehicleId, mileage: body.odometer, name: vehicle.name } });
    }
    const payload = await loadService(db(), body.id);
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId, entityType: "service_record", entityId: body.id, op: "upsert", payload });
    reply.code(201); return payload;
  });

  app.get("/service-records/:serviceRecordId", async (request) => {
    await guard(request);
    requireOwner(request);
    const { serviceRecordId } = request.params as { serviceRecordId: string };
    const payload = await loadService(db(), serviceRecordId);
    if (!payload) throw new AppError(404, "not_found", "Service record not found");
    await getAccessibleVehicle(db(), uid(request), payload.vehicle_id, "drive_only", true);
    return payload;
  });

  app.patch("/service-records/:serviceRecordId", async (request) => {
    await guard(request);
    requireOwner(request);
    const { serviceRecordId } = request.params as { serviceRecordId: string };
    const existing = await loadService(db(), serviceRecordId);
    if (!existing) throw new AppError(404, "not_found", "Service record not found");
    await loadServiceRecordFor(db(), uid(request), serviceRecordId, "write");
    const body = serviceBody.partial().parse(request.body ?? {});
    await db()
      .update(serviceRecords)
      .set({
        ...(body.serviced_on ? { servicedOn: body.serviced_on } : {}),
        ...(body.odometer !== undefined ? { odometer: String(body.odometer) } : {}),
        ...(body.total_cost !== undefined ? { totalCost: String(body.total_cost) } : {}),
        ...(body.workshop_name !== undefined ? { workshopName: body.workshop_name } : {}),
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
        ...(body.receipt_media_id !== undefined ? { receiptMediaId: body.receipt_media_id } : {}),
      })
      .where(eq(serviceRecords.id, serviceRecordId));
    if (body.items !== undefined) {
      await db().delete(serviceRecordItems).where(eq(serviceRecordItems.serviceRecordId, serviceRecordId));
      for (const item of body.items) {
        await db().insert(serviceRecordItems).values({
          id: item.id ?? newId(),
          serviceRecordId,
          planItemId: item.plan_item_id ?? null,
          name: item.name,
          lineCost: item.line_cost != null ? String(item.line_cost) : null,
        });
      }
    }
    if (body.parts !== undefined) {
      await db().delete(serviceRecordParts).where(eq(serviceRecordParts.serviceRecordId, serviceRecordId));
      for (const part of body.parts) {
        await db().insert(serviceRecordParts).values({
          id: part.id ?? newId(),
          serviceRecordId,
          partId: part.part_id,
          name: part.name,
        });
      }
    }
    if (body.odometer !== undefined && body.odometer != null) {
      const [vehicle] = await db().select({ mileage: vehicles.mileage, name: vehicles.name }).from(vehicles).where(eq(vehicles.id, existing.vehicle_id)).limit(1);
      if (vehicle && body.odometer > reqNum(vehicle.mileage)) {
        await db().update(vehicles).set({ mileage: String(body.odometer), updatedAt: new Date() }).where(eq(vehicles.id, existing.vehicle_id));
        await fanOutVehicleChange(db(), { vehicleId: existing.vehicle_id, entityType: "vehicle", entityId: existing.vehicle_id, op: "upsert", payload: { id: existing.vehicle_id, mileage: body.odometer, name: vehicle.name } });
      }
    }
    const payload = await loadService(db(), serviceRecordId);
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId: existing.vehicle_id, entityType: "service_record", entityId: serviceRecordId, op: "upsert", payload });
    return payload;
  });

  app.get("/vehicles/:vehicleId/parts", async (request) => {
    await guard(request);
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getAccessibleVehicle(db(), uid(request), vehicleId, "drive_only", true);
    const items = await db().select().from(parts).where(eq(parts.vehicleId, vehicleId)).orderBy(asc(parts.name));
    return {
      items: items.map((p) => ({
        id: p.id,
        vehicle_id: p.vehicleId,
        name: p.name,
        brand: p.brand,
        part_number: p.partNumber,
        notes: p.notes,
      })),
    };
  });

  app.post("/vehicles/:vehicleId/parts", async (request, reply) => {
    await guard(request);
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getAccessibleVehicle(db(), uid(request), vehicleId, "full");
    const body = z.object({
      id: uuid,
      name: z.string().min(1),
      brand: z.string().optional().nullable(),
      part_number: z.string().optional().nullable(),
      notes: z.string().optional().nullable(),
    }).parse(request.body);
    const [existing] = await db().select().from(parts).where(eq(parts.id, body.id)).limit(1);
    if (existing) {
      reply.code(201); return publicPart(existing);
    }
    const [row] = await db()
      .insert(parts)
      .values({
        id: body.id,
        vehicleId,
        name: body.name,
        brand: body.brand ?? null,
        partNumber: body.part_number ?? null,
        notes: body.notes ?? null,
        createdBy: reviewAuthor.getStore() ?? uid(request),
      })
      .returning();
    const payload = publicPart(row);
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId: row.vehicleId, entityType: "part", entityId: row.id, op: "upsert", payload });
    reply.code(201); return payload;
  });

  app.patch("/parts/:partId", async (request) => {
    await guard(request);
    requireOwner(request);
    const { partId } = request.params as { partId: string };
    await loadPartFor(db(), uid(request), partId, "write");
    const body = z.object({
      name: z.string().optional(),
      brand: z.string().optional().nullable(),
      part_number: z.string().optional().nullable(),
      notes: z.string().optional().nullable(),
    }).parse(request.body ?? {});
    const [updated] = await db()
      .update(parts)
      .set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.brand !== undefined ? { brand: body.brand } : {}),
        ...(body.part_number !== undefined ? { partNumber: body.part_number } : {}),
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
      })
      .where(eq(parts.id, partId))
      .returning();
    const payload = publicPart(updated);
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId: updated.vehicleId, entityType: "part", entityId: updated.id, op: "upsert", payload });
    return payload;
  });

  const publicFuelType = (row: typeof fuelTypes.$inferSelect) => ({
    id: row.id,
    user_id: row.userId,
    name: row.name,
    kind: row.kind,
    unit: row.unit,
  });

  app.get("/fuel-types", async (request) => {
    requireOwner(request);
    const items = await db().select().from(fuelTypes).where(eq(fuelTypes.userId, uid(request)));
    return { items: items.map(publicFuelType) };
  });

  app.post("/fuel-types", async (request, reply) => {
    requireOwner(request);
    const body = z.object({
      id: uuid,
      name: z.string().min(1),
      kind: z.enum(["liquid", "electric"]),
      unit: z.string().min(1),
    }).parse(request.body);
    const [existing] = await db().select().from(fuelTypes).where(eq(fuelTypes.id, body.id)).limit(1);
    if (existing) { reply.code(201); return publicFuelType(existing); }
    const clash = await db().select().from(fuelTypes).where(eq(fuelTypes.userId, uid(request)));
    if (clash.some((t) => t.name.toLowerCase() === body.name.toLowerCase())) {
      throw new AppError(409, "name_taken", "Fuel type name already exists");
    }
    const [row] = await db()
      .insert(fuelTypes)
      .values({ id: body.id, userId: uid(request), name: body.name, kind: body.kind, unit: body.unit })
      .returning();
    const payload = publicFuelType(row);
    await recordChange(db(), { userId: uid(request), entityType: "fuel_type", entityId: row.id, op: "upsert", payload });
    reply.code(201); return payload;
  });

  app.patch("/fuel-types/:fuelTypeId", async (request) => {
    requireOwner(request);
    const { fuelTypeId } = request.params as { fuelTypeId: string };
    const [row] = await db().select().from(fuelTypes).where(eq(fuelTypes.id, fuelTypeId)).limit(1);
    if (!row || row.userId !== uid(request)) throw new AppError(404, "not_found", "Fuel type not found");
    const body = z.object({
      name: z.string().optional(),
      kind: z.enum(["liquid", "electric"]).optional(),
      unit: z.string().optional(),
    }).parse(request.body ?? {});
    const [updated] = await db()
      .update(fuelTypes)
      .set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.kind !== undefined ? { kind: body.kind } : {}),
        ...(body.unit !== undefined ? { unit: body.unit } : {}),
      })
      .where(eq(fuelTypes.id, fuelTypeId))
      .returning();
    const payload = publicFuelType(updated);
    await recordChange(db(), { userId: uid(request), entityType: "fuel_type", entityId: updated.id, op: "upsert", payload });
    return payload;
  });

  app.get("/vehicles/:vehicleId/fuel-logs", async (request) => {
    await guard(request);
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getAccessibleVehicle(db(), uid(request), vehicleId, "drive_only", true);
    const q = request.query as { fuel_type_id?: string; month?: string };
    let rows = await db().select().from(fuelLogs).where(eq(fuelLogs.vehicleId, vehicleId)).orderBy(desc(fuelLogs.loggedOn));
    if (q.fuel_type_id) rows = rows.filter((r) => r.fuelTypeId === q.fuel_type_id);
    if (q.month === "this_month") {
      const prefix = new Date().toISOString().slice(0, 7);
      rows = rows.filter((r) => dateOnly(r.loggedOn)?.startsWith(prefix));
    }
    return { items: rows.map(publicFuelLog) };
  });

  app.post("/vehicles/:vehicleId/fuel-logs", async (request, reply) => {
    await guard(request);
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const vehicle = await getAccessibleVehicle(db(), uid(request), vehicleId, "full");
    const body = z.object({
      id: uuid,
      fuel_type_id: uuid,
      logged_on: z.string(),
      amount: z.number().positive(),
      cost: z.number().min(0),
      odometer: z.number().min(0).max(999999).optional().nullable(),
    }).parse(request.body);
    if (body.logged_on.slice(0, 10) > new Date().toISOString().slice(0, 10)) {
      throw new AppError(422, "invalid_date", "Date cannot be in the future");
    }
    const [existing] = await db().select().from(fuelLogs).where(eq(fuelLogs.id, body.id)).limit(1);
    if (existing) { reply.code(201); return publicFuelLog(existing); }
    const [ft] = await db().select().from(fuelTypes).where(eq(fuelTypes.id, body.fuel_type_id)).limit(1);
    if (!ft || ft.userId !== (reviewAuthor.getStore() ?? uid(request))) throw new AppError(422, "invalid_fuel_type", "Unknown fuel type");
    const kind = vehicle.fuelType === "electric" ? "charge" : "refuel";
    if (kind === "charge" && ft.kind !== "electric") {
      throw new AppError(422, "invalid_fuel_type", "Electric vehicles log charge types");
    }
    if (kind === "refuel" && ft.kind !== "liquid") {
      throw new AppError(422, "invalid_fuel_type", "Petrol and hybrid vehicles log liquid types");
    }
    if (!organizationScoped && body.odometer != null && body.odometer < reqNum(vehicle.mileage)) {
      throw new AppError(422, "mileage_decrease", "Fuel odometer cannot be below vehicle mileage");
    }
    const [row] = await db()
      .insert(fuelLogs)
      .values({
        id: body.id,
        userId: reviewAuthor.getStore() ?? uid(request),
        vehicleId,
        kind,
        fuelTypeId: ft.id,
        fuelTypeName: ft.name,
        unit: ft.unit,
        loggedOn: body.logged_on,
        amount: String(body.amount),
        cost: String(body.cost),
        odometer: body.odometer != null ? String(body.odometer) : null,
      })
      .returning();
    if (body.odometer != null && body.odometer > reqNum(vehicle.mileage)) {
      await db().update(vehicles).set({ mileage: String(body.odometer), updatedAt: new Date() }).where(eq(vehicles.id, vehicleId));
      await fanOutVehicleChange(db(), { vehicleId, entityType: "vehicle", entityId: vehicleId, op: "upsert", payload: { id: vehicleId, mileage: body.odometer, name: vehicle.name } });
    }
    const payload = publicFuelLog(row);
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId, entityType: "fuel_log", entityId: row.id, op: "upsert", payload });
    reply.code(201); return payload;
  });

  app.get("/fuel-logs/:fuelLogId", async (request) => {
    await guard(request);
    requireOwner(request);
    const { fuelLogId } = request.params as { fuelLogId: string };
    const row = await loadFuelLogFor(db(), uid(request), fuelLogId, "read");
    return publicFuelLog(row);
  });

  app.patch("/fuel-logs/:fuelLogId", async (request) => {
    await guard(request);
    requireOwner(request);
    const { fuelLogId } = request.params as { fuelLogId: string };
    const row = await loadFuelLogFor(db(), uid(request), fuelLogId, "write");
    const body = z.object({
      fuel_type_id: uuid.optional(),
      logged_on: z.string().optional(),
      amount: z.number().optional(),
      cost: z.number().optional(),
      odometer: z.number().min(0).max(999999).optional().nullable(),
    }).parse(request.body ?? {});
    let fuelTypeName = row.fuelTypeName;
    let unit = row.unit;
    let fuelTypeId = row.fuelTypeId;
    if (body.fuel_type_id) {
      const [ft] = await db().select().from(fuelTypes).where(eq(fuelTypes.id, body.fuel_type_id)).limit(1);
      if (!ft || (ft.userId !== (reviewAuthor.getStore() ?? uid(request)) && ft.id !== row.fuelTypeId)) throw new AppError(422, "invalid_fuel_type", "Unknown fuel type");
      fuelTypeName = ft.name;
      unit = ft.unit;
      fuelTypeId = ft.id;
    }
    const [updated] = await db()
      .update(fuelLogs)
      .set({
        ...(body.logged_on ? { loggedOn: body.logged_on } : {}),
        ...(body.amount !== undefined ? { amount: String(body.amount) } : {}),
        ...(body.cost !== undefined ? { cost: String(body.cost) } : {}),
        ...(body.odometer !== undefined ? { odometer: body.odometer != null ? String(body.odometer) : null } : {}),
        fuelTypeId,
        fuelTypeName,
        unit,
      })
      .where(eq(fuelLogs.id, fuelLogId))
      .returning();
    if (body.odometer != null) {
      const [vehicle] = await db().select({ mileage: vehicles.mileage, name: vehicles.name }).from(vehicles).where(eq(vehicles.id, row.vehicleId)).limit(1);
      if (body.odometer > reqNum(vehicle?.mileage ?? 0)) {
        await db().update(vehicles).set({ mileage: String(body.odometer), updatedAt: new Date() }).where(eq(vehicles.id, row.vehicleId));
        await fanOutVehicleChange(db(), { vehicleId: row.vehicleId, entityType: "vehicle", entityId: row.vehicleId, op: "upsert", payload: { id: row.vehicleId, mileage: body.odometer, name: vehicle?.name } });
      }
    }
    const payload = publicFuelLog(updated);
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId: row.vehicleId, entityType: "fuel_log", entityId: updated.id, op: "upsert", payload });
    return payload;
  });

  app.get("/vehicles/:vehicleId/documents", async (request) => {
    await guard(request);
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getAccessibleVehicle(db(), uid(request), vehicleId, "drive_only", true);
    const category = (request.query as { category?: string }).category;
    let rows = await db().select().from(documents).where(eq(documents.vehicleId, vehicleId));
    if (category) rows = rows.filter((r) => r.category === category);
    return { items: rows.map(publicDoc) };
  });

  app.post("/vehicles/:vehicleId/documents", async (request, reply) => {
    await guard(request);
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getAccessibleVehicle(db(), uid(request), vehicleId, "full");
    const body = z.object({
      id: uuid,
      name: z.string().min(1).max(120),
      category: z.enum(["insurance", "registration", "invoice", "warranty", "receipt", "other"]),
      notes: z.string().optional().nullable(),
      expires_on: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional().nullable(),
      media_id: uuid.optional().nullable(),
    }).parse(request.body);
    const [existing] = await db().select().from(documents).where(eq(documents.id, body.id)).limit(1);
    if (existing) { reply.code(201); return publicDoc(existing); }
    const [row] = await db()
      .insert(documents)
      .values({
        id: body.id,
        vehicleId,
        name: body.name,
        category: body.category,
        notes: body.notes ?? null,
        expiresOn: body.expires_on ?? null,
        mediaId: body.media_id ?? null,
        createdBy: reviewAuthor.getStore() ?? uid(request),
      })
      .returning();
    const payload = publicDoc(row);
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId, entityType: "document", entityId: row.id, op: "upsert", payload });
    reply.code(201); return payload;
  });

  app.get("/documents/:documentId", async (request) => {
    await guard(request);
    requireOwner(request);
    const { documentId } = request.params as { documentId: string };
    const [row] = await db().select().from(documents).where(eq(documents.id, documentId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Document not found");
    await getAccessibleVehicle(db(), uid(request), row.vehicleId, "drive_only", true);
    return publicDoc(row);
  });

  app.patch("/documents/:documentId", async (request) => {
    await guard(request);
    requireOwner(request);
    const { documentId } = request.params as { documentId: string };
    await loadDocumentFor(db(), uid(request), documentId, "write");
    const [row] = await db().select().from(documents).where(eq(documents.id, documentId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Document not found");
    const body = z.object({
      name: z.string().optional(),
      category: z.enum(["insurance", "registration", "invoice", "warranty", "receipt", "other"]).optional(),
      notes: z.string().optional().nullable(),
      expires_on: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional().nullable(),
      media_id: uuid.optional().nullable(),
    }).parse(request.body ?? {});
    const [updated] = await db()
      .update(documents)
      .set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.category !== undefined ? { category: body.category } : {}),
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
        ...(body.expires_on !== undefined ? { expiresOn: body.expires_on } : {}),
        ...(body.media_id !== undefined ? { mediaId: body.media_id } : {}),
      })
      .where(eq(documents.id, documentId))
      .returning();
    const payload = publicDoc(updated);
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId: row.vehicleId, entityType: "document", entityId: updated.id, op: "upsert", payload });
    return payload;
  });

  app.delete("/documents/:documentId", async (request, reply) => {
    await guard(request);
    requireOwner(request);
    const { documentId } = request.params as { documentId: string };
    const [row] = await db().select().from(documents).where(eq(documents.id, documentId)).limit(1);
    if (row) {
      await loadDocumentFor(db(), uid(request), documentId, "write");
      await db().delete(documents).where(eq(documents.id, documentId));
      await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId: row.vehicleId, entityType: "document", entityId: documentId, op: "delete", payload: { id: documentId } });
    }
    reply.code(204); return null;
  });

  const expenseBody = z.object({
    id: uuid,
    category: z.enum(["fuel", "maintenance", "insurance", "parking", "tolls", "parts", "other"]),
    amount: z.number().min(0.01).max(999999.99),
    incurred_on: z.string(),
    notes: z.string().max(500).optional().nullable(),
    receipt_media_id: uuid.optional().nullable(),
    parts: z.array(z.object({ part_id: uuid, name: z.string(), id: uuid.optional() })).optional(),
  });

  app.get("/vehicles/:vehicleId/expenses", async (request) => {
    await guard(request);
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getAccessibleVehicle(db(), uid(request), vehicleId, "drive_only", true);
    const category = (request.query as { category?: string }).category;
    let rows = await db().select().from(expenses).where(eq(expenses.vehicleId, vehicleId)).orderBy(desc(expenses.incurredOn));
    if (category) rows = rows.filter((r) => r.category === category);
    const items = [];
    for (const row of rows) items.push(await publicExpense(db(), row.id));
    return { items };
  });

  app.post("/vehicles/:vehicleId/expenses", async (request, reply) => {
    await guard(request);
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getAccessibleVehicle(db(), uid(request), vehicleId, "full");
    const body = expenseBody.parse(request.body);
    const [existing] = await db().select().from(expenses).where(eq(expenses.id, body.id)).limit(1);
    if (existing) { reply.code(201); return await publicExpense(db(), existing.id); }
    await db().insert(expenses).values({
      id: body.id,
      vehicleId,
      category: body.category,
      amount: String(body.amount),
      incurredOn: body.incurred_on,
      notes: body.notes ?? null,
      receiptMediaId: body.receipt_media_id ?? null,
      createdBy: reviewAuthor.getStore() ?? uid(request),
    });
    for (const part of body.parts ?? []) {
      await db().insert(expenseParts).values({
        id: part.id ?? newId(),
        expenseId: body.id,
        partId: part.part_id,
        name: part.name,
      });
    }
    const payload = await publicExpense(db(), body.id);
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId, entityType: "expense", entityId: body.id, op: "upsert", payload });
    reply.code(201); return payload;
  });

  app.get("/vehicles/:vehicleId/expenses/summary", async (request) => {
    await guard(request);
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getAccessibleVehicle(db(), uid(request), vehicleId, "drive_only", true);
    const rows = await db().select().from(expenses).where(eq(expenses.vehicleId, vehicleId));
    const prefix = new Date().toISOString().slice(0, 7);
    const total = rows.reduce((s, e) => s + reqNum(e.amount), 0);
    const thisMonth = rows.filter((e) => dateOnly(e.incurredOn)?.startsWith(prefix)).reduce((s, e) => s + reqNum(e.amount), 0);
    const byCat = new Map<string, number>();
    for (const e of rows) byCat.set(e.category, (byCat.get(e.category) ?? 0) + reqNum(e.amount));
    return {
      this_month: thisMonth,
      total,
      by_category: [...byCat.entries()].map(([category, amount]) => ({
        category,
        amount,
        percent: total ? (amount / total) * 100 : 0,
      })),
    };
  });

  app.patch("/expenses/:expenseId", async (request) => {
    await guard(request);
    requireOwner(request);
    const { expenseId } = request.params as { expenseId: string };
    await loadExpenseFor(db(), uid(request), expenseId, "write");
    const current = await publicExpense(db(), expenseId);
    if (!current) throw new AppError(404, "not_found", "Expense not found");
    const body = expenseBody.partial().parse(request.body ?? {});
    await db()
      .update(expenses)
      .set({
        ...(body.category ? { category: body.category } : {}),
        ...(body.amount !== undefined ? { amount: String(body.amount) } : {}),
        ...(body.incurred_on ? { incurredOn: body.incurred_on } : {}),
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
        ...(body.receipt_media_id !== undefined ? { receiptMediaId: body.receipt_media_id } : {}),
      })
      .where(eq(expenses.id, expenseId));
    if (body.parts !== undefined) {
      await db().delete(expenseParts).where(eq(expenseParts.expenseId, expenseId));
      for (const part of body.parts) {
        await db().insert(expenseParts).values({
          id: part.id ?? newId(),
          expenseId,
          partId: part.part_id,
          name: part.name,
        });
      }
    }
    const payload = await publicExpense(db(), expenseId);
    await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId: current.vehicle_id, entityType: "expense", entityId: expenseId, op: "upsert", payload });
    return payload;
  });

  app.delete("/expenses/:expenseId", async (request, reply) => {
    await guard(request);
    requireOwner(request);
    const { expenseId } = request.params as { expenseId: string };
    const current = await publicExpense(db(), expenseId);
    if (current) {
      await loadExpenseFor(db(), uid(request), expenseId, "write");
      await db().delete(expenseParts).where(eq(expenseParts.expenseId, expenseId));
      await db().delete(expenses).where(eq(expenses.id, expenseId));
      await recordVehicleScopedChange(db(), { actorUserId: uid(request), vehicleId: current.vehicle_id, entityType: "expense", entityId: expenseId, op: "delete", payload: { id: expenseId } });
    }
    reply.code(204); return null;
  });

  app.get("/notifications", async (request) => {
    requireOwner(request);
    const rows = await db()
      .select()
      .from(notificationFeed)
      .where(eq(notificationFeed.userId, uid(request)))
      .orderBy(desc(notificationFeed.createdAt));
    return {
      items: rows.map((n) => ({
        id: n.id,
        vehicle_id: n.vehicleId,
        plan_item_id: n.planItemId,
        title: n.title,
        body: n.body,
        status: n.status,
        due_reason: n.dueReason,
        created_at: n.createdAt.toISOString(),
      })),
    };
  });

  app.patch("/notifications/:notificationId", async (request) => {
    requireOwner(request);
    const { notificationId } = request.params as { notificationId: string };
    const body = z.object({ status: z.enum(["unread", "read", "done", "dismissed"]) }).parse(request.body ?? {});
    const [row] = await db().select().from(notificationFeed).where(eq(notificationFeed.id, notificationId)).limit(1);
    if (!row || row.userId !== uid(request)) throw new AppError(404, "not_found", "Notification not found");
    const [updated] = await db()
      .update(notificationFeed)
      .set({ status: body.status })
      .where(eq(notificationFeed.id, notificationId))
      .returning();
    const payload = {
      id: updated.id,
      vehicle_id: updated.vehicleId,
      plan_item_id: updated.planItemId,
      title: updated.title,
      body: updated.body,
      status: updated.status,
      due_reason: updated.dueReason,
      created_at: updated.createdAt.toISOString(),
    };
    await recordChange(db(), { userId: uid(request), entityType: "notification", entityId: updated.id, op: "upsert", payload });
    return payload;
  });
};
}
