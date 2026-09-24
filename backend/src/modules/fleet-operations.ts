import { and, desc, eq, inArray, sql } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import {
  driverAssignments,
  expenses,
  fuelLogs,
  fuelTypes,
  inspectionTemplates,
  inspections,
  organizationMembers,
  organizationVehicles,
  organizationWorkshops,
  organizations,
  partners,
  planItems,
  serviceRecordItems,
  serviceRecords,
  shiftMileage,
  transferredVehicles,
  users,
  vehicleWarranties,
  vehicleImportJobs,
  vehicles,
  warrantyTemplateWorkshops,
  warrantyTemplates,
  workshopMembers,
  workOrders,
} from "../db/schema.js";
import { newId } from "../lib/crypto.js";
import { dateOnly, iso, num, recordChange, reqNum } from "../lib/dbx.js";
import { AppError } from "../lib/errors.js";
import { requireFleetClient, requireWorkshopClient } from "./auth.js";
import { getOrganizationAccess } from "./fleet.js";

const uuid = z.string().uuid();
const inspectionResult = z.enum(["ok", "not_ok"]);

function serializeInspectionTemplate(row: typeof inspectionTemplates.$inferSelect) {
  return { id: row.id, org_id: row.orgId, name: row.name, items: row.items, created_at: iso(row.createdAt), updated_at: iso(row.updatedAt) };
}

function serializeInspection(row: typeof inspections.$inferSelect) {
  return {
    id: row.id,
    org_id: row.orgId,
    vehicle_id: row.vehicleId,
    driver_id: row.driverId,
    template_id: row.templateId,
    inspection_type: row.inspectionType,
    started_at: iso(row.startedAt),
    completed_at: iso(row.completedAt),
    status: row.status,
    items: row.items,
    notes: row.notes,
    created_at: iso(row.createdAt),
  };
}

function serializeShift(row: typeof shiftMileage.$inferSelect) {
  return {
    id: row.id,
    org_id: row.orgId,
    vehicle_id: row.vehicleId,
    driver_id: row.driverId,
    start_odometer_km: row.startOdometerKm,
    end_odometer_km: row.endOdometerKm,
    start_at: iso(row.startAt),
    end_at: iso(row.endAt),
    km_driven: row.kmDriven,
    created_at: iso(row.createdAt),
  };
}

function serializeWarrantyTemplate(row: typeof warrantyTemplates.$inferSelect, workshops: string[] = []) {
  return {
    id: row.id,
    org_id: row.orgId,
    name: row.name,
    duration_years: row.durationYears,
    mileage_limit_km: row.mileageLimitKm,
    coverage_categories: row.coverageCategories,
    exclusions: row.exclusions,
    approved_workshop_ids: workshops,
    created_at: iso(row.createdAt),
    updated_at: iso(row.updatedAt),
  };
}

function serializeWarranty(row: typeof vehicleWarranties.$inferSelect, currentMileage: number) {
  const expiredByDate = (dateOnly(row.warrantyEndDate) ?? "9999-12-31") < new Date().toISOString().slice(0, 10);
  const expiredByMileage = currentMileage > row.warrantyEndMileage;
  const status = row.status === "active" && (expiredByDate || expiredByMileage) ? "expired" : row.status;
  return {
    id: row.id,
    vehicle_id: row.vehicleId,
    template_id: row.templateId,
    sale_date: dateOnly(row.saleDate),
    sale_mileage_km: row.saleMileageKm,
    warranty_end_date: dateOnly(row.warrantyEndDate),
    warranty_end_mileage: row.warrantyEndMileage,
    status,
    expired_by: status === "expired" ? (expiredByDate ? "time" : "mileage") : null,
  };
}

function parseCsv(input: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let quoted = false;
  for (let i = 0; i < input.length; i += 1) {
    const character = input[i]!;
    if (character === '"') {
      if (quoted && input[i + 1] === '"') {
        cell += '"';
        i += 1;
      } else {
        quoted = !quoted;
      }
    } else if (character === "," && !quoted) {
      row.push(cell.trim());
      cell = "";
    } else if ((character === "\n" || character === "\r") && !quoted) {
      if (character === "\r" && input[i + 1] === "\n") i += 1;
      row.push(cell.trim());
      cell = "";
      if (row.some((part) => part.length > 0)) rows.push(row);
      row = [];
    } else {
      cell += character;
    }
  }
  if (quoted) throw new AppError(400, "invalid_csv", "CSV contains an unterminated quoted field");
  row.push(cell.trim());
  if (row.some((part) => part.length > 0)) rows.push(row);
  return rows;
}

function daysLater(dateText: string, years: number): string {
  const date = new Date(`${dateText}T00:00:00.000Z`);
  date.setUTCFullYear(date.getUTCFullYear() + years);
  return date.toISOString().slice(0, 10);
}

async function activeAssignedVehicle(db: Db, orgId: string, userId: string, vehicleId: string) {
  const [assignment] = await db.select().from(driverAssignments).where(and(
    eq(driverAssignments.orgId, orgId),
    eq(driverAssignments.driverId, userId),
    eq(driverAssignments.vehicleId, vehicleId),
    eq(driverAssignments.status, "active"),
  )).limit(1);
  if (!assignment) throw new AppError(403, "not_assigned_to_vehicle", "Driver is not assigned to this vehicle");
  return assignment;
}

async function listWorkshopWarrantyVehicles(db: Db, userId: string) {
  const memberships = await db.select({ member: workshopMembers, partner: partners })
    .from(workshopMembers)
    .innerJoin(partners, eq(workshopMembers.partnerId, partners.id))
    .where(and(eq(workshopMembers.userId, userId), eq(partners.type, "workshop"), eq(partners.status, "verified")));
  const result: Array<{
    orgId: string;
    organizationName: string;
    partnerId: string;
    partnerName: string;
    vehicle: typeof vehicles.$inferSelect;
    warranty: typeof vehicleWarranties.$inferSelect;
  }> = [];
  const today = new Date().toISOString().slice(0, 10);
  for (const membership of memberships) {
    const organizationsForWorkshop = await db.select({ link: organizationWorkshops, org: organizations })
      .from(organizationWorkshops)
      .innerJoin(organizations, eq(organizationWorkshops.orgId, organizations.id))
      .where(and(
        eq(organizationWorkshops.partnerId, membership.partner.id),
        eq(organizations.plan, "enterprise"),
        eq(organizations.status, "active"),
      ));
    for (const { org, link } of organizationsForWorkshop) {
      const templates = await db.select({ template: warrantyTemplates })
        .from(warrantyTemplateWorkshops)
        .innerJoin(warrantyTemplates, eq(warrantyTemplateWorkshops.templateId, warrantyTemplates.id))
        .where(and(eq(warrantyTemplateWorkshops.partnerId, link.partnerId), eq(warrantyTemplates.orgId, org.id)));
      for (const { template } of templates) {
        const warranties = await db.select().from(vehicleWarranties).where(and(
          eq(vehicleWarranties.templateId, template.id), eq(vehicleWarranties.status, "active"),
        ));
        for (const warranty of warranties) {
          const [vehicle] = await db.select().from(vehicles).where(eq(vehicles.id, warranty.vehicleId)).limit(1);
          if (!vehicle || vehicle.archived) continue;
          const currentLinks = await db.select().from(organizationVehicles).where(and(
            eq(organizationVehicles.orgId, org.id), eq(organizationVehicles.vehicleId, vehicle.id),
          )).limit(1);
          const [transfer] = await db.select().from(transferredVehicles).where(and(
            eq(transferredVehicles.orgId, org.id), eq(transferredVehicles.vehicleId, vehicle.id),
            eq(transferredVehicles.warrantyInstanceId, warranty.id),
          )).limit(1);
          if (!currentLinks.length && !transfer) continue;
          const expiredByDate = (dateOnly(warranty.warrantyEndDate) ?? "0000-01-01") < today;
          const expiredByMileage = Math.floor(reqNum(vehicle.mileage)) > warranty.warrantyEndMileage;
          if (expiredByDate || expiredByMileage) {
            await db.update(vehicleWarranties).set({ status: "expired" }).where(eq(vehicleWarranties.id, warranty.id));
            continue;
          }
          result.push({
            orgId: org.id,
            organizationName: org.name,
            partnerId: membership.partner.id,
            partnerName: membership.partner.name,
            vehicle,
            warranty,
          });
        }
      }
    }
  }
  return result;
}

