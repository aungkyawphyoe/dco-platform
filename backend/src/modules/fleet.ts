import { and, eq, inArray } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import {
  driverAssignments,
  organizationMembers,
  organizationVehicles,
  organizationWorkshops,
  organizations,
  partners,
  serviceRecordItems,
  serviceRecords,
  users,
  vehicles,
  warrantyTemplateWorkshops,
  warrantyTemplates,
  workOrders,
} from "../db/schema.js";
import type { Db } from "../db/client.js";
import { newId } from "../lib/crypto.js";
import { createInvitedOwnerAccount } from "../lib/account-invites.js";
import { dateOnly, iso, num, recordChange, reqNum } from "../lib/dbx.js";
import { AppError } from "../lib/errors.js";
import { publicVehicle } from "../lib/serialize.js";
import { requireFleetClient } from "./auth.js";

const uuid = z.string().uuid();
const orgRole = z.enum(["org_admin", "org_manager", "org_mechanic", "org_driver"]);
const lifecycleTemplate = z.enum(["showroom", "taxi_fleet", "rental", "commercial"]);
const issueType = z.enum(["breakdown", "accident", "wear_tear", "scheduled_service", "other"]);
const urgency = z.enum(["low", "medium", "high", "critical"]);

const initialStatus: Record<z.infer<typeof lifecycleTemplate>, string> = {
  showroom: "inventory",
  taxi_fleet: "available",
  rental: "available",
  commercial: "available",
};

const transitions: Record<z.infer<typeof lifecycleTemplate>, Record<string, string[]>> = {
  showroom: { inventory: ["listed"], listed: ["inventory", "reserved"], reserved: ["listed", "sold"], sold: [] },
  taxi_fleet: { available: ["leased", "maintenance"], leased: ["maintenance", "available"], maintenance: ["available"] },
  rental: { available: ["rented"], rented: ["return"], return: ["inspection"], inspection: ["available"] },
  commercial: { available: ["in_service", "maintenance"], in_service: ["maintenance", "retired"], maintenance: ["available", "in_service", "retired"], retired: [] },
};

export async function getOrganizationAccess(db: Db, userId: string, orgId: string, roles?: string[]) {
  const [result] = await db.select({ organization: organizations, membership: organizationMembers })
    .from(organizationMembers)
    .innerJoin(organizations, eq(organizationMembers.orgId, organizations.id))
    .where(and(eq(organizationMembers.orgId, orgId), eq(organizationMembers.userId, userId)))
    .limit(1);
  if (!result) throw new AppError(403, "not_org_member", "User is not a member of this organization");
  if (result.organization.plan !== "enterprise") throw new AppError(403, "enterprise_org_required", "Enterprise organization entitlement is required");
  if (result.organization.status !== "active") throw new AppError(403, "org_not_active", "Organization is not active");
  if (roles && !roles.includes(result.membership.role)) {
    throw new AppError(403, "insufficient_org_role", "Organization role does not permit this operation");
  }
  return result;
}

function serializeOrganization(row: typeof organizations.$inferSelect, role: string) {
  return {
    id: row.id,
    name: row.name,
    type: row.type,
    plan: row.plan,
    status: row.status,
    role,
    contact_email: row.contactEmail,
    contact_phone: row.contactPhone,
  };
}

function serializeMember(row: typeof organizationMembers.$inferSelect, user: typeof users.$inferSelect) {
  return {
    user_id: user.id,
    email: user.email,
    display_name: user.displayName,
    role: row.role,
    joined_at: iso(row.joinedAt),
    invited_by: row.invitedBy,
  };
}

function serializeOrganizationVehicle(row: typeof organizationVehicles.$inferSelect, vehicle: typeof vehicles.$inferSelect, assignedDriver?: string | null) {
  return {
    ...publicVehicle(vehicle),
    lifecycle_template: row.lifecycleTemplate,
    status: row.status,
    revenue_label: row.revenueLabel,
    assigned_driver_id: assignedDriver ?? null,
    added_at: iso(row.addedAt),
  };
}

