import { currentRecord } from "../lib/record-ownership.js";
import { saveReminderBaseline, recalculateReminders } from "../lib/reminder-schedule.js";
import { credentialBody, expiryStatus, saveCredentials } from "../lib/driver-credentials.js";
import { incomingCurrency, incomingServiceCurrency, lockCurrencyVehicle } from '../lib/operational-currency.js';
import { billingRequest } from "../lib/subscription-access.js";
import { assertOrganizationWritable } from "../lib/subscriptions.js";
import { and, desc, eq, inArray, isNull, or, sql } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import {
  drivingLicenses,
  driverAssignments,
  maintenanceCatalog,
  organizationMembers,
  organizationVehicles,
  organizationWorkshops,
  organizations,
  partners,
  parts as partsTable,
  planItems,
  serviceRecordItems,
  serviceRecordParts,
  serviceRecords,
  users,
  vehicles,
  warrantyTemplateWorkshops,
  warrantyTemplates,
  workOrders,
} from "../db/schema.js";
import type { Db } from "../db/client.js";
import { newId } from "../lib/crypto.js";
import { provisionOwnerAccount } from "../lib/account-provisioning.js";
import { dueFrom } from "../lib/catalog.js";
import { slugify } from "../lib/slug.js";
import { dateOnly, iso, num, recordChange, reqNum } from "../lib/dbx.js";
import { AppError } from "../lib/errors.js";
import { publicPlan } from "../lib/serialize-records.js";
import { publicVehicle, publicUser } from "../lib/serialize.js";
import { requireFleetClient, requireFleetPortal } from "./auth.js";
import { refreshTokens } from "../db/schema.js";

const uuid = z.string().uuid();
const orgRole = z.enum(["org_admin", "org_manager", "org_mechanic", "org_driver"]);
const lifecycleTemplate = z.enum(["showroom", "taxi_fleet", "rental", "commercial"]);
const vehicleClass = z.enum(["car", "motorcycle", "truck", "van", "bus"]);
const fuelTypesEnum = z.enum(["petrol", "electric", "hybrid_plugin"]);
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
  if (!result || result.membership.status !== "active") throw new AppError(403, "not_org_member", "User is not a member of this organization");
  if (result.organization.plan !== "enterprise") throw new AppError(403, "enterprise_org_required", "Enterprise organization entitlement is required");
  if (result.organization.status !== "active") throw new AppError(403, "org_not_active", "Organization is not active");
  if (roles && !roles.includes(result.membership.role)) {
    throw new AppError(403, "insufficient_org_role", "Organization role does not permit this operation");
  }
  if (billingRequest.getStore()?.write) await assertOrganizationWritable(db, orgId);
  return result;
}

export async function assertPasswordChangeClear(db: Db, userId: string) {
  const [membership] = await db.select().from(organizationMembers).where(eq(organizationMembers.userId, userId)).limit(1);
  if (membership && membership.status !== "active") throw new AppError(403, "membership_inactive", "Organization membership is inactive");
  const [user] = await db
    .select({ mustChangePassword: users.mustChangePassword })
    .from(users)
    .where(eq(users.id, userId))
    .limit(1);
  if (user?.mustChangePassword) {
    throw new AppError(403, "password_change_required", "Temporary password must be changed");
  }
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
    status: row.status,
    joined_at: iso(row.joinedAt),
    invited_by: row.invitedBy,
  };
}

function serializeOrganizationVehicle(row: typeof organizationVehicles.$inferSelect, vehicle: typeof vehicles.$inferSelect, assignedDriver?: string | null) {
  return {
    ...publicVehicle(vehicle),
    base_currency: vehicle.baseCurrency,
    lifecycle_template: row.lifecycleTemplate,
    status: row.status,
    revenue_label: row.revenueLabel,
    assigned_driver_id: assignedDriver ?? null,
    added_at: iso(row.addedAt),
  };
}