export const fleetOperationsPlugin: FastifyPluginAsync = async (app) => {
  const uid = (request: { authUser?: { sub: string } }) => request.authUser!.sub;

  // ── Inspection templates and completion ────────────────────────────
  app.get("/organizations/:id/inspection-templates", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId);
    const rows = await app.db.select().from(inspectionTemplates).where(eq(inspectionTemplates.orgId, orgId));
    return { items: rows.map(serializeInspectionTemplate) };
  });

  app.post("/organizations/:id/inspection-templates", async (request, reply) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin"]);
    const body = z.object({
      name: z.string().min(1).max(100),
      items: z.array(z.object({ item_name: z.string().min(1).max(100), required: z.boolean().default(true) })).min(1).max(100),
    }).parse(request.body);
    const [row] = await app.db.insert(inspectionTemplates).values({ id: newId(), orgId, name: body.name, items: body.items }).returning();
    return reply.code(201).send(serializeInspectionTemplate(row));
  });

  app.patch("/organizations/:id/inspection-templates/:templateId", async (request) => {
    requireFleetClient(request);
    const { id: rawOrgId, templateId } = request.params as { id: string; templateId: string };
    const orgId = uuid.parse(rawOrgId);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin"]);
    const body = z.object({
      name: z.string().min(1).max(100).optional(),
      items: z.array(z.object({ item_name: z.string().min(1).max(100), required: z.boolean().default(true) })).min(1).max(100).optional(),
    }).parse(request.body ?? {});
    const [current] = await app.db.select().from(inspectionTemplates).where(and(
      eq(inspectionTemplates.id, templateId), eq(inspectionTemplates.orgId, orgId),
    )).limit(1);
    if (!current) throw new AppError(404, "inspection_template_not_found", "Inspection template not found");
    const [updated] = await app.db.update(inspectionTemplates).set({
      ...(body.name !== undefined ? { name: body.name } : {}),
      ...(body.items !== undefined ? { items: body.items } : {}),
      updatedAt: new Date(),
    }).where(eq(inspectionTemplates.id, templateId)).returning();
    return serializeInspectionTemplate(updated);
  });

  app.delete("/organizations/:id/inspection-templates/:templateId", async (request, reply) => {
    requireFleetClient(request);
    const { id: rawOrgId, templateId } = request.params as { id: string; templateId: string };
    const orgId = uuid.parse(rawOrgId);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin"]);
    const [row] = await app.db.select().from(inspectionTemplates).where(and(
      eq(inspectionTemplates.id, templateId), eq(inspectionTemplates.orgId, orgId),
    )).limit(1);
    if (!row) throw new AppError(404, "inspection_template_not_found", "Inspection template not found");
    const [used] = await app.db.select().from(inspections).where(eq(inspections.templateId, templateId)).limit(1);
    if (used) throw new AppError(409, "inspection_template_in_use", "Template has inspection history and cannot be deleted");
    await app.db.delete(inspectionTemplates).where(eq(inspectionTemplates.id, templateId));
    return reply.code(204).send();
  });

  app.post("/organizations/:id/inspections", async (request, reply) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const actorId = uid(request);
    const { membership } = await getOrganizationAccess(app.db, actorId, orgId);
    const body = z.object({
      vehicle_id: uuid,
      template_id: uuid,
      inspection_type: z.enum(["pre_trip", "post_trip", "random"]),
      driver_id: uuid.optional(),
    }).parse(request.body);
    const driverId = membership.role === "org_driver" ? actorId : body.driver_id;
    if (!driverId) throw new AppError(422, "driver_required", "A driver must be assigned for the inspection");
    if (membership.role === "org_driver") await activeAssignedVehicle(app.db, orgId, actorId, body.vehicle_id);
    else if (body.inspection_type !== "random" || !["org_admin", "org_manager"].includes(membership.role)) {
      throw new AppError(403, "insufficient_org_role", "Only an assigned driver can start this inspection");
    }
    const [assignment] = await app.db.select().from(driverAssignments).where(and(
      eq(driverAssignments.orgId, orgId), eq(driverAssignments.driverId, driverId),
      eq(driverAssignments.vehicleId, body.vehicle_id), eq(driverAssignments.status, "active"),
    )).limit(1);
    if (!assignment) throw new AppError(422, "invalid_assignment", "Driver must have an active assignment to this vehicle");
    const [template] = await app.db.select().from(inspectionTemplates).where(and(
      eq(inspectionTemplates.id, body.template_id), eq(inspectionTemplates.orgId, orgId),
    )).limit(1);
    if (!template) throw new AppError(404, "inspection_template_not_found", "Inspection template not found");
    const [row] = await app.db.insert(inspections).values({
      id: newId(), orgId, vehicleId: body.vehicle_id, driverId, templateId: body.template_id,
      inspectionType: body.inspection_type, status: "in_progress", items: [],
    }).returning();
    return reply.code(201).send(serializeInspection(row));
  });

  app.get("/organizations/:id/inspections", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const { membership } = await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager", "org_driver"]);
    const rows = await app.db.select().from(inspections).where(and(
      eq(inspections.orgId, orgId), ...(membership.role === "org_driver" ? [eq(inspections.driverId, uid(request))] : []),
    ));
    return { items: rows.map(serializeInspection) };
  });

  app.get("/drivers/my-inspections", async (request) => {
    requireFleetClient(request);
    const userId = uid(request);
    const [membership] = await app.db.select().from(organizationMembers).where(and(
      eq(organizationMembers.userId, userId), eq(organizationMembers.role, "org_driver"),
    )).limit(1);
    if (!membership) throw new AppError(403, "driver_mode_required", "An organization driver membership is required");
    await getOrganizationAccess(app.db, userId, membership.orgId, ["org_driver"]);
    const rows = await app.db.select().from(inspections).where(and(
      eq(inspections.orgId, membership.orgId), eq(inspections.driverId, userId),
    ));
    return { items: rows.map(serializeInspection) };
  });

  app.patch("/organizations/:id/inspections/:inspectionId", async (request) => {
    requireFleetClient(request);
    const { id: rawOrgId, inspectionId } = request.params as { id: string; inspectionId: string };
    const orgId = uuid.parse(rawOrgId);
    const actorId = uid(request);
    const body = z.object({
      items: z.array(z.object({
        item_name: z.string().min(1).max(100),
        result: inspectionResult,
        photo_media_id: uuid.optional().nullable(),
        notes: z.string().max(1000).optional().nullable(),
      })),
      notes: z.string().max(1000).optional().nullable(),
    }).parse(request.body);
    const [inspection] = await app.db.select().from(inspections).where(and(
      eq(inspections.id, inspectionId), eq(inspections.orgId, orgId), eq(inspections.driverId, actorId),
      eq(inspections.status, "in_progress"),
    )).limit(1);
    if (!inspection) throw new AppError(404, "inspection_not_found", "In-progress inspection not found");
    await activeAssignedVehicle(app.db, orgId, actorId, inspection.vehicleId);
    const [template] = await app.db.select().from(inspectionTemplates).where(eq(inspectionTemplates.id, inspection.templateId)).limit(1);
    if (!template) throw new AppError(404, "inspection_template_not_found", "Inspection template not found");
    const definitions = template.items as Array<{ item_name: string; required: boolean }>;
    const itemNames = new Set(definitions.map((item) => item.item_name));
    if (body.items.some((item) => !itemNames.has(item.item_name))) {
      throw new AppError(422, "invalid_inspection_item", "Inspection includes an item that is not in the template");
    }
    const submitted = new Map(body.items.map((item) => [item.item_name, item]));
    const missing = definitions.filter((definition) => definition.required && !submitted.has(definition.item_name));
    if (missing.length) throw new AppError(400, "inspection_incomplete", "All required checklist items need a result", { missing: missing.map((item) => item.item_name) });
    const finalItems = definitions.flatMap((definition) => {
      const item = submitted.get(definition.item_name);
      return item ? [{ ...item, required: definition.required }] : [];
    });
    const failedItems = finalItems.filter((item) => item.result === "not_ok");
    const status = failedItems.length ? "failed" : "completed";
    const [updated] = await app.db.update(inspections).set({
      items: finalItems,
      notes: body.notes ?? null,
      status,
      completedAt: new Date(),
    }).where(eq(inspections.id, inspection.id)).returning();
    if (failedItems.length) {
      const [vehicle] = await app.db.select().from(vehicles).where(eq(vehicles.id, inspection.vehicleId)).limit(1);
      const detail = failedItems.map((item) => item.item_name).join(", ");
      await app.db.insert(workOrders).values({
        id: newId(), orgId, vehicleId: inspection.vehicleId, reportedBy: actorId,
        odometerKm: Math.max(0, Math.floor(reqNum(vehicle?.mileage))), issueType: "other",
        description: `Inspection failure: ${detail}`.slice(0, 2000), urgency: "medium",
      });
    }
    return serializeInspection(updated);
  });

  // ── Shift mileage ──────────────────────────────────────────────────
  app.post("/organizations/:id/shift-mileage", async (request, reply) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_driver"]);
    const body = z.object({ vehicle_id: uuid, start_odometer_km: z.number().int().min(0) }).parse(request.body);
    await activeAssignedVehicle(app.db, orgId, actorId, body.vehicle_id);
    const [vehicle] = await app.db.select().from(vehicles).where(eq(vehicles.id, body.vehicle_id)).limit(1);
    if (!vehicle) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found");
    const previous = await app.db.select().from(shiftMileage).where(and(
      eq(shiftMileage.orgId, orgId), eq(shiftMileage.vehicleId, body.vehicle_id),
    )).orderBy(desc(shiftMileage.startAt));
    const previousEnd = previous.find((row) => row.endOdometerKm !== null)?.endOdometerKm ?? null;
    const minimum = Math.max(previousEnd ?? 0, Math.floor(reqNum(vehicle.mileage)));
    if (body.start_odometer_km < minimum) throw new AppError(400, "odometer_regression", "Start odometer is below the latest vehicle reading");
    const [row] = await app.db.insert(shiftMileage).values({
      id: newId(), orgId, vehicleId: body.vehicle_id, driverId: actorId, startOdometerKm: body.start_odometer_km,
    }).returning();
    return reply.code(201).send(serializeShift(row));
  });

  app.patch("/organizations/:id/shift-mileage/:shiftId", async (request) => {
    requireFleetClient(request);
    const { id: rawOrgId, shiftId } = request.params as { id: string; shiftId: string };
    const orgId = uuid.parse(rawOrgId);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_driver"]);
    const body = z.object({ end_odometer_km: z.number().int().min(0) }).parse(request.body);
    const [row] = await app.db.select().from(shiftMileage).where(and(
      eq(shiftMileage.id, shiftId), eq(shiftMileage.orgId, orgId), eq(shiftMileage.driverId, actorId), sql`${shiftMileage.endAt} IS NULL`,
    )).limit(1);
    if (!row) throw new AppError(404, "active_shift_not_found", "Active shift not found");
    await activeAssignedVehicle(app.db, orgId, actorId, row.vehicleId);
    if (body.end_odometer_km < row.startOdometerKm) throw new AppError(400, "invalid_odometer_range", "End odometer must be at least the start odometer");
    const endedAt = new Date();
    const [updated] = await app.db.update(shiftMileage).set({
      endOdometerKm: body.end_odometer_km,
      endAt: endedAt,
      kmDriven: body.end_odometer_km - row.startOdometerKm,
    }).where(eq(shiftMileage.id, row.id)).returning();
    await app.db.update(vehicles).set({ mileage: String(body.end_odometer_km), updatedAt: endedAt }).where(eq(vehicles.id, row.vehicleId));
    return serializeShift(updated);
  });

  app.get("/organizations/:id/shift-mileage", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const { membership } = await getOrganizationAccess(app.db, uid(request), orgId);
    const rows = await app.db.select().from(shiftMileage).where(and(
      eq(shiftMileage.orgId, orgId), ...(membership.role === "org_driver" ? [eq(shiftMileage.driverId, uid(request))] : []),
    )).orderBy(desc(shiftMileage.startAt));
    return { items: rows.map(serializeShift) };
  });

  app.post("/organizations/:id/fuel-logs", async (request, reply) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const actorId = uid(request);
    const { organization } = await getOrganizationAccess(app.db, actorId, orgId, ["org_driver"]);
    const body = z.object({
      vehicle_id: uuid,
      fuel_type_id: uuid,
      logged_on: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      amount: z.number().positive(),
      cost: z.number().min(0),
      odometer_km: z.number().int().min(0),
    }).parse(request.body);
    await activeAssignedVehicle(app.db, orgId, actorId, body.vehicle_id);
    const [link] = await app.db.select().from(organizationVehicles).where(and(
      eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, body.vehicle_id),
    )).limit(1);
    const [vehicle] = await app.db.select().from(vehicles).where(eq(vehicles.id, body.vehicle_id)).limit(1);
    const [fuelType] = await app.db.select().from(fuelTypes).where(and(eq(fuelTypes.id, body.fuel_type_id), eq(fuelTypes.userId, actorId))).limit(1);
    if (!link || !vehicle) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
    if (!fuelType) throw new AppError(422, "invalid_fuel_type", "Fuel type does not belong to this driver");
    if (body.odometer_km < Math.floor(reqNum(vehicle.mileage))) throw new AppError(400, "odometer_regression", "Fuel odometer cannot be below current vehicle mileage");
    const kind = vehicle.fuelType === "electric" ? "charge" : "refuel";
    if ((kind === "charge" && fuelType.kind !== "electric") || (kind === "refuel" && fuelType.kind !== "liquid")) {
      throw new AppError(422, "invalid_fuel_type", "Fuel type does not match the vehicle powertrain");
    }
    const [row] = await app.db.transaction(async (tx) => {
      const [log] = await tx.insert(fuelLogs).values({
        id: newId(), userId: actorId, vehicleId: body.vehicle_id, kind, fuelTypeId: fuelType.id,
        fuelTypeName: fuelType.name, unit: fuelType.unit, loggedOn: body.logged_on,
        amount: String(body.amount), cost: String(body.cost),
      }).returning();
      await tx.update(vehicles).set({ mileage: String(body.odometer_km), updatedAt: new Date() }).where(eq(vehicles.id, body.vehicle_id));
      return [log];
    });
    const payload = {
      id: row.id,
      user_id: row.userId,
      vehicle_id: row.vehicleId,
      kind: row.kind,
      fuel_type_id: row.fuelTypeId,
      fuel_type_name: row.fuelTypeName,
      unit: row.unit,
      logged_on: dateOnly(row.loggedOn),
      amount: reqNum(row.amount),
      cost: reqNum(row.cost),
      odometer_km: body.odometer_km,
    };
    await recordChange(app.db, { userId: actorId, entityType: "fuel_log", entityId: row.id, op: "upsert", payload });
    if (organization.adminUserId !== actorId) await recordChange(app.db, { userId: organization.adminUserId, entityType: "fuel_log", entityId: row.id, op: "upsert", payload });
    return reply.code(201).send(payload);
  });

  // ── Warranty templates and vehicle warranties ──────────────────────
  app.get("/organizations/:id/warranty-templates", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId);
    const rows = await app.db.select().from(warrantyTemplates).where(eq(warrantyTemplates.orgId, orgId));
    const items = [];
    for (const row of rows) {
      const links = await app.db.select().from(warrantyTemplateWorkshops).where(eq(warrantyTemplateWorkshops.templateId, row.id));
      items.push(serializeWarrantyTemplate(row, links.map((link) => link.partnerId)));
    }
    return { items };
  });

  app.post("/organizations/:id/warranty-templates", async (request, reply) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin"]);
    const body = z.object({
      name: z.string().min(1).max(100),
      duration_years: z.number().int().min(1).max(10),
      mileage_limit_km: z.number().int().min(1000).max(500000),
      coverage_categories: z.array(z.string().min(1).max(100)).default([]),
      exclusions: z.string().max(1000).optional().nullable(),
      approved_workshop_ids: z.array(uuid).default([]),
    }).parse(request.body);
    for (const partnerId of body.approved_workshop_ids) {
      const [partner] = await app.db.select().from(partners).where(eq(partners.id, partnerId)).limit(1);
      if (!partner || partner.type !== "workshop") throw new AppError(422, "invalid_workshop", "Approved workshop must be a workshop partner");
      const [approved] = await app.db.select().from(organizationWorkshops).where(and(
        eq(organizationWorkshops.orgId, orgId), eq(organizationWorkshops.partnerId, partnerId),
      )).limit(1);
      if (!approved) throw new AppError(422, "workshop_not_approved", "Workshop must be approved by the organization first");
    }
    const created = await app.db.transaction(async (tx) => {
      const [row] = await tx.insert(warrantyTemplates).values({
        id: newId(), orgId, name: body.name, durationYears: body.duration_years, mileageLimitKm: body.mileage_limit_km,
        coverageCategories: body.coverage_categories, exclusions: body.exclusions ?? null,
      }).returning();
      for (const partnerId of body.approved_workshop_ids) {
        await tx.insert(warrantyTemplateWorkshops).values({ id: newId(), templateId: row.id, partnerId });
      }
      return row;
    });
    return reply.code(201).send(serializeWarrantyTemplate(created, body.approved_workshop_ids));
  });

  app.patch("/organizations/:id/warranty-templates/:templateId", async (request) => {
    requireFleetClient(request);
    const { id: rawOrgId, templateId } = request.params as { id: string; templateId: string };
    const orgId = uuid.parse(rawOrgId);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin"]);
    const body = z.object({
      name: z.string().min(1).max(100).optional(),
      duration_years: z.number().int().min(1).max(10).optional(),
      mileage_limit_km: z.number().int().min(1000).max(500000).optional(),
      coverage_categories: z.array(z.string().min(1).max(100)).optional(),
      exclusions: z.string().max(1000).nullable().optional(),
      approved_workshop_ids: z.array(uuid).optional(),
    }).parse(request.body ?? {});
    const [current] = await app.db.select().from(warrantyTemplates).where(and(
      eq(warrantyTemplates.id, templateId), eq(warrantyTemplates.orgId, orgId),
    )).limit(1);
    if (!current) throw new AppError(404, "warranty_template_not_found", "Warranty template not found");
    if (body.approved_workshop_ids) {
      for (const partnerId of body.approved_workshop_ids) {
        const [partner] = await app.db.select().from(partners).where(eq(partners.id, partnerId)).limit(1);
        if (!partner || partner.type !== "workshop") throw new AppError(422, "invalid_workshop", "Approved workshop must be a workshop partner");
        const [approved] = await app.db.select().from(organizationWorkshops).where(and(
          eq(organizationWorkshops.orgId, orgId), eq(organizationWorkshops.partnerId, partnerId),
        )).limit(1);
        if (!approved) throw new AppError(422, "workshop_not_approved", "Workshop must be approved by the organization first");
      }
    }
    const updated = await app.db.transaction(async (tx) => {
      const [row] = await tx.update(warrantyTemplates).set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.duration_years !== undefined ? { durationYears: body.duration_years } : {}),
        ...(body.mileage_limit_km !== undefined ? { mileageLimitKm: body.mileage_limit_km } : {}),
        ...(body.coverage_categories !== undefined ? { coverageCategories: body.coverage_categories } : {}),
        ...(body.exclusions !== undefined ? { exclusions: body.exclusions } : {}),
        updatedAt: new Date(),
      }).where(eq(warrantyTemplates.id, templateId)).returning();
      if (body.approved_workshop_ids) {
        await tx.delete(warrantyTemplateWorkshops).where(eq(warrantyTemplateWorkshops.templateId, templateId));
        for (const partnerId of body.approved_workshop_ids) {
          await tx.insert(warrantyTemplateWorkshops).values({ id: newId(), templateId, partnerId });
        }
      }
      return row;
    });
    const workshops = body.approved_workshop_ids ?? (await app.db.select().from(warrantyTemplateWorkshops).where(eq(warrantyTemplateWorkshops.templateId, templateId))).map((row) => row.partnerId);
    return serializeWarrantyTemplate(updated, workshops);
  });

  app.delete("/organizations/:id/warranty-templates/:templateId", async (request, reply) => {
    requireFleetClient(request);
    const { id: rawOrgId, templateId } = request.params as { id: string; templateId: string };
    const orgId = uuid.parse(rawOrgId);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin"]);
    const [used] = await app.db.select().from(vehicleWarranties).where(eq(vehicleWarranties.templateId, templateId)).limit(1);
    if (used) throw new AppError(409, "warranty_template_in_use", "Template is used by an active or historical warranty");
    const [row] = await app.db.delete(warrantyTemplates).where(and(
      eq(warrantyTemplates.id, templateId), eq(warrantyTemplates.orgId, orgId),
    )).returning();
    if (!row) throw new AppError(404, "warranty_template_not_found", "Warranty template not found");
    return reply.code(204).send();
  });

  app.get("/organizations/:id/vehicle-warranties", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId);
  const orgVehicles = await app.db.select({ vehicle: vehicles, link: organizationVehicles })
      .from(organizationVehicles).innerJoin(vehicles, eq(organizationVehicles.vehicleId, vehicles.id))
      .where(eq(organizationVehicles.orgId, orgId));
    const vehicleIds = orgVehicles.map((row) => row.vehicle.id);
    if (!vehicleIds.length) return { items: [] };
    const warranties = await app.db.select({ warranty: vehicleWarranties, vehicle: vehicles })
      .from(vehicleWarranties).innerJoin(vehicles, eq(vehicleWarranties.vehicleId, vehicles.id))
      .where(inArray(vehicleWarranties.vehicleId, vehicleIds));
    return { items: warranties.map((row) => ({
      ...serializeWarranty(row.warranty, Math.floor(reqNum(row.vehicle.mileage))),
      current_mileage_km: Math.floor(reqNum(row.vehicle.mileage)),
    })) };
  });

  // ── Dealer transfer / read-only history ────────────────────────────
  app.post("/organizations/:id/vehicles/:vehicleId/transfer", async (request, reply) => {
    requireFleetClient(request);
    const { id: rawOrgId, vehicleId } = request.params as { id: string; vehicleId: string };
    const orgId = uuid.parse(rawOrgId);
    const actorId = uid(request);
    const { organization } = await getOrganizationAccess(app.db, actorId, orgId, ["org_admin"]);
    const body = z.object({
      buyer_email: z.string().email().max(254),
      sale_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      current_mileage_km: z.number().int().min(0),
      warranty_template_id: uuid.optional().nullable(),
    }).parse(request.body);
    if (body.sale_date > new Date().toISOString().slice(0, 10)) throw new AppError(422, "invalid_sale_date", "Sale date cannot be in the future");
    const [buyer] = await app.db.select().from(users).where(eq(users.email, body.buyer_email.toLowerCase())).limit(1);
    if (!buyer || buyer.role !== "owner" || buyer.status !== "active") throw new AppError(404, "buyer_not_found", "Buyer must have an active DCO account before transfer");
    const [link] = await app.db.select().from(organizationVehicles).where(and(
      eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, vehicleId),
    )).limit(1);
    if (!link) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
    if (link.lifecycleTemplate !== "showroom" || link.status !== "reserved") {
      throw new AppError(409, "vehicle_not_ready_for_transfer", "Vehicle must be reserved in the showroom lifecycle before transfer");
    }
    const [vehicle] = await app.db.select().from(vehicles).where(eq(vehicles.id, vehicleId)).limit(1);
    if (!vehicle || body.current_mileage_km < Math.floor(reqNum(vehicle.mileage))) {
      throw new AppError(422, "invalid_odometer", "Sale mileage cannot be below the last recorded mileage");
    }
    let template: typeof warrantyTemplates.$inferSelect | null = null;
    if (body.warranty_template_id) {
      const [found] = await app.db.select().from(warrantyTemplates).where(and(
        eq(warrantyTemplates.id, body.warranty_template_id), eq(warrantyTemplates.orgId, orgId),
      )).limit(1);
      if (!found) throw new AppError(404, "warranty_template_not_found", "Warranty template not found in this organization");
      template = found;
    }
    const transfer = await app.db.transaction(async (tx) => {
      let warrantyId: string | null = null;
      if (template) {
        warrantyId = newId();
        await tx.insert(vehicleWarranties).values({
          id: warrantyId, vehicleId, templateId: template.id, saleDate: body.sale_date,
          saleMileageKm: body.current_mileage_km,
          warrantyEndDate: daysLater(body.sale_date, template.durationYears),
          warrantyEndMileage: body.current_mileage_km + template.mileageLimitKm,
          status: "active",
        });
      }
      const [updatedVehicle] = await tx.update(vehicles).set({
        userId: buyer.id,
        mileage: String(body.current_mileage_km),
        mileageUnit: "km",
        updatedAt: new Date(),
      }).where(eq(vehicles.id, vehicleId)).returning();
      const [auditRow] = await tx.insert(transferredVehicles).values({
        id: newId(), vehicleId, orgId, buyerUserId: buyer.id, transferredBy: actorId,
        warrantyInstanceId: warrantyId,
      }).returning();
      await tx.delete(organizationVehicles).where(eq(organizationVehicles.id, link.id));
      return { vehicle: updatedVehicle, audit: auditRow, warrantyId };
    });
    await recordChange(app.db, { userId: buyer.id, entityType: "vehicle", entityId: vehicleId, op: "upsert", payload: { id: vehicleId, user_id: buyer.id, mileage: body.current_mileage_km } });
    return reply.code(201).send({
      vehicle_id: transfer.vehicle.id,
      buyer_user_id: buyer.id,
      transferred_at: iso(transfer.audit.transferredAt),
      warranty_instance_id: transfer.warrantyId,
      status: "sold",
    });
  });

  app.get("/organizations/:id/transferred", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
    const rows = await app.db.select({ transfer: transferredVehicles, vehicle: vehicles })
      .from(transferredVehicles).innerJoin(vehicles, eq(transferredVehicles.vehicleId, vehicles.id))
      .where(eq(transferredVehicles.orgId, orgId)).orderBy(desc(transferredVehicles.transferredAt));
    return { items: rows.map((row) => ({
      id: row.transfer.id,
      vehicle: { id: row.vehicle.id, name: row.vehicle.name, make: row.vehicle.make, model: row.vehicle.model, year: row.vehicle.year, plate: row.vehicle.licensePlate },
      buyer_user_id: row.transfer.buyerUserId,
      transferred_by: row.transfer.transferredBy,
      transferred_at: iso(row.transfer.transferredAt),
      warranty_instance_id: row.transfer.warrantyInstanceId,
    })) };
  });

  app.get("/organizations/:id/transferred/:vehicleId/history", async (request) => {
    requireFleetClient(request);
    const { id: rawOrgId, vehicleId } = request.params as { id: string; vehicleId: string };
    const orgId = uuid.parse(rawOrgId);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
    const [transfer] = await app.db.select().from(transferredVehicles).where(and(
      eq(transferredVehicles.orgId, orgId), eq(transferredVehicles.vehicleId, vehicleId),
    )).limit(1);
    if (!transfer) throw new AppError(404, "transferred_vehicle_not_found", "Transferred vehicle was not found");
    const services = await app.db.select().from(serviceRecords).where(eq(serviceRecords.vehicleId, vehicleId)).orderBy(desc(serviceRecords.servicedOn));
    const warranty = transfer.warrantyInstanceId
      ? (await app.db.select().from(vehicleWarranties).where(eq(vehicleWarranties.id, transfer.warrantyInstanceId)).limit(1))[0] ?? null
      : null;
    return {
      vehicle_id: vehicleId,
      transferred_at: iso(transfer.transferredAt),
      service_records: services.map((row) => ({ id: row.id, serviced_on: dateOnly(row.servicedOn), odometer: reqNum(row.odometer), total_cost: reqNum(row.totalCost), workshop_name: row.workshopName, notes: row.notes })),
      warranty: warranty ? serializeWarranty(warranty, 0) : null,
    };
  });

  // ── Fleet analytics ─────────────────────────────────────────────────
  app.get("/organizations/:id/analytics/vehicle/:vehicleId", async (request) => {
    requireFleetClient(request);
    const { id: rawOrgId, vehicleId } = request.params as { id: string; vehicleId: string };
    const orgId = uuid.parse(rawOrgId);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
    const [link] = await app.db.select().from(organizationVehicles).where(and(
      eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, vehicleId),
    )).limit(1);
    if (!link) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
    return calculateVehicleCost(app.db, vehicleId);
  });

  app.get("/organizations/:id/analytics/fleet", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const { organization } = await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
    const links = await app.db.select().from(organizationVehicles).where(eq(organizationVehicles.orgId, orgId));
    const vehiclesReport = [];
    for (const link of links) vehiclesReport.push(await calculateVehicleCost(app.db, link.vehicleId));
    const totalSpend = vehiclesReport.reduce((sum, row) => sum + row.tco, 0);
    const totalKm = vehiclesReport.reduce((sum, row) => sum + row.total_km_driven, 0);
    const average = totalKm > 0 ? totalSpend / totalKm : 0;
    const threshold = thresholdFor(organization.settings, average);
    const openOrders = await app.db.select().from(workOrders).where(and(
      eq(workOrders.orgId, orgId), inArray(workOrders.status, ["reported", "in_progress"]),
    ));
    const assignments = await app.db.select().from(driverAssignments).where(and(eq(driverAssignments.orgId, orgId), eq(driverAssignments.status, "active")));
    const vehicleRows = links.length
      ? await app.db.select().from(vehicles).where(inArray(vehicles.id, links.map((row) => row.vehicleId)))
      : [];
    const vehicleById = new Map(vehicleRows.map((row) => [row.id, row]));
    const maintenancePlans = links.length
      ? await app.db.select().from(planItems).where(and(inArray(planItems.vehicleId, links.map((row) => row.vehicleId)), eq(planItems.enabled, true)))
      : [];
    const soon = new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10);
    const upcomingVehicleIds = new Set<string>();
    for (const plan of maintenancePlans) {
      const dueDate = dateOnly(plan.nextDueOn);
      const vehicle = vehicleById.get(plan.vehicleId);
      const dueMileage = num(plan.nextDueMileage);
      if ((dueDate !== null && dueDate <= soon) || (vehicle && dueMileage !== null && dueMileage - reqNum(vehicle.mileage) <= 500)) {
        upcomingVehicleIds.add(plan.vehicleId);
      }
    }
    return {
      vehicle_count: links.length,
      total_fleet_spend: totalSpend,
      average_cost_per_km: average,
      lemon_count: vehiclesReport.filter((row) => row.cost_per_km > threshold && row.total_km_driven > 0).length,
      open_work_orders: openOrders.length,
      active_assignments: assignments.length,
      upcoming_maintenance_count: upcomingVehicleIds.size,
      vehicles: vehiclesReport,
    };
  });

  app.get("/organizations/:id/analytics/lemons", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const { organization } = await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
    const links = await app.db.select({ link: organizationVehicles, vehicle: vehicles })
      .from(organizationVehicles).innerJoin(vehicles, eq(organizationVehicles.vehicleId, vehicles.id))
      .where(eq(organizationVehicles.orgId, orgId));
    const metrics = [];
    for (const row of links) metrics.push({ vehicle: row.vehicle, metric: await calculateVehicleCost(app.db, row.vehicle.id) });
    const totalSpend = metrics.reduce((sum, row) => sum + row.metric.tco, 0);
    const totalKm = metrics.reduce((sum, row) => sum + row.metric.total_km_driven, 0);
    const average = totalKm > 0 ? totalSpend / totalKm : 0;
    const threshold = thresholdFor(organization.settings, average);
    return { threshold_cost_per_km: threshold, items: metrics.filter((row) => row.metric.total_km_driven > 0 && row.metric.cost_per_km > threshold).map((row) => ({ ...row.metric, name: row.vehicle.name, license_plate: row.vehicle.licensePlate })) };
  });

  app.get("/organizations/:id/reports/export", async (request, reply) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
    const query = z.object({ type: z.enum(["vehicles", "fleet", "lemons"]) }).parse(request.query ?? {});
    const escape = (value: unknown) => `"${String(value ?? "").replaceAll('"', '""')}"`;
    let lines: Array<Array<string | number | null>>;
    if (query.type === "vehicles") {
      const rows = await app.db.select({ vehicle: vehicles, link: organizationVehicles })
        .from(organizationVehicles).innerJoin(vehicles, eq(organizationVehicles.vehicleId, vehicles.id))
        .where(eq(organizationVehicles.orgId, orgId));
      lines = [["vehicle_id", "name", "plate", "make", "model", "year", "status", "lifecycle_template", "mileage"]];
      for (const row of rows) lines.push([row.vehicle.id, row.vehicle.name, row.vehicle.licensePlate, row.vehicle.make, row.vehicle.model, row.vehicle.year, row.link.status, row.link.lifecycleTemplate, row.vehicle.mileage]);
    } else {
      const [organization] = await app.db.select().from(organizations).where(eq(organizations.id, orgId)).limit(1);
      const rows = await app.db.select({ vehicle: vehicles, link: organizationVehicles })
        .from(organizationVehicles).innerJoin(vehicles, eq(organizationVehicles.vehicleId, vehicles.id))
        .where(eq(organizationVehicles.orgId, orgId));
      const metrics = [];
      for (const row of rows) metrics.push({ vehicle: row.vehicle, metric: await calculateVehicleCost(app.db, row.vehicle.id) });
      const spend = metrics.reduce((sum, row) => sum + row.metric.tco, 0);
      const km = metrics.reduce((sum, row) => sum + row.metric.total_km_driven, 0);
      const average = km ? spend / km : 0;
      const threshold = thresholdFor(organization?.settings, average);
      const selected = query.type === "lemons"
        ? metrics.filter((row) => row.metric.total_km_driven > 0 && row.metric.cost_per_km > threshold)
        : metrics;
      lines = [["vehicle_id", "name", "plate", "tco", "cost_per_km", "total_km_driven", "maintenance_cost", "fuel_cost", "wear_cost"]];
      for (const row of selected) lines.push([
        row.vehicle.id, row.vehicle.name, row.vehicle.licensePlate, row.metric.tco, row.metric.cost_per_km,
        row.metric.total_km_driven, row.metric.maintenance_cost, row.metric.fuel_cost, row.metric.wear_cost,
      ]);
    }
    const csv = lines.map((line) => line.map(escape).join(",")).join("\r\n");
    return reply
      .header("content-type", "text/csv; charset=utf-8")
      .header("content-disposition", `attachment; filename="fleet-${query.type}.csv"`)
      .send(csv);
  });

  app.post("/organizations/:id/analytics/lemon-threshold", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const { organization } = await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin"]);
    const body = z.object({ multiplier: z.number().min(1).optional(), absolute_cost_per_km: z.number().min(0).optional() })
      .refine((value) => (value.multiplier === undefined) !== (value.absolute_cost_per_km === undefined), "Specify exactly one threshold mode")
      .parse(request.body);
    const settings = (organization.settings ?? {}) as Record<string, unknown>;
    const updatedSettings = body.multiplier !== undefined
      ? { ...settings, lemon_threshold: { mode: "multiplier", value: body.multiplier } }
      : { ...settings, lemon_threshold: { mode: "absolute", value: body.absolute_cost_per_km } };
    const [updated] = await app.db.update(organizations).set({ settings: updatedSettings, updatedAt: new Date() })
      .where(eq(organizations.id, orgId)).returning();
    return { lemon_threshold: updated.settings && (updated.settings as Record<string, unknown>).lemon_threshold };
  });

  // ── CSV inventory import ────────────────────────────────────────────
  app.post("/organizations/:id/vehicles/import", async (request, reply) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const actorId = uid(request);
    const { organization } = await getOrganizationAccess(app.db, actorId, orgId, ["org_admin"]);
    const file = await request.file({ limits: { fileSize: 1024 * 1024 } });
    if (!file) throw new AppError(400, "no_file", "CSV file is required");
    if (!file.filename.toLowerCase().endsWith(".csv")) throw new AppError(400, "invalid_csv", "File must have a .csv extension");
    const chunks: Buffer[] = [];
    for await (const chunk of file.file) chunks.push(chunk);
    const rows = parseCsv(Buffer.concat(chunks).toString("utf8"));
    if (rows.length < 2) throw new AppError(400, "invalid_csv", "CSV must include headers and at least one vehicle row");
    if (rows.length - 1 > 100) throw new AppError(400, "import_limit_exceeded", "Maximum 100 vehicle rows per import");
    const headers = rows[0]!.map((header, index) => (index === 0 ? header.replace(/^\uFEFF/, "") : header).toLowerCase());
    const required = ["name", "make", "model", "year", "plate", "vin", "fuel_type"];
    if (required.some((header) => !headers.includes(header))) throw new AppError(400, "invalid_csv", "CSV is missing required vehicle columns", { required });
    const [job] = await app.db.insert(vehicleImportJobs).values({
      id: newId(), orgId, createdBy: actorId, fileName: file.filename, totalRows: rows.length - 1, status: "processing", results: [],
    }).returning();
    const ownerId = organization.adminUserId;
    const orgType = organization.type;
    setImmediate(() => {
      void processVehicleImport(app.db, job.id, orgId, actorId, ownerId, orgType, rows).catch((error: unknown) => {
        app.log.error(error);
        void app.db.update(vehicleImportJobs).set({
          status: "failed", results: [{ error: "Vehicle import failed" }], completedAt: new Date(),
        }).where(eq(vehicleImportJobs.id, job.id));
      });
    });
    return reply.code(202).send({ job_id: job.id, status: job.status, total_rows: job.totalRows });
  });

  app.get("/organizations/:id/vehicles/import/:jobId", async (request) => {
    requireFleetClient(request);
    const { id: rawOrgId, jobId } = request.params as { id: string; jobId: string };
    const orgId = uuid.parse(rawOrgId);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin"]);
    const [job] = await app.db.select().from(vehicleImportJobs).where(and(
      eq(vehicleImportJobs.id, jobId), eq(vehicleImportJobs.orgId, orgId),
    )).limit(1);
    if (!job) throw new AppError(404, "import_job_not_found", "Vehicle import job not found");
    const results = job.results as Array<{ status?: string }>;
    return {
      job_id: job.id,
      status: job.status,
      total_rows: job.totalRows,
      success_count: results.filter((row) => row.status === "success").length,
      fail_count: results.filter((row) => row.status === "failed").length,
      rows: results,
      created_at: iso(job.createdAt),
      completed_at: iso(job.completedAt),
    };
  });

  // ── External workshop warranty service ──────────────────────────────
  app.get("/workshops/my-vehicles", async (request) => {
    requireWorkshopClient(request);
    const items = await listWorkshopWarrantyVehicles(app.db, uid(request));
    return {
      items: items.map((item) => ({
        organization_id: item.orgId,
        workshop_id: item.partnerId,
        workshop_name: item.partnerName,
        vehicle: {
          id: item.vehicle.id,
          name: item.vehicle.name,
          make: item.vehicle.make,
          model: item.vehicle.model,
          year: item.vehicle.year,
          license_plate: item.vehicle.licensePlate,
          vin: item.vehicle.vin,
          mileage_km: Math.floor(reqNum(item.vehicle.mileage)),
        },
        warranty: serializeWarranty(item.warranty, Math.floor(reqNum(item.vehicle.mileage))),
      })),
    };
  });

  app.post("/workshops/:vehicleId/service", async (request, reply) => {
    requireWorkshopClient(request);
    const vehicleId = uuid.parse((request.params as { vehicleId: string }).vehicleId);
    const userId = uid(request);
    const body = z.object({
      serviced_on: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      odometer_km: z.number().int().min(0),
      total_cost: z.number().min(0),
      notes: z.string().max(2000).optional().nullable(),
      items: z.array(z.object({ name: z.string().min(1).max(100), line_cost: z.number().min(0).optional().nullable() })).min(1),
    }).parse(request.body);
    const accessible = await listWorkshopWarrantyVehicles(app.db, userId);
    const target = accessible.find((item) => item.vehicle.id === vehicleId);
    if (!target) throw new AppError(404, "vehicle_not_assigned", "Vehicle is not under an active approved workshop warranty");
    if (body.serviced_on > new Date().toISOString().slice(0, 10)) throw new AppError(422, "invalid_service_date", "Service date cannot be in the future");
    if (body.odometer_km < Math.floor(reqNum(target.vehicle.mileage))) {
      throw new AppError(400, "odometer_regression", "Service odometer cannot be below the current vehicle mileage");
    }
    const serviceId = newId();
    const record = await app.db.transaction(async (tx) => {
      const [created] = await tx.insert(serviceRecords).values({
        id: serviceId, vehicleId, servicedOn: body.serviced_on, odometer: String(body.odometer_km),
        totalCost: String(body.total_cost), workshopName: target.partnerName, notes: body.notes ?? null,
      }).returning();
      const items = [];
      for (const item of body.items) {
        const [createdItem] = await tx.insert(serviceRecordItems).values({
          id: newId(), serviceRecordId: serviceId, name: item.name,
          lineCost: item.line_cost == null ? null : String(item.line_cost),
        }).returning();
        items.push(createdItem);
      }
      await tx.update(vehicles).set({ mileage: String(body.odometer_km), updatedAt: new Date() }).where(eq(vehicles.id, vehicleId));
      return { created, items };
    });
    const payload = {
      id: record.created.id,
      vehicle_id: vehicleId,
      serviced_on: dateOnly(record.created.servicedOn),
      odometer_km: body.odometer_km,
      total_cost: reqNum(record.created.totalCost),
      workshop_name: target.partnerName,
      notes: record.created.notes,
      items: record.items.map((item) => ({ name: item.name, line_cost: num(item.lineCost) })),
    };
    await recordChange(app.db, { userId, entityType: "service_record", entityId: serviceId, op: "upsert", payload });
    if (target.vehicle.userId !== userId) {
      await recordChange(app.db, { userId: target.vehicle.userId, entityType: "service_record", entityId: serviceId, op: "upsert", payload });
    }
    const reachedWarrantyLimit = body.odometer_km > target.warranty.warrantyEndMileage || body.serviced_on > (dateOnly(target.warranty.warrantyEndDate) ?? "9999-12-31");
    if (reachedWarrantyLimit) await app.db.update(vehicleWarranties).set({ status: "expired" }).where(eq(vehicleWarranties.id, target.warranty.id));
    return reply.code(201).send(payload);
  });
};

