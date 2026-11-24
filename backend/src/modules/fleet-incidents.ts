import { createHash, randomUUID } from "node:crypto";
import { and, desc, eq, getTableColumns, inArray, sql } from "drizzle-orm";
import type { FastifyPluginAsync, FastifyRequest } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import {
  auditEvents, driverAssignments, fleetIncidentCategory, fleetIncidentPhotos, fleetIncidents,
  fleetIncidentWorkOrders, mediaObjects, organizationMembers, organizationVehicles, users, workOrders,
  workOrderIssueTypeEnum, workOrderUrgencyEnum,
} from "../db/schema.js";
import { AppError } from "../lib/errors.js";
import { requireFleetClient, requireFleetPortal, requireOwner } from "./auth.js";
import { assertPasswordChangeClear, getOrganizationAccess } from "./fleet.js";

const uuid = z.string().uuid();
const baseParams = z.object({ id: uuid });
const caseParams = baseParams.extend({ incidentId: uuid });
const eventTime = z.string().datetime({ offset: true }).transform(value => new Date(value));
const fields = z.object({
  event_at: eventTime.optional(),
  category: z.enum(fleetIncidentCategory.enumValues),
  description: z.string().trim().min(1).max(2000),
});
const photoIds = z.array(uuid.transform(id => id.toLowerCase())).max(5).refine(ids => new Set(ids).size === ids.length);
const create = fields.extend({ id: uuid.optional(), vehicle_id: uuid, driver_at_event_id: uuid.nullable().optional(), photo_ids: photoIds.default([]) }).strict();
const update = fields.partial().extend({ driver_at_event_id: uuid.nullable().optional() }).strict();
type Transaction = Parameters<Parameters<Db["transaction"]>[0]>[0];
const { submissionFingerprint, ...incidentColumns } = getTableColumns(fleetIncidents);
const notFound = () => new AppError(404, "incident_not_found", "Incident not found");

function assigned(orgId: string, vehicleId: string, actor: string) {
  return and(eq(driverAssignments.orgId, orgId), eq(driverAssignments.vehicleId, vehicleId),
    eq(driverAssignments.driverId, actor), eq(driverAssignments.status, "active"));
}

async function getSuggestions(db: Db | Transaction, orgId: string, vehicleId: string, eventAt: Date) {
  const at = eventAt.toISOString();
  return db.selectDistinct({ id: users.id, name: users.displayName }).from(driverAssignments)
    .innerJoin(users, eq(users.id, driverAssignments.driverId))
    .where(and(eq(driverAssignments.orgId, orgId), eq(driverAssignments.vehicleId, vehicleId),
      sql`${driverAssignments.assignedAt} <= ${at} AND (${driverAssignments.unassignedAt} IS NULL OR ${driverAssignments.unassignedAt} > ${at})`));
}

async function validateDriver(tx: Transaction, orgId: string, vehicleId: string, driverId: string) {
  const [driver] = await tx.select({ id: driverAssignments.id }).from(driverAssignments)
    .where(and(eq(driverAssignments.orgId, orgId), eq(driverAssignments.vehicleId, vehicleId),
      eq(driverAssignments.driverId, driverId))).limit(1);
  if (!driver) throw new AppError(422, "invalid_incident_driver", "Choose a driver with assignment history for this vehicle");
}