export const fleetPlugin: FastifyPluginAsync = async (app) => {
  const uid = (request: { authUser?: { sub: string } }) => request.authUser!.sub;

  app.addHook("preHandler", async (request) => {
    await assertPasswordChangeClear(app.db, request.authUser!.sub);
  });

  app.get("/drivers/my-vehicle", async (request) => {
    requireFleetClient(request);
    const userId = uid(request);
    const [result] = await app.db.select({ organization: organizations, membership: organizationMembers })
      .from(organizationMembers)
      .innerJoin(organizations, eq(organizationMembers.orgId, organizations.id))
      .where(eq(organizationMembers.userId, userId))
      .limit(1);
    if (!result || result.membership.status !== "active" || result.membership.role !== "org_driver") throw new AppError(403, "driver_mode_required", "An organization driver membership is required");
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
    const access = result.membership.status === "active" && result.organization.plan === "enterprise" && result.organization.status === "active";
    return {
      organization: serializeOrganization(result.organization, result.membership.role),
      fleet_access: access,
    };
  });

  app.get("/organizations/:id/members", async (request) => {
    requireFleetPortal(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
    const rows = await app.db.select({membership:organizationMembers,user:users,expiry:drivingLicenses.expiryDate})
      .from(organizationMembers).innerJoin(users,eq(organizationMembers.userId,users.id))
      .leftJoin(drivingLicenses,eq(drivingLicenses.userId,users.id))
      .where(eq(organizationMembers.orgId,orgId));
    return {items:rows.map(row=>({...serializeMember(row.membership,row.user),
      ...(row.membership.role === "org_driver" ? {license_expiry_date:row.expiry, license_status:expiryStatus(row.expiry)} : {})}))};
  });

  app.put("/organizations/:id/members/:userId/license", async request => {
    requireFleetPortal(request);
    const {id,userId}=z.object({id:uuid,userId:uuid}).parse(request.params);
    const actor=uid(request);
    await assertPasswordChangeClear(app.db,actor);
    const body=credentialBody.parse(request.body);
    return app.db.transaction(async tx=>{
      await getOrganizationAccess(tx,actor,id,["org_admin","org_manager"]);
      const [driver]=await tx.select().from(organizationMembers).where(and(
        eq(organizationMembers.orgId,id),eq(organizationMembers.userId,userId),
        eq(organizationMembers.role,"org_driver"),eq(organizationMembers.status,"active"))).for("update");
      if (!driver) throw new AppError(404,"not_found","Active fleet driver not found");
      const saved=await saveCredentials(tx,userId,body);
      return {license_expiry_date:saved.license_expiry_date,license_status:expiryStatus(saved.license_expiry_date)};
    });
  });

  app.post("/organizations/:id/members", async (request, reply) => {
    requireFleetPortal(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin"]);
    const body = z.object({
      email: z.string().email().max(254),
      role: z.enum(["org_manager", "org_mechanic", "org_driver"]),
      temporary_password: z.string().min(8).max(128).optional(),
    }).parse(request.body);
    let [member] = await app.db.select().from(users).where(eq(users.email, body.email.toLowerCase())).limit(1);
    let accountCreated = false;
    let temporaryPassword: string | null = null;
    if (member) {
      throw new AppError(409, "personal_account_exists", "Use a new email for a dedicated organization account. Existing accounts require an invitation acceptance flow.");
    } else {
      const provisioned = await provisionOwnerAccount(app.db, body.email, body.temporary_password);
      if (!provisioned.created) throw new AppError(409, "personal_account_exists", "Existing accounts require an invitation acceptance flow");
      member = provisioned.user;
      accountCreated = provisioned.created;
      temporaryPassword = provisioned.temporaryPassword;
    }
    if (member.role !== "owner" || member.status !== "active") {
      throw new AppError(409, "invalid_member_account", "Organization members must use an active owner account");
    }
    const [existing] = await app.db.select().from(organizationMembers).where(eq(organizationMembers.userId, member.id)).limit(1);
    if (existing) throw new AppError(409, "already_in_org", "User already belongs to an organization");
    const [created] = await app.db.insert(organizationMembers).values({
      id: newId(), orgId, userId: member.id, role: body.role, invitedBy: actorId,
    }).returning();
    return reply.code(201).send({
      ...serializeMember(created, member),
      account_created: accountCreated,
      temporary_password: temporaryPassword,
    });
  });

  app.patch("/organizations/:id/members/:userId", async (request, reply) => {
    requireFleetPortal(request);
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
    if (body.role === "org_driver" && membership.role !== "org_driver") {
      throw new AppError(409, "dedicated_driver_required", "Provision a dedicated driver account instead of converting an existing identity");
    }
    const [updated] = await app.db.update(organizationMembers).set({ role: body.role! }).where(eq(organizationMembers.id, membership.id)).returning();
    const [member] = await app.db.select().from(users).where(eq(users.id, memberId)).limit(1);
    return serializeMember(updated, member!);
  });

  app.post("/organizations/:id/members/:userId/status", async (request, reply) => {
    requireFleetPortal(request);
    const { id: rawOrgId, userId: memberId } = request.params as { id: string; userId: string };
    const orgId = uuid.parse(rawOrgId);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin"]);
    const body = z.object({ status: z.enum(["active", "deactivated"]) }).parse(request.body);
    const [membership] = await app.db.select().from(organizationMembers).where(and(eq(organizationMembers.orgId, orgId), eq(organizationMembers.userId, memberId))).limit(1);
    if (!membership) throw new AppError(404, "member_not_found", "Organization member not found");
    if (membership.role === "org_admin") throw new AppError(409, "cannot_change_org_admin", "Cannot change org admin status");
    const [targetUser] = await app.db.select().from(users).where(eq(users.id, memberId)).limit(1);
    if (!targetUser) throw new AppError(404, "user_not_found", "User not found");
    await app.db.transaction(async (tx) => {
      await tx.update(organizationMembers).set({ status: body.status }).where(eq(organizationMembers.id, membership.id));
      if (body.status === "deactivated") {
        await tx.update(driverAssignments).set({ status: "completed", unassignedAt: new Date() }).where(and(
          eq(driverAssignments.orgId, orgId), eq(driverAssignments.driverId, memberId), eq(driverAssignments.status, "active"),
        ));
      }
    });
    return { status: body.status, user_id: memberId };
  });

  app.get("/organizations/:id/workshops", async (request) => {
    requireFleetPortal(request);
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
    requireFleetPortal(request);
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
    requireFleetPortal(request);
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
    requireFleetPortal(request);
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
    requireFleetPortal(request);
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
      vehicle_class: vehicleClass.optional(),
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
        vehicleClass: body.vehicle_class ?? "car",
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
    requireFleetPortal(request);
    const { id: rawOrgId, vehicleId } = request.params as { id: string; vehicleId: string };
    const orgId = uuid.parse(rawOrgId);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin", "org_manager"]);
    const body = z.object({
      status: z.string().min(1).max(40),
      expected_status: z.string().min(1).max(40).optional(),
      revenue_label: z.string().max(200).nullable().optional(),
      vehicle_class: vehicleClass.optional(),
    }).parse(request.body);
    return app.db.transaction(async (tx) => {
      await tx.select({ id: vehicles.id }).from(vehicles).where(eq(vehicles.id, vehicleId)).for("update");
      const [link] = await tx.select().from(organizationVehicles).where(and(eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, vehicleId))).limit(1).for("update");
      if (!link) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
      if (body.expected_status !== undefined && body.expected_status !== link.status) {
        throw new AppError(409, "vehicle_status_changed", "Vehicle status changed. Refresh and select the next status again.");
      }
      if (body.status === "sold") {
        throw new AppError(409, "handover_required", "Complete buyer handover to mark a showroom vehicle as sold.");
      }
      if (body.status !== link.status && !(transitions[link.lifecycleTemplate][link.status] ?? []).includes(body.status)) {
        throw new AppError(400, "invalid_status_transition", "Status transition is not allowed by the vehicle lifecycle template");
      }
      const [updated] = await tx.update(organizationVehicles).set({
        status: body.status,
        ...(body.revenue_label !== undefined ? { revenueLabel: body.revenue_label } : {}),
        updatedAt: new Date(),
      }).where(eq(organizationVehicles.id, link.id)).returning();
      const [vehicle] = body.vehicle_class !== undefined
        ? await tx.update(vehicles).set({ vehicleClass: body.vehicle_class, updatedAt: new Date() }).where(eq(vehicles.id, vehicleId)).returning()
        : await tx.select().from(vehicles).where(eq(vehicles.id, vehicleId)).limit(1);
      const payload = serializeOrganizationVehicle(updated, vehicle!);
      await recordChange(tx, { userId: actorId, entityType: "organization_vehicle", entityId: updated.id, op: "upsert", payload });
      return payload;
    });
  });

  app.post("/organizations/:id/assignments", async (request, reply) => {
    requireFleetPortal(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin", "org_manager"]);
    const body = z.object({ vehicle_id: uuid, driver_id: uuid }).parse(request.body);
    const [driver] = await app.db.select().from(organizationMembers).where(and(
      eq(organizationMembers.orgId, orgId), eq(organizationMembers.userId, body.driver_id), eq(organizationMembers.role, "org_driver"), eq(organizationMembers.status, "active"),
    )).limit(1);
    if (!driver) throw new AppError(422, "invalid_driver", "Driver must be an org_driver member of this organization");
    const [vehicle] = await app.db.select().from(organizationVehicles).where(and(
      eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, body.vehicle_id),
    )).limit(1);
    if (!vehicle) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
    const [assignment] = await app.db.insert(driverAssignments).values({
      id: newId(), orgId, vehicleId: body.vehicle_id, driverId: body.driver_id, assignedBy: actorId,
    }).onConflictDoNothing().returning();
    if (!assignment) throw new AppError(409, "assignment_already_active", "This driver already has access to this vehicle");
    return reply.code(201).send(serializeAssignment(assignment));
  });

  app.get("/organizations/:id/assignments", async (request) => {
    requireFleetPortal(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const { membership } = await getOrganizationAccess(app.db, uid(request), orgId);
    const conditions = [eq(driverAssignments.orgId, orgId)];
    if (membership.role === "org_driver") conditions.push(eq(driverAssignments.driverId, uid(request)));
    const rows = await app.db.select().from(driverAssignments).where(and(...conditions));
    return { items: rows.map(serializeAssignment) };
  });

  app.delete("/organizations/:id/assignments/:assignmentId", async (request, reply) => {
    requireFleetPortal(request);
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
    requireFleetPortal(request);
    const { id: rawOrgId, vehicleId } = request.params as { id: string; vehicleId: string };
    const orgId = uuid.parse(rawOrgId);
    const actorId = uid(request);
    const { organization } = await getOrganizationAccess(app.db, actorId, orgId, ["org_admin", "org_manager", "org_mechanic"]);
    const [orgVehicle] = await app.db.select().from(organizationVehicles).where(and(
      eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, vehicleId),
    )).limit(1);
    if (!orgVehicle) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
    const body = z.object({
      title: z.string().optional().nullable(),
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
      await lockCurrencyVehicle(tx,vehicleId,orgId);
      const [created] = await tx.insert(serviceRecords).values({
        currency: await incomingServiceCurrency(tx,request.body),
        id: serviceId, vehicleId, title: body.title ?? null, servicedOn: body.serviced_on, odometer: String(body.odometer), totalCost: String(body.total_cost),
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
      title: record.created.title,
      serviced_on: dateOnly(record.created.servicedOn),
      odometer: num(record.created.odometer),
      total_cost: reqNum(record.created.totalCost),
      currency: record.created.currency,
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

  app.get("/organizations/:id/vehicles/:vehicleId/service-records", async (request) => {
    requireFleetPortal(request);
    const { id: rawOrgId, vehicleId } = request.params as { id: string; vehicleId: string };
    const orgId = uuid.parse(rawOrgId);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager", "org_mechanic"]);
    const [orgVehicle] = await app.db.select().from(organizationVehicles).where(and(
      eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, vehicleId),
    )).limit(1);
    if (!orgVehicle) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
    const rows = await app.db.select().from(serviceRecords)
      .where(and(eq(serviceRecords.vehicleId, vehicleId), currentRecord(serviceRecords)))
      .orderBy(desc(serviceRecords.servicedOn));
    const items = [];
    for (const row of rows) {
      const recordItems = await app.db.select().from(serviceRecordItems)
        .where(eq(serviceRecordItems.serviceRecordId, row.id));
      items.push({
        id: row.id,
        vehicle_id: row.vehicleId,
        title: row.title,
        serviced_on: dateOnly(row.servicedOn),
        odometer: num(row.odometer),
        total_cost: reqNum(row.totalCost),
        workshop_name: row.workshopName,
        notes: row.notes,
        created_by: row.createdBy,
        items: recordItems.map((item) => ({
          id: item.id, name: item.name, line_cost: num(item.lineCost), plan_item_id: item.planItemId,
        })),
      });
    }
    return { items };
  });

  app.get("/organizations/:id/vehicles/:vehicleId/plan-items", async (request) => {
    requireFleetPortal(request);
    const { id: rawOrgId, vehicleId } = request.params as { id: string; vehicleId: string };
    const orgId = uuid.parse(rawOrgId);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager", "org_mechanic"]);
    const [orgVehicle] = await app.db.select().from(organizationVehicles).where(and(
      eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, vehicleId),
    )).limit(1);
    if (!orgVehicle) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
    const rows = await app.db.select().from(planItems).where(and(eq(planItems.vehicleId, vehicleId), currentRecord(planItems)));
    return { items: rows.map(publicPlan) };
  });

  app.get("/organizations/:id/maintenance-catalog", async (request) => {
    requireFleetPortal(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager", "org_mechanic"]);
    const rows = await app.db.select().from(maintenanceCatalog)
      .where(and(or(isNull(maintenanceCatalog.orgId), eq(maintenanceCatalog.orgId, orgId)), eq(maintenanceCatalog.enabled, true)))
      .orderBy(maintenanceCatalog.sortOrder, maintenanceCatalog.name);
    return { items: rows.map(row => ({ catalog_key: row.catalogKey, name: row.name, source: row.orgId ? "org" : "global" })) };
  });

  app.post("/organizations/:id/maintenance-catalog", async (request, reply) => {
    requireFleetPortal(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
    const body = z.object({ name: z.string().trim().min(1).max(80) }).strict().parse(request.body);
    const [row] = await app.db.insert(maintenanceCatalog).values({
      id: newId(), orgId, name: body.name,
      catalogKey: `${slugify(body.name)}__${newId()}`,
      fuelTypes: ["petrol", "electric", "hybrid_plugin"],
    }).returning();
    return reply.code(201).send({ catalog_key: row.catalogKey, name: row.name, source: "org" });
  });

  const reminderBody = z.object({
    id: uuid,
    name: z.string().trim().min(1).max(80),
    notes: z.string().trim().max(4000).nullable().optional(),
    catalog_key: z.string().nullable().optional(),
    interval_days: z.number().int().positive().nullable(),
    time_count: z.number().int().positive().nullable().optional(),
    time_unit: z.enum(["days", "months", "years"]).nullable().optional(),
    warning_days: z.number().int().min(0).nullable().optional(),
    warning_distance: z.number().min(0).nullable().optional(),
    interval_distance: z.number().positive().nullable(),
    next_due_on: z.string().date().nullable(),
    next_due_mileage: z.number().nonnegative().nullable(),
    enabled: z.boolean(),
  }).strict().superRefine((body, context) => {
    if (body.next_due_on === null && body.next_due_mileage === null)
      context.addIssue({ code: "custom", message: "Set a due date or mileage" });
    if (Boolean(body.time_count) !== Boolean(body.time_unit))
      context.addIssue({ code: "custom", message: "Choose a time count and unit together" });
    if ((body.interval_days !== null || body.time_count) && body.next_due_on === null)
      context.addIssue({ code: "custom", message: "Time repetition requires a first due date" });
    if (body.interval_distance !== null && body.next_due_mileage === null)
      context.addIssue({ code: "custom", message: "Distance repetition requires a first due mileage" });
    const recurring = body.interval_days !== null || body.time_count != null || body.interval_distance !== null;
    if (recurring && body.next_due_on !== null && body.interval_days === null && !body.time_count)
      context.addIssue({ code: "custom", path: ["time_count"], message: "Enter a repeat time" });
    if (recurring && body.next_due_mileage !== null && body.interval_distance === null)
      context.addIssue({ code: "custom", path: ["interval_distance"], message: "Enter a repeat distance" });
  });

  for (const method of ["POST", "PUT"] as const) {
    app.route({ method, url: "/organizations/:id/vehicles/:vehicleId/plan-items", handler: async (request, reply) => {
      requireFleetPortal(request);
      const { id, vehicleId } = request.params as { id: string; vehicleId: string };
      const orgId = uuid.parse(id);
      await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
      const body = reminderBody.parse(request.body);
      const row = await app.db.transaction(async tx => {
        const [vehicle] = await tx.select().from(organizationVehicles)
          .where(and(eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, vehicleId))).for("update");
        if (!vehicle) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
        const [existing] = await tx.select().from(planItems).where(and(eq(planItems.id, body.id), currentRecord(planItems)));
        if (existing && existing.vehicleId !== vehicleId) throw new AppError(404, "not_found", "Reminder not found");
        if (method === "PUT" && !existing) throw new AppError(404, "not_found", "Reminder not found");
        if (method === "POST" && existing) return existing;
        if (body.catalog_key) {
          if (body.catalog_key !== existing?.catalogKey) {
            const [catalog] = await tx.select().from(maintenanceCatalog).where(and(
              eq(maintenanceCatalog.catalogKey, body.catalog_key), or(isNull(maintenanceCatalog.orgId), eq(maintenanceCatalog.orgId, orgId)), eq(maintenanceCatalog.enabled, true)));
            if (!catalog) throw new AppError(422, "invalid_catalog_item", "Select an available service item");
          }
          const [duplicate] = await tx.select().from(planItems).where(and(
            eq(planItems.vehicleId, vehicleId), eq(planItems.catalogKey, body.catalog_key), eq(planItems.enabled, true), currentRecord(planItems)));
          if (body.enabled && duplicate && duplicate.id !== body.id)
            throw new AppError(409, "reminder_exists", "This service already has an active reminder");
        }
        const values = { name: body.name, notes: body.notes === undefined ? existing?.notes ?? null : body.notes, catalogKey: body.catalog_key ?? null,
          intervalDays: body.interval_days, timeCount: body.time_count ?? null, timeUnit: body.time_unit ?? null,
          warningDays: body.warning_days ?? null, warningDistance: body.warning_distance == null ? null : String(body.warning_distance), intervalDistance: body.interval_distance === null ? null : String(body.interval_distance),
          nextDueOn: body.next_due_on, nextDueMileage: body.next_due_mileage === null ? null : String(body.next_due_mileage), enabled: body.enabled };
        const [saved] = existing
          ? await tx.update(planItems).set(values).where(and(eq(planItems.id, body.id), currentRecord(planItems))).returning()
          : await tx.insert(planItems).values({ ...values, id: body.id, vehicleId, createdBy: uid(request) }).returning();
        await tx.execute(sql`INSERT INTO plan_schedule_baselines(plan_item_id,next_due_on,next_due_mileage)
          VALUES (${saved.id},${saved.nextDueOn},${saved.nextDueMileage}) ON CONFLICT (plan_item_id)
          DO UPDATE SET next_due_on=excluded.next_due_on,next_due_mileage=excluded.next_due_mileage`);
        await saveReminderBaseline(tx as Db, saved.id, Boolean(existing));
        const [withBaseline] = await tx.select().from(planItems).where(and(eq(planItems.id, saved.id), currentRecord(planItems)));
        return withBaseline;
      });
      return reply.code(method === "POST" ? 201 : 200).send(publicPlan(row));
    }});
  }

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
      plan_item_id: uuid.nullable().optional(),
    }).parse(request.body);
    const [assignment] = await app.db.select().from(driverAssignments).where(and(
      eq(driverAssignments.orgId, orgId), eq(driverAssignments.vehicleId, body.vehicle_id),
      eq(driverAssignments.driverId, actorId), eq(driverAssignments.status, "active"),
    )).limit(1);
    if (!assignment) throw new AppError(403, "not_assigned_to_vehicle", "Driver is not assigned to this vehicle");
    if (body.plan_item_id) {
      const [planItem] = await app.db.select().from(planItems).where(and(
        eq(planItems.id, body.plan_item_id), eq(planItems.vehicleId, body.vehicle_id), currentRecord(planItems),
      )).limit(1);
      if (!planItem) throw new AppError(422, "invalid_plan_item", "Plan item must belong to the assigned vehicle");
    }
    const [workOrder] = await app.db.insert(workOrders).values({
      id: newId(), orgId, vehicleId: body.vehicle_id, reportedBy: actorId, odometerKm: body.odometer_km,
      issueType: body.issue_type, description: body.description, urgency: body.urgency, photos: body.photos,
      planItemId: body.plan_item_id ?? null,
    }).returning();
    return reply.code(201).send(serializeWorkOrder(workOrder));
  });

  app.get("/organizations/:id/work-orders", async (request) => {
    requireFleetPortal(request);
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
      eq(organizationMembers.userId, userId), eq(organizationMembers.role, "org_driver"), eq(organizationMembers.status, "active"),
    )).limit(1);
    if (!membership) throw new AppError(403, "driver_mode_required", "An organization driver membership is required");
    await getOrganizationAccess(app.db, userId, membership.orgId, ["org_driver"]);
    const rows = await app.db.select().from(workOrders).where(and(eq(workOrders.orgId, membership.orgId), eq(workOrders.reportedBy, userId)));
    return { items: rows.map(serializeWorkOrder) };
  });

  app.patch("/organizations/:id/work-orders/:workOrderId", async (request) => {
    requireFleetPortal(request);
    const { id: rawOrgId, workOrderId } = request.params as { id: string; workOrderId: string };
    const orgId = uuid.parse(rawOrgId);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin", "org_manager"]);
    const body = z.object({
      status: z.enum(["in_progress", "completed"]),
      assigned_to: uuid.optional().nullable(),
      resolution_notes: z.string().max(2000).optional().nullable(),
      completion_cost: z.number().min(0).optional(),
      parts: z.array(z.object({
        part_id: uuid.nullable().optional(),
        name: z.string().min(1).max(200),
      })).max(50).optional(),
    }).parse(request.body);
    const [current] = await app.db.select().from(workOrders).where(and(eq(workOrders.id, workOrderId), eq(workOrders.orgId, orgId))).limit(1);
    if (!current) throw new AppError(404, "work_order_not_found", "Work order not found");
    const allowed = current.status === "reported" ? body.status === "in_progress" : current.status === "in_progress" && body.status === "completed";
    if (!allowed) throw new AppError(400, "invalid_work_order_status", "Work order must advance reported → in_progress → completed");
    if (body.assigned_to) {
      const [assignee] = await app.db.select().from(organizationMembers).where(and(
        eq(organizationMembers.orgId, orgId), eq(organizationMembers.userId, body.assigned_to), inArray(organizationMembers.role, ["org_manager", "org_mechanic"]), eq(organizationMembers.status, "active"),
      )).limit(1);
      if (!assignee) throw new AppError(422, "invalid_assignee", "Work order assignee must be a mechanic or manager in this organization");
    }
    // Confirmed Access Decision 19: completion requires cost and auto-creates a
    // service record at the report-time odometer (stale by design — chosen over
    // a fresh entry). Parts may be free-text names (part_id nullable).
    if (body.status === "completed" && body.completion_cost === undefined) {
      throw new AppError(400, "completion_cost_required", "Work order completion requires a completion cost");
    }
    if (body.status !== "completed") {
      const [updated] = await app.db.update(workOrders).set({
        status: body.status,
        ...(body.assigned_to !== undefined ? { assignedTo: body.assigned_to } : {}),
        updatedAt: new Date(),
      }).where(eq(workOrders.id, current.id)).returning();
      return serializeWorkOrder(updated);
    }
    const parts = body.parts ?? [];
    for (const part of parts) {
      if (!part.part_id) continue;
      const [partRow] = await app.db.select().from(partsTable).where(and(
        eq(partsTable.id, part.part_id), eq(partsTable.vehicleId, current.vehicleId), currentRecord(partsTable),
      )).limit(1);
      if (!partRow) throw new AppError(422, "invalid_part", "Part must belong to the work order's vehicle");
    }
    const completionCost = body.completion_cost!;
    const serviceId = newId();
    const servicedOn = new Date().toISOString().slice(0, 10);
    const result = await app.db.transaction(async (tx) => {
      await lockCurrencyVehicle(tx,current.vehicleId,orgId);
      const [lockedOrder] = await tx.select().from(workOrders).where(eq(workOrders.id,current.id)).for('update');
      if (!lockedOrder || lockedOrder.status !== 'in_progress') throw new AppError(409,'work_order_changed','Work order was already completed or changed');
      const [createdService] = await tx.insert(serviceRecords).values({
        currency: await incomingServiceCurrency(tx,request.body),
        id: serviceId,
        vehicleId: current.vehicleId,
        servicedOn,
        odometer: String(current.odometerKm),
        totalCost: String(completionCost),
        notes: body.resolution_notes ?? null,
        createdBy: actorId,
      }).returning();
      const createdParts = [];
      for (const part of parts) {
        const [createdPart] = await tx.insert(serviceRecordParts).values({
          id: newId(),
          serviceRecordId: serviceId,
          partId: part.part_id ?? null,
          name: part.name,
        }).returning();
        createdParts.push(createdPart);
      }
      const [updatedWo] = await tx.update(workOrders).set({
        status: "completed",
        ...(body.assigned_to !== undefined ? { assignedTo: body.assigned_to } : {}),
        resolvedBy: actorId,
        resolvedAt: new Date(),
        resolutionNotes: body.resolution_notes ?? null,
        completionCost: String(completionCost),
        currency: createdService.currency,
        updatedAt: new Date(),
      }).where(eq(workOrders.id, current.id)).returning();
      if (current.planItemId) {
        await advancePlanItemForLog(tx, current.vehicleId, current.planItemId, current.odometerKm, servicedOn);
      }
      return { service: createdService, parts: createdParts, workOrder: updatedWo };
    });
    return {
      ...serializeWorkOrder(result.workOrder),
      service_record: {
        id: result.service.id,
        vehicle_id: result.service.vehicleId,
        serviced_on: dateOnly(result.service.servicedOn),
        odometer: reqNum(result.service.odometer),
        total_cost: reqNum(result.service.totalCost),
        currency: result.service.currency,
        notes: result.service.notes,
        parts: result.parts.map((part) => ({ id: part.id, name: part.name, part_id: part.partId })),
      },
    };
  });

  app.post("/drivers/vehicles/:vehicleId/service-records", async (request, reply) => {
    requireFleetClient(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const actorId = uid(request);
    const [assignment] = await app.db.select().from(driverAssignments).where(and(
      eq(driverAssignments.vehicleId, vehicleId), eq(driverAssignments.driverId, actorId), eq(driverAssignments.status, "active"),
    )).limit(1);
    if (!assignment) throw new AppError(403, "not_assigned_to_vehicle", "Driver is not assigned to this vehicle");
    const orgId = assignment.orgId;
    await getOrganizationAccess(app.db, actorId, orgId, ["org_driver"]);
    const body = z.object({
      id: uuid.optional(),
      title: z.string().optional().nullable(),
      serviced_on: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      odometer_km: z.number().min(0),
      total_cost: z.number().min(0),
      plan_item_id: uuid.nullable().optional(),
      name: z.string().min(1).max(100).optional(),
      notes: z.string().max(2000).optional().nullable(),
      receipt_media_id: uuid.nullable().optional(),
    }).parse(request.body);
    const [orgVehicle] = await app.db.select().from(organizationVehicles).where(and(
      eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, vehicleId),
    )).limit(1);
    if (!orgVehicle) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
    const [fleetVehicle] = await app.db.select().from(vehicles).where(eq(vehicles.id, vehicleId)).limit(1);
    if (!fleetVehicle || body.odometer_km < reqNum(fleetVehicle.mileage)) {
      throw new AppError(400, "odometer_regression", "Odometer cannot be lower than the last recorded vehicle mileage");
    }
    let itemName: string;
    if (body.plan_item_id) {
      const [planItem] = await app.db.select().from(planItems).where(and(
        eq(planItems.id, body.plan_item_id), eq(planItems.vehicleId, vehicleId), currentRecord(planItems),
      )).limit(1);
      if (!planItem) throw new AppError(422, "invalid_plan_item", "Plan item must belong to the assigned vehicle");
      itemName = planItem.name;
    } else if (body.name) {
      itemName = body.name;
    } else {
      throw new AppError(422, "service_item_required", "Provide a plan item or a free-text item name");
    }
    const serviceId = body.id ?? newId();
    const [existing] = await app.db.select().from(serviceRecords).where(and(eq(serviceRecords.id, serviceId), currentRecord(serviceRecords))).limit(1);
    if (existing) return reply.code(201).send({ id: existing.id, duplicate: true });
    const record = await app.db.transaction(async (tx) => {
      await lockCurrencyVehicle(tx,vehicleId,orgId);
      const [created] = await tx.insert(serviceRecords).values({
        currency: await incomingServiceCurrency(tx,request.body),
        id: serviceId,
        vehicleId,
        title: body.title ?? null,
        servicedOn: body.serviced_on,
        odometer: String(body.odometer_km),
        totalCost: String(body.total_cost),
        notes: body.notes ?? null,
        receiptMediaId: body.receipt_media_id ?? null,
        createdBy: actorId,
      }).returning();
      const [item] = await tx.insert(serviceRecordItems).values({
        id: newId(),
        serviceRecordId: serviceId,
        planItemId: body.plan_item_id ?? null,
        name: itemName,
        lineCost: String(body.total_cost),
      }).returning();
      await tx.update(vehicles).set({ mileage: String(body.odometer_km), updatedAt: new Date() }).where(eq(vehicles.id, vehicleId));
      if (body.plan_item_id) {
        await advancePlanItemForLog(tx, vehicleId, body.plan_item_id, body.odometer_km, body.serviced_on);
      }
      return { created, items: [item] };
    });
    const payload = {
      id: record.created.id,
      vehicle_id: vehicleId,
      title: record.created.title,
      serviced_on: dateOnly(record.created.servicedOn),
      odometer: num(record.created.odometer),
      total_cost: reqNum(record.created.totalCost),
      currency: record.created.currency,
      notes: record.created.notes,
      items: record.items.map((item) => ({
        id: item.id, name: item.name, line_cost: num(item.lineCost), plan_item_id: item.planItemId,
      })),
    };
    await recordChange(app.db, { userId: actorId, entityType: "service_record", entityId: serviceId, op: "upsert", payload });
    return reply.code(201).send(payload);
  });

  async function requireDriverAssignment(vehicleId: string, userId: string) {
    const [assignment] = await app.db.select().from(driverAssignments).where(and(
      eq(driverAssignments.vehicleId, vehicleId),
      eq(driverAssignments.driverId, userId),
      eq(driverAssignments.status, "active"),
    )).limit(1);
    if (!assignment) throw new AppError(403, "driver_not_assigned", "No active vehicle assignment");
    return assignment;
  }

  app.get("/drivers/vehicles/:vehicleId/plan-items", async (request) => {
    requireFleetClient(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await requireDriverAssignment(vehicleId, uid(request));
    const items = await app.db.select().from(planItems).where(and(eq(planItems.vehicleId, vehicleId), currentRecord(planItems)));
    return { items: items.map(publicPlan) };
  });

  app.post("/drivers/vehicles/:vehicleId/plan-items", async (request) => {
    requireFleetClient(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await requireDriverAssignment(vehicleId, uid(request));
    throw new AppError(403, "plan_managed_by_admin", "Maintenance plans are managed by Fleet Admin");
  });

  app.get("/drivers/vehicles/:vehicleId/service-records", async (request) => {
    requireFleetClient(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await requireDriverAssignment(vehicleId, uid(request));
    const rows = await app.db.select().from(serviceRecords)
      .where(and(eq(serviceRecords.vehicleId, vehicleId), currentRecord(serviceRecords)))
      .orderBy(desc(serviceRecords.servicedOn));
    const items = [];
    for (const row of rows) {
      const recordItems = await app.db.select().from(serviceRecordItems)
        .where(eq(serviceRecordItems.serviceRecordId, row.id));
      items.push({
        id: row.id,
        vehicle_id: row.vehicleId,
        title: row.title,
        serviced_on: dateOnly(row.servicedOn),
        odometer: num(row.odometer),
        total_cost: reqNum(row.totalCost),
        workshop_name: row.workshopName,
        notes: row.notes,
        created_by: row.createdBy,
        items: recordItems.map((item) => ({
          id: item.id, name: item.name, line_cost: num(item.lineCost), plan_item_id: item.planItemId,
        })),
      });
    }
    return { items };
  });

  app.get("/drivers/vehicles/:vehicleId/suggested-plan-items", async (request) => {
    requireFleetClient(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const assignment = await requireDriverAssignment(vehicleId, uid(request));
    const rows = await app.db.select().from(maintenanceCatalog)
      .where(and(eq(maintenanceCatalog.enabled, true), or(isNull(maintenanceCatalog.orgId), eq(maintenanceCatalog.orgId, assignment.orgId))))
      .orderBy(maintenanceCatalog.sortOrder, maintenanceCatalog.name);
    return { items: rows.map((row) => ({ catalog_key: row.catalogKey, name: row.name })) };
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

async function advancePlanItemForLog(
  tx: Parameters<Parameters<Db["transaction"]>[0]>[0],
  vehicleId: string,
  planItemId: string,
  odometerKm: number,
  servicedOn: string,
) {
  const rows = await recalculateReminders(tx as Db, vehicleId);
  return rows.find(row => row.id === planItemId) ?? null;
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
    plan_item_id: row.planItemId,
    completion_cost: num(row.completionCost),
    currency: row.currency,
    assigned_to: row.assignedTo,
    resolved_by: row.resolvedBy,
    resolved_at: iso(row.resolvedAt),
    resolution_notes: row.resolutionNotes,
    created_at: iso(row.createdAt),
    updated_at: iso(row.updatedAt),
  };
}