async function processVehicleImport(
  db: Db,
  jobId: string,
  orgId: string,
  actorId: string,
  ownerId: string,
  orgType: string,
  rows: string[][],
) {
  const headers = rows[0]!.map((header, index) => (index === 0 ? header.replace(/^\uFEFF/, "") : header).toLowerCase());
  const results: Array<{ row: number; status: "success" | "failed"; vehicle_id?: string; error?: string }> = [];
  for (const [index, values] of rows.slice(1).entries()) {
    const rowNumber = index + 2;
    const record = Object.fromEntries(headers.map((header, column) => [header, values[column] ?? ""])) as Record<string, string>;
    try {
      const data = z.object({
        name: z.string().min(1).max(100), make: z.string().min(1).max(100), model: z.string().min(1).max(100),
        year: z.coerce.number().int().min(1900).max(new Date().getFullYear() + 1),
        plate: z.string().min(1).max(20), vin: z.string().length(17),
        fuel_type: z.enum(["petrol", "electric", "hybrid_plugin"]),
        mileage: z.coerce.number().min(0).default(0), lifecycle_template: z.enum(["showroom", "taxi_fleet", "rental", "commercial"]).optional(),
      }).parse(record);
      const template = data.lifecycle_template ?? templateForOrganization(orgType);
      const [duplicateVin] = await db.select().from(vehicles).where(and(eq(vehicles.vin, data.vin), eq(vehicles.archived, false))).limit(1);
      if (duplicateVin) throw new AppError(409, "duplicate_vin", "VIN already belongs to another vehicle");
      const orgPlateRows = await db.select({ plate: vehicles.licensePlate }).from(organizationVehicles)
        .innerJoin(vehicles, eq(organizationVehicles.vehicleId, vehicles.id)).where(eq(organizationVehicles.orgId, orgId));
      if (orgPlateRows.some((row) => row.plate.toLowerCase() === data.plate.toLowerCase())) {
        throw new AppError(409, "duplicate_plate", "License plate already exists in this organization");
      }
      const vehicleId = newId();
      await db.transaction(async (tx) => {
        await tx.insert(vehicles).values({
          id: vehicleId, userId: ownerId, name: data.name, make: data.make, model: data.model, year: data.year,
          licensePlate: data.plate, vin: data.vin, fuelType: data.fuel_type, mileage: String(data.mileage), mileageUnit: "km",
        });
        await tx.insert(organizationVehicles).values({
          id: newId(), orgId, vehicleId, lifecycleTemplate: template, status: defaultStatus(template), addedBy: actorId,
        });
      });
      results.push({ row: rowNumber, status: "success", vehicle_id: vehicleId });
    } catch (error) {
      const message = error instanceof AppError ? error.message : error instanceof z.ZodError ? "Row has invalid or missing fields" : "Row could not be imported";
      results.push({ row: rowNumber, status: "failed", error: message });
    }
  }
  await db.update(vehicleImportJobs).set({ status: "completed", results, completedAt: new Date() }).where(eq(vehicleImportJobs.id, jobId));
}