export const fleetPlugin: FastifyPluginAsync = async (app) => {
  const uid = (request: { authUser?: { sub: string } }) => request.authUser!.sub;

  app.get("/drivers/my-vehicle", async (request) => {
    requireFleetClient(request);
    const userId = uid(request);
    const [result] = await app.db.select({ organization: organizations, membership: organizationMembers })
      .from(organizationMembers)
      .innerJoin(organizations, eq(organizationMembers.orgId, organizations.id))
      .where(eq(organizationMembers.userId, userId))
      .limit(1);
    if (!result || result.membership.role !== "org_driver") throw new AppError(403, "driver_mode_required", "An organization driver membership is required");
    if (result.organization.status !== "active" || result.organization.plan !== "enterprise") {
      throw new AppError(403, "org_not_active", "Organization is not active");
    }
    const [assignment] = await app.db.select().from(driverAssignments).where(and(
      eq(driverAssignments.orgId, result.organization.id), eq(driverAssignments.driverId, userId), eq(driverAssignments.status, "active"),
    )).limit(1);
    if (!assignment) return { organization: serializeOrganization(result.organization, result.membership.role), assignment: null, vehicle: null };
    const [row] = await app.db.select({ organizationVehicle: organizationVehicles, vehicle: vehicles })
      .from(organizationVehicles).innerJoin(vehicles, eq(organizationVehicles.vehicleId, vehicles.id))
      .where(and(eq(organizationVehicles.orgId, result.organization.id), eq(organizationVehicles.vehicleId, assignment.vehicleId))).limit(1);
    if (!row) throw new AppError(404, "vehicle_not_in_org", "Assigned vehicle no longer belongs to the organization");
    const vehicleDetails = serializeOrganizationVehicle(row.organizationVehicle, row.vehicle, userId);
    delete (vehicleDetails as { revenue_label?: string | null }).revenue_label;
    return {
      organization: serializeOrganization(result.organization, result.membership.role),
      assignment: serializeAssignment(assignment),
      vehicle: vehicleDetails,
    };
  });

  app.get("/organizations/me", async (request) => {
    requireFleetClient(request);
    const [result] = await app.db.select({ organization: organizations, membership: organizationMembers })
      .from(organizationMembers)
      .innerJoin(organizations, eq(organizationMembers.orgId, organizations.id))
      .where(eq(organizationMembers.userId, uid(request)))
      .limit(1);
    if (!result) return { organization: null, fleet_access: false };
    const access = result.organization.plan === "enterprise" && result.organization.status === "active";
    return {
      organization: serializeOrganization(result.organization, result.membership.role),
      fleet_access: access,
    };
  });

  app.get("/organizations/:id/members", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
    const rows = await app.db.select({ membership: organizationMembers, user: users })
      .from(organizationMembers)
      .innerJoin(users, eq(organizationMembers.userId, users.id))
      .where(eq(organizationMembers.orgId, orgId));
    return { items: rows.map((row) => serializeMember(row.membership, row.user)) };
  });

  app.post("/organizations/:id/members", async (request, reply) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin"]);
    const body = z.object({ email: z.string().email().max(254), role: z.enum(["org_manager", "org_mechanic", "org_driver"]) }).parse(request.body);
    let [member] = await app.db.select().from(users).where(eq(users.email, body.email.toLowerCase())).limit(1);
    let accountInvitationSent = false;
    if (!member) {
      const invited = await createInvitedOwnerAccount(app.db, app.mailer, body.email);
      member = invited.user;
      accountInvitationSent = invited.created;
    }
    if (member.role !== "owner" || member.status !== "active") {
      throw new AppError(409, "invalid_member_account", "Organization members must use an active owner account");
    }
    const [existing] = await app.db.select().from(organizationMembers).where(eq(organizationMembers.userId, member.id)).limit(1);
    if (existing) throw new AppError(409, "already_in_org", "User already belongs to an organization");
    const [created] = await app.db.insert(organizationMembers).values({
      id: newId(), orgId, userId: member.id, role: body.role, invitedBy: actorId,
    }).returning();
    let organizationInvitationSent = true;
    try {
      const [organization] = await app.db.select().from(organizations).where(eq(organizations.id, orgId)).limit(1);
      await app.mailer.sendOrganizationInvitation(member.email, organization!.name, body.role);
    } catch (error) {
      organizationInvitationSent = false;
      app.log.error(error);
    }
    return reply.code(201).send({
      ...serializeMember(created, member),
      account_invitation_sent: accountInvitationSent,
      organization_invitation_sent: organizationInvitationSent,
    });
  });

  app.patch("/organizations/:id/members/:userId", async (request, reply) => {
    requireFleetClient(request);
    const { id: rawOrgId, userId: memberId } = request.params as { id: string; userId: string };
    const orgId = uuid.parse(rawOrgId);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin"]);
    const body = z.object({ role: z.enum(["org_manager", "org_mechanic", "org_driver"]).optional(), remove: z.boolean().optional() })
      .refine((value) => value.role !== undefined || value.remove === true, "Specify a role or remove=true")
      .parse(request.body ?? {});
    const [membership] = await app.db.select().from(organizationMembers)
      .where(and(eq(organizationMembers.orgId, orgId), eq(organizationMembers.userId, memberId))).limit(1);
    if (!membership) throw new AppError(404, "member_not_found", "Organization member not found");
    if (membership.role === "org_admin") throw new AppError(409, "cannot_change_org_admin", "Transfer Org Admin responsibility before removing or changing this member");
    if (body.remove) {
      await app.db.update(driverAssignments).set({ status: "completed", unassignedAt: new Date() }).where(and(
        eq(driverAssignments.orgId, orgId), eq(driverAssignments.driverId, memberId), eq(driverAssignments.status, "active"),
      ));
      await app.db.delete(organizationMembers).where(eq(organizationMembers.id, membership.id));
      return reply.code(204).send();
    }
    const [updated] = await app.db.update(organizationMembers).set({ role: body.role! }).where(eq(organizationMembers.id, membership.id)).returning();
    const [member] = await app.db.select().from(users).where(eq(users.id, memberId)).limit(1);
    return serializeMember(updated, member!);
  });

  app.get("/organizations/:id/workshops", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
    const rows = await app.db.select({ organizationWorkshop: organizationWorkshops, partner: partners })
      .from(organizationWorkshops)
      .innerJoin(partners, eq(organizationWorkshops.partnerId, partners.id))
      .where(eq(organizationWorkshops.orgId, orgId));
    return { items: rows.map((row) => ({
      id: row.partner.id,
      name: row.partner.name,
      status: row.partner.status,
      contact_email: row.partner.contactEmail,
      contact_phone: row.partner.contactPhone,
      added_at: iso(row.organizationWorkshop.addedAt),
    })) };
  });

  app.post("/organizations/:id/workshops", async (request, reply) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin"]);
    const body = z.object({ partner_id: uuid }).parse(request.body);
    const [partner] = await app.db.select().from(partners).where(eq(partners.id, body.partner_id)).limit(1);
    if (!partner || partner.type !== "workshop") throw new AppError(404, "workshop_not_found", "Workshop partner not found");
    if (partner.status !== "verified") throw new AppError(409, "workshop_not_verified", "Workshop must be verified before it can be approved");
    const [existing] = await app.db.select().from(organizationWorkshops).where(and(
      eq(organizationWorkshops.orgId, orgId), eq(organizationWorkshops.partnerId, partner.id),
    )).limit(1);
    if (existing) throw new AppError(409, "workshop_already_approved", "Workshop is already approved for this organization");
    const [row] = await app.db.insert(organizationWorkshops).values({ id: newId(), orgId, partnerId: partner.id, addedBy: actorId }).returning();
    return reply.code(201).send({ id: partner.id, name: partner.name, status: partner.status, added_at: iso(row.addedAt) });
  });

  app.delete("/organizations/:id/workshops/:partnerId", async (request, reply) => {
    requireFleetClient(request);
    const { id: rawOrgId, partnerId } = request.params as { id: string; partnerId: string };
    const orgId = uuid.parse(rawOrgId);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin"]);
    const templates = await app.db.select({ id: warrantyTemplates.id }).from(warrantyTemplates).where(eq(warrantyTemplates.orgId, orgId));
    if (templates.length) {
      await app.db.delete(warrantyTemplateWorkshops).where(and(
        eq(warrantyTemplateWorkshops.partnerId, partnerId),
        inArray(warrantyTemplateWorkshops.templateId, templates.map((template) => template.id)),
      ));
    }
    const [removed] = await app.db.delete(organizationWorkshops).where(and(
      eq(organizationWorkshops.orgId, orgId), eq(organizationWorkshops.partnerId, partnerId),
    )).returning();
    if (!removed) throw new AppError(404, "workshop_not_approved", "Workshop is not approved for this organization");
    return reply.code(204).send();
  });

  app.get("/organizations/:id/vehicles", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const { membership } = await getOrganizationAccess(app.db, uid(request), orgId);
    let rows = await app.db.select({ organizationVehicle: organizationVehicles, vehicle: vehicles })
      .from(organizationVehicles)
      .innerJoin(vehicles, eq(organizationVehicles.vehicleId, vehicles.id))
      .where(eq(organizationVehicles.orgId, orgId));
    if (membership.role === "org_driver") {
      const assignments = await app.db.select().from(driverAssignments).where(and(
        eq(driverAssignments.orgId, orgId), eq(driverAssignments.driverId, uid(request)), eq(driverAssignments.status, "active"),
      ));
      const assignedIds = new Set(assignments.map((assignment) => assignment.vehicleId));
      rows = rows.filter((row) => assignedIds.has(row.vehicle.id));
    }
    const items = [];
    for (const row of rows) {
      const [assignment] = await app.db.select().from(driverAssignments).where(and(
        eq(driverAssignments.orgId, orgId), eq(driverAssignments.vehicleId, row.vehicle.id), eq(driverAssignments.status, "active"),
      )).limit(1);
      const item = serializeOrganizationVehicle(row.organizationVehicle, row.vehicle, assignment?.driverId ?? null);
      if (membership.role === "org_driver") delete (item as { revenue_label?: string | null }).revenue_label;
      items.push(item);
    }
    return { items };
  });

  app.post("/organizations/:id/vehicles", async (request, reply) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const actorId = uid(request);
    const { organization } = await getOrganizationAccess(app.db, actorId, orgId, ["org_admin", "org_manager"]);
    const body = z.object({
      id: uuid,
      name: z.string().min(1).max(100),
      make: z.string().min(1).max(100),
      model: z.string().min(1).max(100),
      year: z.number().int().min(1900).max(new Date().getFullYear() + 1),
      license_plate: z.string().min(1).max(20),
      vin: z.string().length(17),
      fuel_type: z.enum(["petrol", "electric", "hybrid_plugin"]),
      mileage: z.number().min(0).default(0),
      lifecycle_template: lifecycleTemplate,
      revenue_label: z.string().max(200).optional().nullable(),
    }).parse(request.body);
    const [existingVehicle] = await app.db.select().from(vehicles).where(eq(vehicles.id, body.id)).limit(1);
    if (existingVehicle) throw new AppError(409, "vehicle_id_taken", "Vehicle ID already exists");
    const [existingVin] = await app.db.select().from(vehicles).where(and(eq(vehicles.vin, body.vin), eq(vehicles.archived, false))).limit(1);
    if (existingVin) throw new AppError(409, "duplicate_vin", "VIN already belongs to another vehicle");
    const existingPlates = await app.db.select({ plate: vehicles.licensePlate }).from(organizationVehicles)
      .innerJoin(vehicles, eq(organizationVehicles.vehicleId, vehicles.id)).where(eq(organizationVehicles.orgId, orgId));
    if (existingPlates.some((row) => row.plate.toLowerCase() === body.license_plate.toLowerCase())) {
      throw new AppError(409, "duplicate_plate", "License plate already belongs to a vehicle in this organization");
    }
    const status = initialStatus[body.lifecycle_template];
    const vehicle = await app.db.transaction(async (tx) => {
      const [createdVehicle] = await tx.insert(vehicles).values({
        id: body.id,
        userId: organization.adminUserId,
        name: body.name,
        make: body.make,
        model: body.model,
        year: body.year,
        licensePlate: body.license_plate,
        vin: body.vin,
        fuelType: body.fuel_type,
        mileage: String(body.mileage),
        mileageUnit: "km",
      }).returning();
      const [createdLink] = await tx.insert(organizationVehicles).values({
        id: newId(), orgId, vehicleId: createdVehicle.id, lifecycleTemplate: body.lifecycle_template,
        status, revenueLabel: body.revenue_label ?? null, addedBy: actorId,
      }).returning();
      return { vehicle: createdVehicle, link: createdLink };
    });
    await recordChange(app.db, { userId: actorId, entityType: "organization_vehicle", entityId: vehicle.link.id, op: "upsert", payload: serializeOrganizationVehicle(vehicle.link, vehicle.vehicle) });
    return reply.code(201).send(serializeOrganizationVehicle(vehicle.link, vehicle.vehicle));
  });

  app.patch("/organizations/:id/vehicles/:vehicleId", async (request) => {
    requireFleetClient(request);
    const { id: rawOrgId, vehicleId } = request.params as { id: string; vehicleId: string };
    const orgId = uuid.parse(rawOrgId);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin", "org_manager"]);
    const body = z.object({ status: z.string().min(1).max(40), revenue_label: z.string().max(200).nullable().optional() }).parse(request.body);
    const [link] = await app.db.select().from(organizationVehicles).where(and(eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, vehicleId))).limit(1);
    if (!link) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
    if (body.status !== link.status && !(transitions[link.lifecycleTemplate][link.status] ?? []).includes(body.status)) {
      throw new AppError(400, "invalid_status_transition", "Status transition is not allowed by the vehicle lifecycle template");
    }
    const [updated] = await app.db.update(organizationVehicles).set({
      status: body.status,
      ...(body.revenue_label !== undefined ? { revenueLabel: body.revenue_label } : {}),
      updatedAt: new Date(),
    }).where(eq(organizationVehicles.id, link.id)).returning();
    const [vehicle] = await app.db.select().from(vehicles).where(eq(vehicles.id, vehicleId)).limit(1);
    const payload = serializeOrganizationVehicle(updated, vehicle!);
    await recordChange(app.db, { userId: actorId, entityType: "organization_vehicle", entityId: updated.id, op: "upsert", payload });
    return payload;
  });

  app.post("/organizations/:id/assignments", async (request, reply) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin", "org_manager"]);
    const body = z.object({ vehicle_id: uuid, driver_id: uuid }).parse(request.body);
    const [driver] = await app.db.select().from(organizationMembers).where(and(
      eq(organizationMembers.orgId, orgId), eq(organizationMembers.userId, body.driver_id), eq(organizationMembers.role, "org_driver"),
    )).limit(1);
    if (!driver) throw new AppError(422, "invalid_driver", "Driver must be an org_driver member of this organization");
    const [vehicle] = await app.db.select().from(organizationVehicles).where(and(
      eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, body.vehicle_id),
    )).limit(1);
    if (!vehicle) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
    const [driverCurrent] = await app.db.select().from(driverAssignments).where(and(eq(driverAssignments.driverId, body.driver_id), eq(driverAssignments.status, "active"))).limit(1);
    if (driverCurrent) throw new AppError(409, "driver_already_assigned", "Driver already has an active vehicle assignment");
    const [vehicleCurrent] = await app.db.select().from(driverAssignments).where(and(eq(driverAssignments.vehicleId, body.vehicle_id), eq(driverAssignments.status, "active"))).limit(1);
    if (vehicleCurrent) throw new AppError(409, "vehicle_already_assigned", "Vehicle already has an active driver assignment");
    const [assignment] = await app.db.insert(driverAssignments).values({
      id: newId(), orgId, vehicleId: body.vehicle_id, driverId: body.driver_id, assignedBy: actorId,
    }).returning();
    return reply.code(201).send(serializeAssignment(assignment));
  });

  app.get("/organizations/:id/assignments", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const { membership } = await getOrganizationAccess(app.db, uid(request), orgId);
    const conditions = [eq(driverAssignments.orgId, orgId)];
    if (membership.role === "org_driver") conditions.push(eq(driverAssignments.driverId, uid(request)));
    const rows = await app.db.select().from(driverAssignments).where(and(...conditions));
    return { items: rows.map(serializeAssignment) };
  });

  app.delete("/organizations/:id/assignments/:assignmentId", async (request, reply) => {
    requireFleetClient(request);
    const { id: rawOrgId, assignmentId } = request.params as { id: string; assignmentId: string };
    const orgId = uuid.parse(rawOrgId);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin", "org_manager"]);
    const [assignment] = await app.db.select().from(driverAssignments).where(and(
      eq(driverAssignments.id, assignmentId), eq(driverAssignments.orgId, orgId), eq(driverAssignments.status, "active"),
    )).limit(1);
    if (!assignment) throw new AppError(404, "assignment_not_found", "Active assignment not found");
    const [updated] = await app.db.update(driverAssignments).set({ status: "completed", unassignedAt: new Date() })
      .where(eq(driverAssignments.id, assignment.id)).returning();
    return reply.code(200).send(serializeAssignment(updated));
  });

  app.post("/organizations/:id/vehicles/:vehicleId/service-records", async (request, reply) => {
    requireFleetClient(request);
    const { id: rawOrgId, vehicleId } = request.params as { id: string; vehicleId: string };
    const orgId = uuid.parse(rawOrgId);
    const actorId = uid(request);
    const { organization } = await getOrganizationAccess(app.db, actorId, orgId, ["org_admin", "org_manager", "org_mechanic"]);
    const [orgVehicle] = await app.db.select().from(organizationVehicles).where(and(
      eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, vehicleId),
    )).limit(1);
    if (!orgVehicle) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
    const body = z.object({
      serviced_on: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      odometer: z.number().min(0),
      total_cost: z.number().min(0),
      workshop_name: z.string().max(120).optional().nullable(),
      notes: z.string().max(2000).optional().nullable(),
      items: z.array(z.object({ name: z.string().min(1).max(100), line_cost: z.number().min(0).optional().nullable() })).min(1),
    }).parse(request.body);
    const [fleetVehicle] = await app.db.select().from(vehicles).where(eq(vehicles.id, vehicleId)).limit(1);
    if (!fleetVehicle || body.odometer < reqNum(fleetVehicle.mileage)) {
      throw new AppError(400, "odometer_regression", "Service odometer cannot be lower than the last recorded vehicle mileage");
    }
    const serviceId = newId();
    const record = await app.db.transaction(async (tx) => {
      const [created] = await tx.insert(serviceRecords).values({
        id: serviceId, vehicleId, servicedOn: body.serviced_on, odometer: String(body.odometer), totalCost: String(body.total_cost),
        workshopName: body.workshop_name ?? null, notes: body.notes ?? null,
      }).returning();
      const items = [];
      for (const item of body.items) {
        const [createdItem] = await tx.insert(serviceRecordItems).values({
          id: newId(), serviceRecordId: serviceId, name: item.name, lineCost: item.line_cost == null ? null : String(item.line_cost),
        }).returning();
        items.push(createdItem);
      }
      await tx.update(vehicles).set({ mileage: String(body.odometer), updatedAt: new Date() }).where(eq(vehicles.id, vehicleId));
      return { created, items };
    });
    const payload = {
      id: record.created.id,
      vehicle_id: vehicleId,
      serviced_on: dateOnly(record.created.servicedOn),
      odometer: reqNum(record.created.odometer),
      total_cost: reqNum(record.created.totalCost),
      workshop_name: record.created.workshopName,
      notes: record.created.notes,
      items: record.items.map((item) => ({ id: item.id, name: item.name, line_cost: num(item.lineCost) })),
    };
    await recordChange(app.db, { userId: actorId, entityType: "service_record", entityId: serviceId, op: "upsert", payload });
    if (organization.adminUserId !== actorId) {
      await recordChange(app.db, { userId: organization.adminUserId, entityType: "service_record", entityId: serviceId, op: "upsert", payload });
    }
    return reply.code(201).send(payload);
  });

  app.post("/organizations/:id/work-orders", async (request, reply) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_driver"]);
    const body = z.object({
      vehicle_id: uuid,
      odometer_km: z.number().int().min(0),
      issue_type: issueType,
      description: z.string().min(10).max(2000),
      urgency,
      photos: z.array(uuid).max(5).optional().default([]),
    }).parse(request.body);
    const [assignment] = await app.db.select().from(driverAssignments).where(and(
      eq(driverAssignments.orgId, orgId), eq(driverAssignments.vehicleId, body.vehicle_id),
      eq(driverAssignments.driverId, actorId), eq(driverAssignments.status, "active"),
    )).limit(1);
    if (!assignment) throw new AppError(403, "not_assigned_to_vehicle", "Driver is not assigned to this vehicle");
    const [workOrder] = await app.db.insert(workOrders).values({
      id: newId(), orgId, vehicleId: body.vehicle_id, reportedBy: actorId, odometerKm: body.odometer_km,
      issueType: body.issue_type, description: body.description, urgency: body.urgency, photos: body.photos,
    }).returning();
    return reply.code(201).send(serializeWorkOrder(workOrder));
  });

  app.get("/organizations/:id/work-orders", async (request) => {
    requireFleetClient(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const { membership } = await getOrganizationAccess(app.db, uid(request), orgId);
    const visibility = membership.role === "org_driver"
      ? eq(workOrders.reportedBy, uid(request))
      : membership.role === "org_mechanic"
        ? eq(workOrders.assignedTo, uid(request))
        : undefined;
    const rows = await app.db.select().from(workOrders).where(and(
      eq(workOrders.orgId, orgId), ...(visibility ? [visibility] : []),
    ));
    return { items: rows.map(serializeWorkOrder) };
  });

  app.get("/drivers/my-work-orders", async (request) => {
    requireFleetClient(request);
    const userId = uid(request);
    const [membership] = await app.db.select().from(organizationMembers).where(and(
      eq(organizationMembers.userId, userId), eq(organizationMembers.role, "org_driver"),
    )).limit(1);
    if (!membership) throw new AppError(403, "driver_mode_required", "An organization driver membership is required");
    await getOrganizationAccess(app.db, userId, membership.orgId, ["org_driver"]);
    const rows = await app.db.select().from(workOrders).where(and(eq(workOrders.orgId, membership.orgId), eq(workOrders.reportedBy, userId)));
    return { items: rows.map(serializeWorkOrder) };
  });

  app.patch("/organizations/:id/work-orders/:workOrderId", async (request) => {
    requireFleetClient(request);
    const { id: rawOrgId, workOrderId } = request.params as { id: string; workOrderId: string };
    const orgId = uuid.parse(rawOrgId);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin", "org_manager"]);
    const body = z.object({ status: z.enum(["in_progress", "completed"]), assigned_to: uuid.optional().nullable(), resolution_notes: z.string().max(2000).optional().nullable() }).parse(request.body);
    const [current] = await app.db.select().from(workOrders).where(and(eq(workOrders.id, workOrderId), eq(workOrders.orgId, orgId))).limit(1);
    if (!current) throw new AppError(404, "work_order_not_found", "Work order not found");
    const allowed = current.status === "reported" ? body.status === "in_progress" : current.status === "in_progress" && body.status === "completed";
    if (!allowed) throw new AppError(400, "invalid_work_order_status", "Work order must advance reported → in_progress → completed");
    if (body.assigned_to) {
      const [assignee] = await app.db.select().from(organizationMembers).where(and(
        eq(organizationMembers.orgId, orgId), eq(organizationMembers.userId, body.assigned_to), inArray(organizationMembers.role, ["org_manager", "org_mechanic"]),
      )).limit(1);
      if (!assignee) throw new AppError(422, "invalid_assignee", "Work order assignee must be a mechanic or manager in this organization");
    }
    const [updated] = await app.db.update(workOrders).set({
      status: body.status,
      ...(body.assigned_to !== undefined ? { assignedTo: body.assigned_to } : {}),
      ...(body.status === "completed" ? { resolvedBy: actorId, resolvedAt: new Date(), resolutionNotes: body.resolution_notes ?? null } : {}),
      updatedAt: new Date(),
    }).where(eq(workOrders.id, current.id)).returning();
    return serializeWorkOrder(updated);
  });
};

function serializeAssignment(row: typeof driverAssignments.$inferSelect) {
  return {
    id: row.id,
    org_id: row.orgId,
    vehicle_id: row.vehicleId,
    driver_id: row.driverId,
    assigned_by: row.assignedBy,
    assigned_at: iso(row.assignedAt),
    unassigned_at: iso(row.unassignedAt),
    status: row.status,
  };
}

function serializeWorkOrder(row: typeof workOrders.$inferSelect) {
  return {
    id: row.id,
    org_id: row.orgId,
    vehicle_id: row.vehicleId,
    reported_by: row.reportedBy,
    reported_at: iso(row.reportedAt),
    odometer_km: row.odometerKm,
    issue_type: row.issueType,
    description: row.description,
    urgency: row.urgency,
    photos: row.photos,
    status: row.status,
    assigned_to: row.assignedTo,
    resolved_by: row.resolvedBy,
    resolved_at: iso(row.resolvedAt),
    resolution_notes: row.resolutionNotes,
    created_at: iso(row.createdAt),
    updated_at: iso(row.updatedAt),
  };
}