export const fleetIncidentsPlugin: FastifyPluginAsync = async app => {
  const base = "/organizations/:id/incidents";
  async function access(request: FastifyRequest, orgId: string) {
    requireFleetClient(request);
    const actor = request.authUser!.sub;
    await assertPasswordChangeClear(app.db, actor);
    const { membership, organization } = await getOrganizationAccess(app.db, actor, orgId);
    const manager = membership.role === "org_admin" || membership.role === "org_manager";
    if (membership.role === "org_driver") requireOwner(request); else requireFleetPortal(request);
    return { actor, manager, role: membership.role, currency: organization.currency };
  }
  async function management(request: FastifyRequest, orgId: string) {
    const identity = await access(request, orgId);
    if (!identity.manager) throw new AppError(403, "insufficient_org_role", "Fleet admin or manager access is required");
    return identity;
  }
  function visibility(identity: Awaited<ReturnType<typeof access>>) {
    if (identity.manager) return sql`true`;
    if (identity.role === "org_driver") return sql`EXISTS (
      SELECT 1 FROM driver_assignments a JOIN organization_vehicles v
        ON v.org_id = a.org_id AND v.vehicle_id = a.vehicle_id
      WHERE a.org_id = "fleet_incidents"."org_id" AND a.vehicle_id = "fleet_incidents"."vehicle_id"
        AND a.driver_id = ${identity.actor} AND a.status = 'active')`;
    return sql`EXISTS (
      SELECT 1 FROM fleet_incident_work_orders l JOIN work_orders w ON w.id = l.work_order_id
      WHERE l.incident_id = "fleet_incidents"."id" AND w.assigned_to = ${identity.actor})`;
  }
  async function readable(request: FastifyRequest, orgId: string, incidentId: string) {
    const identity = await access(request, orgId);
    const [incident] = await app.db.select(incidentColumns).from(fleetIncidents).where(and(
      eq(fleetIncidents.orgId, orgId), eq(fleetIncidents.id, incidentId), visibility(identity)));
    if (!incident) throw notFound();
    return incident;
  }
  async function lock(tx: Transaction, orgId: string, incidentId: string) {
    const [incident] = await tx.select(incidentColumns).from(fleetIncidents).where(and(
      eq(fleetIncidents.orgId, orgId), eq(fleetIncidents.id, incidentId))).for("update");
    if (!incident) throw notFound();
    return incident;
  }
  function requireOpen(incident: Pick<typeof fleetIncidents.$inferSelect, "closedAt">) {
    if (incident.closedAt) throw new AppError(409, "incident_closed", "Reopen this incident before editing it");
  }
  async function audit(tx: Transaction, actor: string, orgId: string, incidentId: string, action: string, details = {}) {
    await tx.insert(auditEvents).values({ adminUserId: actor, action, detail: { orgId, incidentId, ...details } });
  }

  app.get(base, async request => {
    const { id } = baseParams.parse(request.params);
    const identity = await access(request, id);
    const { page } = z.object({ page: z.coerce.number().int().min(1).max(100000).default(1) }).parse(request.query);
    const rows = await app.db.select(incidentColumns).from(fleetIncidents).where(and(eq(fleetIncidents.orgId, id), visibility(identity)))
      .orderBy(desc(fleetIncidents.eventAt), desc(fleetIncidents.id)).limit(51).offset((page - 1) * 50);
    return { items: rows.slice(0, 50), hasMore: rows.length > 50 };
  });
  app.get(base + "/driver-suggestions", async request => {
    const { id } = baseParams.parse(request.params);
    await management(request, id);
    const { vehicle_id, event_at } = z.object({ vehicle_id: uuid, event_at: eventTime }).parse(request.query);
    return getSuggestions(app.db, id, vehicle_id, event_at);
  });
  app.get(base + "/:incidentId", async request => {
    const { id, incidentId } = caseParams.parse(request.params);
    const incident = await readable(request, id, incidentId);
    const [repairs, photos] = await Promise.all([
      app.db.select({ id: workOrders.id, status: workOrders.status, description: workOrders.description })
        .from(fleetIncidentWorkOrders).innerJoin(workOrders, eq(workOrders.id, fleetIncidentWorkOrders.workOrderId))
        .where(eq(fleetIncidentWorkOrders.incidentId, incidentId)),
      app.db.select({ id: fleetIncidentPhotos.mediaId }).from(fleetIncidentPhotos)
        .where(eq(fleetIncidentPhotos.incidentId, incidentId)),
    ]);
    return { ...incident, repairs, photoIds: photos.map(photo => photo.id) };
  });
  app.get(base + "/:incidentId/photos/:mediaId", async (request, reply) => {
    const { id, incidentId, mediaId } = caseParams.extend({ mediaId: uuid }).parse(request.params);
    await readable(request, id, incidentId);
    const [photo] = await app.db.select({ key: mediaObjects.blobKey, contentType: mediaObjects.contentType })
      .from(fleetIncidentPhotos).innerJoin(mediaObjects, eq(mediaObjects.id, fleetIncidentPhotos.mediaId))
      .where(and(eq(fleetIncidentPhotos.incidentId, incidentId), eq(fleetIncidentPhotos.mediaId, mediaId)));
    if (!photo) throw new AppError(404, "photo_not_found", "Photo not found");
    return reply.header("Cache-Control", "private, no-store").type(photo.contentType).send(await app.media.get(photo.key));
  });

  app.post(base, async (request, reply) => {
    const { id } = baseParams.parse(request.params);
    const identity = await access(request, id);
    if (!identity.manager && identity.role !== "org_driver") throw new AppError(403, "forbidden", "Incident reporting is unavailable for this role");
    const body = create.parse(request.body);
    if (!identity.manager && body.driver_at_event_id !== undefined) throw new AppError(403, "forbidden", "Only fleet managers can set driver attribution");
    const fingerprint = createHash("sha256").update(JSON.stringify({
      vehicle: body.vehicle_id.toLowerCase(),
      eventAt: body.event_at?.toISOString(),
      category: body.category,
      description: body.description,
      driverAtEvent: body.driver_at_event_id?.toLowerCase() ?? body.driver_at_event_id,
      photos: [...body.photo_ids].sort(),
    })).digest("hex");
    const result = await app.db.transaction(async tx => {
      const [vehicle] = await tx.select({ id: organizationVehicles.id }).from(organizationVehicles)
        .where(and(eq(organizationVehicles.orgId, id), eq(organizationVehicles.vehicleId, body.vehicle_id))).for("share");
      if (!vehicle) throw new AppError(404, "vehicle_not_found", "Vehicle is not in this organization");
      if (!identity.manager) {
        const [assignment] = await tx.select({ id: driverAssignments.id }).from(driverAssignments)
          .where(assigned(id, body.vehicle_id, identity.actor)).limit(1).for("share");
        if (!assignment) throw new AppError(403, "not_assigned_to_vehicle", "Vehicle assignment is required");
      }
      const eventAt = body.event_at ?? new Date();
      if (body.driver_at_event_id) await validateDriver(tx, id, body.vehicle_id, body.driver_at_event_id);
      const suggestions = await getSuggestions(tx, id, body.vehicle_id, eventAt);
      const inferred = identity.manager ? (suggestions.length === 1 ? suggestions[0].id : null)
        : (suggestions.some(driver => driver.id === identity.actor) ? identity.actor : null);
      const driverAtEventId = body.driver_at_event_id === undefined ? inferred : body.driver_at_event_id;
      const incidentId = body.id ?? randomUUID();
      const [incident] = await tx.insert(fleetIncidents).values({
        id: incidentId, orgId: id, vehicleId: body.vehicle_id, reportedBy: identity.actor,
        driverAtEventId, eventAt, category: body.category, description: body.description, submissionFingerprint: fingerprint,
      }).onConflictDoNothing().returning(incidentColumns);
      if (!incident) {
        const [existing] = await tx.select(incidentColumns).from(fleetIncidents).where(and(
          eq(fleetIncidents.id, incidentId), eq(fleetIncidents.orgId, id),
          eq(fleetIncidents.reportedBy, identity.actor), eq(submissionFingerprint, fingerprint),
        ));
        if (!existing) throw new AppError(409, "incident_id_conflict", "This submission ID is already in use. Check Reports before submitting again.");
        return existing;
      }
      if (body.photo_ids.length) {
        const photos = await tx.select({ id: mediaObjects.id }).from(mediaObjects).where(and(
          inArray(mediaObjects.id, body.photo_ids), eq(mediaObjects.ownerOrgId, id),
          eq(mediaObjects.vehicleId, body.vehicle_id), eq(mediaObjects.userId, identity.actor),
          eq(mediaObjects.purpose, "incident_photo"))).orderBy(mediaObjects.id).for("update");
        const used = await tx.select().from(fleetIncidentPhotos).where(inArray(fleetIncidentPhotos.mediaId, body.photo_ids));
        if (photos.length !== body.photo_ids.length || used.length) {
          throw new AppError(422, "invalid_incident_photos", "Choose unused incident photos uploaded for this vehicle");
        }
      }
      if (body.photo_ids.length) await tx.insert(fleetIncidentPhotos)
        .values(body.photo_ids.map(mediaId => ({ incidentId: incident.id, mediaId })));
      return incident;
    });
    return reply.code(201).send(result);
  });

  app.patch(base + "/:incidentId", async request => {
    const { id, incidentId } = caseParams.parse(request.params);
    const { actor } = await management(request, id);
    const body = update.parse(request.body);
    return app.db.transaction(async tx => {
      const incident = await lock(tx, id, incidentId);
      requireOpen(incident);
      if (body.driver_at_event_id) await validateDriver(tx, id, incident.vehicleId, body.driver_at_event_id);
      const [updated] = await tx.update(fleetIncidents).set({
        category: body.category, description: body.description, eventAt: body.event_at,
        driverAtEventId: body.driver_at_event_id, updatedAt: new Date(),
      }).where(eq(fleetIncidents.id, incidentId)).returning(incidentColumns);
      await audit(tx, actor, id, incidentId, "fleet_incident_updated");
      return updated;
    });
  });
  app.post(base + "/:incidentId/close", async request => {
    const { id, incidentId } = caseParams.parse(request.params);
    const { actor } = await management(request, id);
    const { review_note } = z.object({ review_note: z.string().trim().max(2000).optional() }).parse(request.body ?? {});
    return app.db.transaction(async tx => {
      const incident = await lock(tx, id, incidentId);
      if (incident.closedAt) return incident;
      const now = new Date();
      const [updated] = await tx.update(fleetIncidents).set({ closedAt: now, closedBy: actor,
        reviewNote: review_note || null, updatedAt: now }).where(eq(fleetIncidents.id, incidentId)).returning(incidentColumns);
      await audit(tx, actor, id, incidentId, "fleet_incident_closed");
      return updated;
    });
  });
  app.post(base + "/:incidentId/reopen", async request => {
    const { id, incidentId } = caseParams.parse(request.params);
    const { actor } = await management(request, id);
    return app.db.transaction(async tx => {
      const incident = await lock(tx, id, incidentId);
      if (!incident.closedAt) return incident;
      const [updated] = await tx.update(fleetIncidents).set({ closedAt: null, closedBy: null,
        reviewNote: null, updatedAt: new Date() }).where(eq(fleetIncidents.id, incidentId)).returning(incidentColumns);
      await audit(tx, actor, id, incidentId, "fleet_incident_reopened",
        { previousClosedAt: incident.closedAt, previousClosedBy: incident.closedBy });
      return updated;
    });
  });
  app.put(base + "/:incidentId/work-orders/:workOrderId", async request => {
    const { id, incidentId, workOrderId } = caseParams.extend({ workOrderId: uuid }).parse(request.params);
    const { actor } = await management(request, id);
    return app.db.transaction(async tx => {
      const incident = await lock(tx, id, incidentId);
      requireOpen(incident);
      const [repair] = await tx.select({ id: workOrders.id }).from(workOrders).where(and(
        eq(workOrders.id, workOrderId), eq(workOrders.orgId, id), eq(workOrders.vehicleId, incident.vehicleId))).for("share");
      if (!repair) throw new AppError(404, "work_order_not_found", "Work order is not available for this vehicle");
      const [link] = await tx.insert(fleetIncidentWorkOrders).values({
        incidentId, workOrderId, orgId: id, vehicleId: incident.vehicleId,
      }).onConflictDoNothing().returning();
      if (link) await audit(tx, actor, id, incidentId, "fleet_incident_repair_linked", { workOrderId });
      return { workOrderId };
    });
  });
  app.post(base + "/:incidentId/work-orders", async (request, reply) => {
    const { id, incidentId } = caseParams.parse(request.params);
    const { actor, currency } = await management(request, id);
    const body = z.object({ id: uuid, odometer_km: z.number().int().min(0).max(2147483647),
      issue_type: z.enum(workOrderIssueTypeEnum.enumValues), urgency: z.enum(workOrderUrgencyEnum.enumValues),
      description: z.string().trim().min(10).max(2000) }).parse(request.body);
    if (!currency) throw new AppError(409, "currency_required", "Set the fleet currency before creating repairs");
    const repair = await app.db.transaction(async tx => {
      const incident = await lock(tx, id, incidentId);
      requireOpen(incident);
      const [existing] = await tx.select().from(fleetIncidentWorkOrders).where(and(
        eq(fleetIncidentWorkOrders.incidentId, incidentId), eq(fleetIncidentWorkOrders.workOrderId, body.id)));
      if (existing) return { workOrderId: existing.workOrderId };
      const [vehicle] = await tx.select({ id: organizationVehicles.id }).from(organizationVehicles)
        .where(and(eq(organizationVehicles.orgId, id), eq(organizationVehicles.vehicleId, incident.vehicleId))).for("share");
      if (!vehicle) throw new AppError(409, "vehicle_ownership_changed", "Vehicle is no longer in this organization");
      const [created] = await tx.insert(workOrders).values({ id: body.id, orgId: id, vehicleId: incident.vehicleId,
        reportedBy: actor, currency, odometerKm: body.odometer_km, issueType: body.issue_type,
        urgency: body.urgency, description: body.description }).onConflictDoNothing().returning({ id: workOrders.id });
      if (!created) throw new AppError(409, "work_order_id_conflict", "Work order ID is already in use");
      await tx.insert(fleetIncidentWorkOrders).values({ incidentId, workOrderId: created.id, orgId: id, vehicleId: incident.vehicleId });
      await audit(tx, actor, id, incidentId, "fleet_incident_repair_created", { workOrderId: created.id });
      return { workOrderId: created.id };
    });
    return reply.code(201).send(repair);
  });
};