async function calculateVehicleCost(db: Db, vehicleId: string) {
  const serviceRows = await db.select().from(serviceRecords).where(eq(serviceRecords.vehicleId, vehicleId));
  const fuelRows = await db.select().from(fuelLogs).where(eq(fuelLogs.vehicleId, vehicleId));
  const expenseRows = await db.select().from(expenses).where(eq(expenses.vehicleId, vehicleId));
  const shifts = await db.select().from(shiftMileage).where(and(eq(shiftMileage.vehicleId, vehicleId), sql`${shiftMileage.kmDriven} IS NOT NULL`));
  const maintenanceCost = serviceRows.reduce((sum, row) => sum + reqNum(row.totalCost), 0);
  const fuelCost = fuelRows.reduce((sum, row) => sum + reqNum(row.cost), 0);
  const wearCost = expenseRows.filter((row) => row.category === "parts").reduce((sum, row) => sum + reqNum(row.amount), 0);
  const km = shifts.reduce((sum, row) => sum + (row.kmDriven ?? 0), 0);
  const tco = maintenanceCost + fuelCost + wearCost;
  const assignments = await db.select().from(driverAssignments).where(eq(driverAssignments.vehicleId, vehicleId));
  const now = Date.now();
  const assignmentStart = assignments.reduce((minimum, row) => Math.min(minimum, row.assignedAt.getTime()), now);
  const periodDays = Math.max(1, Math.ceil((now - assignmentStart) / 86400000));
  const assignedDays = assignments.reduce((sum, row) => {
    const end = row.unassignedAt?.getTime() ?? now;
    return sum + Math.max(0, (end - row.assignedAt.getTime()) / 86400000);
  }, 0);
  return {
    vehicle_id: vehicleId,
    tco,
    cost_per_km: km > 0 ? tco / km : 0,
    total_km_driven: km,
    maintenance_cost: maintenanceCost,
    fuel_cost: fuelCost,
    wear_cost: wearCost,
    utilization_rate: Math.min(100, Math.round((assignedDays / periodDays) * 100)),
  };
}

function thresholdFor(settings: unknown, fleetAverage: number): number {
  const setting = (settings as { lemon_threshold?: { mode?: string; value?: number } } | null)?.lemon_threshold;
  if (setting?.mode === "absolute") return setting.value ?? 0;
  const multiplier = setting?.mode === "multiplier" ? setting.value ?? 2 : 2;
  return fleetAverage * multiplier;
}

function templateForOrganization(type: string): "showroom" | "taxi_fleet" | "rental" | "commercial" {
  if (type === "taxi_fleet") return "taxi_fleet";
  if (type === "rental") return "rental";
  if (type === "commercial" || type === "logistics") return "commercial";
  return "showroom";
}

function defaultStatus(template: "showroom" | "taxi_fleet" | "rental" | "commercial"): string {
  if (template === "showroom") return "inventory";
  return "available";
}
