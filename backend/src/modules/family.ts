import { and, asc, desc, eq, isNull, sql } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import {
  documents,
  drivingLicenses,
  families,
  familyMemberships,
  familyVehicles,
  mediaObjects,
  organizationVehicles,
  users,
  vehicleGrants,
  vehicles,
} from "../db/schema.js";
import { newId, randomToken, sha256 } from "../lib/crypto.js";
import { dateOnly, iso, num, recordChange, reqNum } from "../lib/dbx.js";
import { publicUser, publicVehicle } from "../lib/serialize.js";
import { AppError } from "../lib/errors.js";
import { requireOwner } from "./auth.js";

const uuid = z.string().uuid();

async function requirePremiumPlan(db: Db, userId: string): Promise<void> {
  const [user] = await db.select({ plan: users.plan }).from(users).where(eq(users.id, userId)).limit(1);
  if (!user || user.plan !== "premium") {
    throw new AppError(403, "premium_required", "Premium is required to create or manage a family");
  }
}

async function requirePremiumForPrimaryOwner(db: Db, userId: string, role: string): Promise<void> {
  if (role === "primary_owner") await requirePremiumPlan(db, userId);
}

function generateShareCode(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let code = "";
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

function publicFamily(row: typeof families.$inferSelect) {
  return {
    id: row.id,
    name: row.name,
    share_code: row.shareCode,
    qr_code_data: row.qrCodeData,
    status: row.status,
    created_by: row.createdBy,
    created_at: iso(row.createdAt),
    archived_at: iso(row.archivedAt),
  };
}

function publicFamilyMember(row: typeof familyMemberships.$inferSelect, user: typeof users.$inferSelect, vehicleCount: number, licenseStatus: string | null) {
  return {
    id: row.id,
    user_id: row.userId,
    email: user.email,
    display_name: user.displayName,
    role: row.role,
    joined_at: iso(row.joinedAt),
    invited_by: row.invitedBy,
    vehicle_count: vehicleCount,
    license_status: licenseStatus,
  };
}

function publicVehicleGrant(row: typeof vehicleGrants.$inferSelect) {
  return {
    id: row.id,
    vehicle_id: row.vehicleId,
    user_id: row.userId,
    granted_by: row.grantedBy,
    permission: row.permission,
    created_at: iso(row.createdAt),
  };
}

function publicDrivingLicense(row: typeof drivingLicenses.$inferSelect) {
  return {
    id: row.id,
    user_id: row.userId,
    license_number: row.licenseNumber,
    issuing_country: row.issuingCountry,
    expiry_date: dateOnly(row.expiryDate),
    categories: row.categories,
    front_media_id: row.frontMediaId,
    back_media_id: row.backMediaId,
    created_at: iso(row.createdAt),
    updated_at: iso(row.updatedAt),
  };
}

async function getLicenseStatus(db: Db, userId: string): Promise<string | null> {
  const [license] = await db.select().from(drivingLicenses).where(eq(drivingLicenses.userId, userId)).limit(1);
  if (!license) return null;
  const today = new Date();
  const expiry = new Date(license.expiryDate);
  const diffDays = Math.ceil((expiry.getTime() - today.getTime()) / 86400000);
  if (diffDays < 0) return "expired";
  if (diffDays <= 14) return "expiring_soon";
  return "valid";
}

export const familyPlugin: FastifyPluginAsync = async (app) => {
  const db = () => app.db;
  const uid = (request: { authUser?: { sub: string } }) => request.authUser!.sub;

  // Create family
  app.post("/families", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    await requirePremiumPlan(db(), userId);
    const body = z.object({ name: z.string().min(1).max(100) }).parse(request.body);

    // Check if user already in a family
    const [existing] = await db().select().from(familyMemberships).where(eq(familyMemberships.userId, userId)).limit(1);
    if (existing) throw new AppError(409, "already_in_family", "User is already a member of a family");

    const shareCode = generateShareCode();
    const familyId = newId();
    const qrCodeData = { code: shareCode, family_id: familyId, expires_at: new Date(Date.now() + 7 * 86400000).toISOString() };

    const [family] = await db().insert(families).values({
      id: familyId,
      name: body.name,
      shareCode,
      qrCodeData,
      createdBy: userId,
    }).returning();

    // Create primary owner membership
    await db().insert(familyMemberships).values({
      id: newId(),
      familyId,
      userId,
      role: "primary_owner",
      invitedBy: userId,
    });

    // Update user's family_id
    await db().update(users).set({ familyId }).where(eq(users.id, userId));

    await recordChange(db(), { userId, entityType: "family", entityId: familyId, op: "upsert", payload: publicFamily(family) });
    await recordChange(db(), { userId, entityType: "family_membership", entityId: familyId, op: "upsert", payload: { family_id: familyId, user_id: userId, role: "primary_owner" } });

    return reply.code(201).send(publicFamily(family));
  });

  // Get my family
  app.get("/families/me", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const [membership] = await db().select().from(familyMemberships).where(eq(familyMemberships.userId, userId)).limit(1);
    if (!membership) throw new AppError(404, "no_family", "Not a member of any family");

    const [family] = await db().select().from(families).where(eq(families.id, membership.familyId)).limit(1);
    if (!family || family.status === "archived") throw new AppError(404, "no_family", "Not a member of any family");

    const [fvCount] = await db().select({ count: sql`count(*)` })
      .from(familyVehicles)
      .where(eq(familyVehicles.familyId, family.id));

    return { ...publicFamily(family), my_role: membership.role, vehicle_count: Number(fvCount?.count ?? 0) };
  });

  // Lookup family by share code
  app.get("/families/:code", async (request) => {
    requireOwner(request);
    const code = (request.params as { code: string }).code.toUpperCase();
    const [family] = await db().select().from(families).where(and(eq(families.shareCode, code), eq(families.status, "active"))).limit(1);
    if (!family) throw new AppError(404, "family_not_found", "Invalid or expired share code");

    const memberCount = await db().select({ count: sql`count(*)` }).from(familyMemberships).where(eq(familyMemberships.familyId, family.id));
    const vehicleCount = await db().select({ count: sql`count(*)` }).from(vehicles).where(and(eq(vehicles.userId, familyMemberships.userId), eq(vehicles.archived, false)));

    return {
      id: family.id,
      name: family.name,
      member_count: Number(memberCount[0]?.count ?? 0),
      vehicle_count: Number(vehicleCount[0]?.count ?? 0),
    };
  });

  // Join family by code
  app.post("/families/:id/join", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const body = z.object({ code: z.string().min(8).max(8) }).parse(request.body);
    const code = body.code.toUpperCase();

    // Check if user already in a family
    const [existing] = await db().select().from(familyMemberships).where(eq(familyMemberships.userId, userId)).limit(1);
    if (existing) throw new AppError(409, "already_in_family", "User is already a member of a family");

    const [family] = await db().select().from(families).where(and(eq(families.shareCode, code), eq(families.status, "active"))).limit(1);
    if (!family) throw new AppError(404, "family_not_found", "Invalid or expired share code");

    // Default to member role; Primary Owner can change later
    const membershipId = newId();
    await db().insert(familyMemberships).values({
      id: membershipId,
      familyId: family.id,
      userId,
      role: "member",
      invitedBy: family.createdBy,
    });

    // Update user's family_id
    await db().update(users).set({ familyId: family.id }).where(eq(users.id, userId));

    await recordChange(db(), { userId, entityType: "family_membership", entityId: membershipId, op: "upsert", payload: { family_id: family.id, user_id: userId, role: "member" } });

    return { ...publicFamily(family), my_role: "member" };
  });

  // Update family (Primary Owner only)
  app.patch("/families/:id", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const familyId = (request.params as { id: string }).id;
    const body = z.object({ name: z.string().min(1).max(100).optional(), regenerate_share_code: z.boolean().default(false) }).parse(request.body);

    // Verify Primary Owner
    const [membership] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.userId, userId))).limit(1);
    if (!membership || membership.role !== "primary_owner") throw new AppError(403, "not_primary_owner", "Only the Primary Owner can update the family");
    await requirePremiumPlan(db(), userId);

    const updates: Record<string, unknown> = {};
    if (body.name) updates.name = body.name;
    if (body.regenerate_share_code) {
      updates.shareCode = generateShareCode();
      updates.qrCodeData = { code: updates.shareCode, family_id: familyId, expires_at: new Date(Date.now() + 7 * 86400000).toISOString() };
    }

    const [family] = await db().update(families).set(updates).where(eq(families.id, familyId)).returning();
    await recordChange(db(), { userId, entityType: "family", entityId: familyId, op: "upsert", payload: publicFamily(family) });

    return publicFamily(family);
  });

  // Archive family (Primary Owner only)
  app.delete("/families/:id", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const familyId = (request.params as { id: string }).id;

    // Verify Primary Owner
    const [membership] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.userId, userId))).limit(1);
    if (!membership || membership.role !== "primary_owner") throw new AppError(403, "not_primary_owner", "Only the Primary Owner can archive the family");
    await requirePremiumPlan(db(), userId);

    // Check if ownership was transferred (there should be another primary_owner)
    const [otherPrimary] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.role, "primary_owner"), sql`${familyMemberships.userId} != ${userId}`)).limit(1);
    if (!otherPrimary) throw new AppError(409, "transfer_required", "Transfer Primary Ownership to another member before archiving");

    await db().update(families).set({ status: "archived", archivedAt: new Date() }).where(eq(families.id, familyId));
    await recordChange(db(), { userId, entityType: "family", entityId: familyId, op: "archive", payload: { id: familyId, status: "archived" } });

    return reply.code(204).send();
  });

  // List family members
  app.get("/families/:id/members", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const familyId = (request.params as { id: string }).id;

    // Verify membership
    const [myMembership] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.userId, userId))).limit(1);
    if (!myMembership) throw new AppError(403, "not_family_member", "Not a member of this family");

    const members = await db().select().from(familyMemberships).where(eq(familyMemberships.familyId, familyId));
    const result = [];
    for (const member of members) {
      const [user] = await db().select().from(users).where(eq(users.id, member.userId)).limit(1);
      const vehicleCount = await db().select({ count: sql`count(*)` }).from(vehicles).where(and(eq(vehicles.userId, member.userId), eq(vehicles.archived, false)));
      const licenseStatus = await getLicenseStatus(db(), member.userId);
      result.push(publicFamilyMember(member, user!, Number(vehicleCount[0]?.count ?? 0), licenseStatus));
    }
    return result;
  });

  // Update member role or remove (Primary Owner only)
  app.patch("/families/:id/members/:userId", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const familyId = (request.params as { id: string }).id;
    const targetUserId = (request.params as { userId: string }).userId;
    const body = z.object({ role: z.enum(["primary_owner", "member", "driver"]) }).parse(request.body);

    // Verify Primary Owner
    const [myMembership] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.userId, userId))).limit(1);
    if (!myMembership || myMembership.role !== "primary_owner") throw new AppError(403, "not_primary_owner", "Only the Primary Owner can manage members");
    await requirePremiumPlan(db(), userId);

    // Cannot change Primary Owner role via this endpoint
    const [targetMembership] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.userId, targetUserId))).limit(1);
    if (!targetMembership) throw new AppError(404, "member_not_found", "Member not found in this family");
    if (targetMembership.role === "primary_owner") throw new AppError(409, "cannot_change_primary", "Cannot change Primary Owner role. Use ownership transfer.");

    if (body.role === "primary_owner") throw new AppError(400, "invalid_role", "Cannot set role to primary_owner via this endpoint");

    const [updated] = await db().update(familyMemberships).set({ role: body.role }).where(eq(familyMemberships.id, targetMembership.id)).returning();
    await recordChange(db(), { userId, entityType: "family_membership", entityId: targetMembership.id, op: "upsert", payload: { family_id: familyId, user_id: targetUserId, role: body.role } });

    // Update user's family_id (stays the same)
    const [user] = await db().select().from(users).where(eq(users.id, targetUserId)).limit(1);
    const vehicleCount = await db().select({ count: sql`count(*)` }).from(vehicles).where(and(eq(vehicles.userId, targetUserId), eq(vehicles.archived, false)));
    const licenseStatus = await getLicenseStatus(db(), targetUserId);

    return publicFamilyMember(updated, user!, Number(vehicleCount[0]?.count ?? 0), licenseStatus);
  });

  // Remove member (Primary Owner only)
  app.delete("/families/:id/members/:userId", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const familyId = (request.params as { id: string }).id;
    const targetUserId = (request.params as { userId: string }).userId;

    // Verify Primary Owner
    const [myMembership] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.userId, userId))).limit(1);
    if (!myMembership || myMembership.role !== "primary_owner") throw new AppError(403, "not_primary_owner", "Only the Primary Owner can remove members");
    await requirePremiumPlan(db(), userId);

    const [targetMembership] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.userId, targetUserId))).limit(1);
    if (!targetMembership) throw new AppError(404, "member_not_found", "Member not found in this family");
    if (targetMembership.role === "primary_owner") throw new AppError(409, "cannot_remove_primary", "Cannot remove Primary Owner. Transfer ownership first.");

    // Revoke all vehicle grants for this user in this family
    await db().delete(vehicleGrants).where(and(eq(vehicleGrants.userId, targetUserId), sql`${vehicleGrants.vehicleId} IN (SELECT id FROM ${vehicles} WHERE ${vehicles.userId} IN (SELECT user_id FROM ${familyMemberships} WHERE ${familyMemberships.familyId} = ${familyId}))`));
    
    await db().delete(familyMemberships).where(eq(familyMemberships.id, targetMembership.id));
    await db().update(users).set({ familyId: null }).where(eq(users.id, targetUserId));

    await recordChange(db(), { userId, entityType: "family_membership", entityId: targetMembership.id, op: "delete", payload: { family_id: familyId, user_id: targetUserId } });

    return reply.code(204).send();
  });

  // Grant vehicle access (Primary Owner or Member with full grant)
  app.post("/families/:id/vehicle-grants", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const familyId = (request.params as { id: string }).id;
    const body = z.object({ vehicle_id: uuid, user_id: uuid, permission: z.enum(["full", "drive_only"]) }).parse(request.body);

    // Verify membership
    const [myMembership] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.userId, userId))).limit(1);
    if (!myMembership) throw new AppError(403, "not_family_member", "Not a member of this family");
    await requirePremiumForPrimaryOwner(db(), userId, myMembership.role);

    // Verify target is family member
    const [targetMembership] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.userId, body.user_id))).limit(1);
    if (!targetMembership) throw new AppError(404, "member_not_found", "Target user is not a member of this family");

    // Verify vehicle belongs to family (owned by a family member)
    const [vehicle] = await db().select().from(vehicles).where(and(eq(vehicles.id, body.vehicle_id), eq(vehicles.archived, false))).limit(1);
    if (!vehicle) throw new AppError(404, "vehicle_not_found", "Vehicle not found");

    const [vehicleOwnerMembership] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.userId, vehicle.userId))).limit(1);
    if (!vehicleOwnerMembership) throw new AppError(403, "vehicle_not_in_family", "Vehicle is not part of this family");

    // Check grantor has permission to grant
    if (myMembership.role !== "primary_owner") {
      const [grantorGrant] = await db().select().from(vehicleGrants).where(and(eq(vehicleGrants.vehicleId, body.vehicle_id), eq(vehicleGrants.userId, userId), eq(vehicleGrants.permission, "full"))).limit(1);
      if (!grantorGrant) throw new AppError(403, "insufficient_permission", "You need full access to this vehicle to grant access to others");
    }

    // Cannot grant to vehicle owner (they have implicit full access)
    if (vehicle.userId === body.user_id) throw new AppError(409, "grant_not_needed", "Vehicle owner has implicit full access");

    const [existingGrant] = await db().select().from(vehicleGrants).where(and(eq(vehicleGrants.vehicleId, body.vehicle_id), eq(vehicleGrants.userId, body.user_id))).limit(1);
    if (existingGrant) throw new AppError(409, "grant_exists", "Grant already exists for this user and vehicle");

    const grantId = newId();
    const [grant] = await db().insert(vehicleGrants).values({
      id: grantId,
      vehicleId: body.vehicle_id,
      userId: body.user_id,
      grantedBy: userId,
      permission: body.permission,
    }).returning();

    await recordChange(db(), { userId, entityType: "vehicle_grant", entityId: grantId, op: "upsert", payload: publicVehicleGrant(grant) });

    return reply.code(201).send(publicVehicleGrant(grant));
  });

  // Revoke vehicle grant (Primary Owner or grantor)
  app.delete("/families/:id/vehicle-grants/:grantId", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const familyId = (request.params as { id: string }).id;
    const grantId = (request.params as { grantId: string }).grantId;

    // Verify membership
    const [myMembership] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.userId, userId))).limit(1);
    if (!myMembership) throw new AppError(403, "not_family_member", "Not a member of this family");
    await requirePremiumForPrimaryOwner(db(), userId, myMembership.role);

    const [grant] = await db().select().from(vehicleGrants).where(eq(vehicleGrants.id, grantId)).limit(1);
    if (!grant) throw new AppError(404, "grant_not_found", "Grant not found");

    // Verify grant is for a vehicle in this family
    const [vehicle] = await db().select().from(vehicles).where(and(eq(vehicles.id, grant.vehicleId), eq(vehicles.archived, false))).limit(1);
    if (!vehicle) throw new AppError(404, "vehicle_not_found", "Vehicle not found");

    const [vehicleOwnerMembership] = await db().select().from(familyMemberships).where(and(eq(familyMemberships.familyId, familyId), eq(familyMemberships.userId, vehicle.userId))).limit(1);
    if (!vehicleOwnerMembership) throw new AppError(403, "grant_not_in_family", "Grant is not for a vehicle in this family");

    // Only Primary Owner or grantor can revoke
    if (myMembership.role !== "primary_owner" && grant.grantedBy !== userId) {
      throw new AppError(403, "not_authorized", "Only Primary Owner or grantor can revoke this grant");
    }

    await db().delete(vehicleGrants).where(eq(vehicleGrants.id, grantId));
    await recordChange(db(), { userId, entityType: "vehicle_grant", entityId: grantId, op: "delete", payload: { vehicle_id: grant.vehicleId, user_id: grant.userId } });

    return reply.code(204).send();
  });

  // ─── Family Vehicles ────────────────────────────────────────────────

  // List family vehicles
  app.get("/families/me/vehicles", async (request) => {
    requireOwner(request);
    const userId = uid(request);

    const [membership] = await db().select().from(familyMemberships)
      .where(eq(familyMemberships.userId, userId)).limit(1);
    if (!membership) throw new AppError(404, "no_family", "Not a member of any family");

    if (membership.role === "primary_owner") {
      // Owner sees all their non-archived vehicles that are in family_vehicles
      const rows = await db().select({
        vehicle: vehicles,
        fv: familyVehicles,
      })
        .from(familyVehicles)
        .innerJoin(vehicles, eq(familyVehicles.vehicleId, vehicles.id))
        .where(
          and(
            eq(familyVehicles.familyId, membership.familyId),
            eq(vehicles.userId, userId),
            eq(vehicles.archived, false),
          ),
        );

      return {
        items: rows.map((r) => ({
          ...publicVehicle(r.vehicle),
          source: "family",
          permission: null,
        })),
      };
    }

    // Member/Driver sees vehicles they have grants for that are in family_vehicles
    const rows = await db().select({
      vehicle: vehicles,
      grant: vehicleGrants,
    })
      .from(vehicleGrants)
      .innerJoin(vehicles, eq(vehicleGrants.vehicleId, vehicles.id))
      .innerJoin(familyVehicles, eq(familyVehicles.vehicleId, vehicles.id))
      .where(
        and(
          eq(vehicleGrants.userId, userId),
          eq(familyVehicles.familyId, membership.familyId),
          eq(vehicles.archived, false),
        ),
      );

    return {
      items: rows.map((r) => ({
        ...publicVehicle(r.vehicle),
        source: "family",
        permission: r.grant.permission,
      })),
    };
  });

  // Add vehicle to family (Primary Owner only)
  app.post("/families/me/vehicles", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const body = z.object({ vehicle_id: uuid }).parse(request.body);

    const [membership] = await db().select().from(familyMemberships)
      .where(and(eq(familyMemberships.userId, userId), eq(familyMemberships.role, "primary_owner"))).limit(1);
    if (!membership) throw new AppError(403, "not_primary_owner", "Only Primary Owner can add vehicles");
    await requirePremiumPlan(db(), userId);

    // Verify vehicle belongs to the requesting user and is not archived
    const [vehicle] = await db().select().from(vehicles)
      .where(and(eq(vehicles.id, body.vehicle_id), eq(vehicles.userId, userId), eq(vehicles.archived, false))).limit(1);
    if (!vehicle) throw new AppError(404, "vehicle_not_found", "Vehicle not found or not owned by you");

    // Check if already in family
    const [existing] = await db().select().from(familyVehicles)
      .where(and(eq(familyVehicles.familyId, membership.familyId), eq(familyVehicles.vehicleId, body.vehicle_id))).limit(1);
    if (existing) throw new AppError(409, "vehicle_already_in_family", "Vehicle is already in this family");

    const id = newId();
    const [row] = await db().insert(familyVehicles).values({
      id,
      familyId: membership.familyId,
      vehicleId: body.vehicle_id,
      addedBy: userId,
    }).returning();

    await recordChange(db(), {
      userId,
      entityType: "family_vehicle",
      entityId: id,
      op: "upsert",
      payload: { id: row.id, family_id: row.familyId, vehicle_id: row.vehicleId, added_by: row.addedBy, added_at: iso(row.addedAt) },
    });

    return reply.code(201).send({
      id: row.id,
      family_id: row.familyId,
      vehicle_id: row.vehicleId,
      added_by: row.addedBy,
      added_at: iso(row.addedAt),
    });
  });

  // Remove vehicle from family (Primary Owner only)
  app.delete("/families/me/vehicles/:vehicleId", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const vehicleId = (request.params as { vehicleId: string }).vehicleId;

    const [membership] = await db().select().from(familyMemberships)
      .where(and(eq(familyMemberships.userId, userId), eq(familyMemberships.role, "primary_owner"))).limit(1);
    if (!membership) throw new AppError(403, "not_primary_owner", "Only Primary Owner can remove vehicles");
    await requirePremiumPlan(db(), userId);

    const [fv] = await db().select().from(familyVehicles)
      .where(and(eq(familyVehicles.familyId, membership.familyId), eq(familyVehicles.vehicleId, vehicleId))).limit(1);
    if (!fv) throw new AppError(404, "vehicle_not_in_family", "Vehicle is not in this family");

    // Auto-revoke all grants for this vehicle in this family
    await db().delete(vehicleGrants).where(
      and(
        eq(vehicleGrants.vehicleId, vehicleId),
        sql`${vehicleGrants.userId} IN (SELECT user_id FROM ${familyMemberships} WHERE ${familyMemberships.familyId} = ${membership.familyId})`,
      ),
    );

    await db().delete(familyVehicles).where(eq(familyVehicles.id, fv.id));

    await recordChange(db(), {
      userId,
      entityType: "family_vehicle",
      entityId: fv.id,
      op: "delete",
      payload: { id: fv.id, family_id: fv.familyId, vehicle_id: fv.vehicleId },
    });

    return reply.code(204).send();
  });

  // ─── Driving License ────────────────────────────────────────────────

  // Get my driving license
  app.get("/users/me/license", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const [license] = await db().select().from(drivingLicenses).where(eq(drivingLicenses.userId, userId)).limit(1);
    if (!license) throw new AppError(404, "license_not_found", "No driving license uploaded yet");
    return publicDrivingLicense(license);
  });

  // Upsert my driving license
  app.put("/users/me/license", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const body = z.object({
      license_number: z.string().max(50).optional().nullable(),
      issuing_country: z.string().length(2).optional().nullable(),
      expiry_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      categories: z.string().optional().nullable(),
      front_media_id: uuid.optional().nullable(),
      back_media_id: uuid.optional().nullable(),
    }).parse(request.body);

    const expiryDate = new Date(body.expiry_date);
    if (expiryDate < new Date()) throw new AppError(400, "invalid_expiry_date", "Expiry date must be in the future");

    const [existing] = await db().select().from(drivingLicenses).where(eq(drivingLicenses.userId, userId)).limit(1);
    let license;
    if (existing) {
      [license] = await db().update(drivingLicenses).set({
        licenseNumber: body.license_number,
        issuingCountry: body.issuing_country,
        expiryDate: body.expiry_date,
        categories: body.categories,
        frontMediaId: body.front_media_id,
        backMediaId: body.back_media_id,
        updatedAt: new Date(),
      }).where(eq(drivingLicenses.userId, userId)).returning();
    } else {
      [license] = await db().insert(drivingLicenses).values({
        id: newId(),
        userId,
        licenseNumber: body.license_number,
        issuingCountry: body.issuing_country,
        expiryDate: body.expiry_date,
        categories: body.categories,
        frontMediaId: body.front_media_id,
        backMediaId: body.back_media_id,
      }).returning();
    }

    await recordChange(db(), { userId, entityType: "driving_license", entityId: license.id, op: "upsert", payload: publicDrivingLicense(license) });

    return publicDrivingLicense(license);
  });

  // Upload license media
  app.post("/users/me/license/media", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const data = await request.file({ limits: { fileSize: 15 * 1024 * 1024 } });
    if (!data) throw new AppError(400, "no_file", "No file uploaded");

    const fields = data.fields as unknown as Record<string, string | string[]>;
    const side = Array.isArray(fields.side) ? fields.side[0] : fields.side;
    if (side !== "front" && side !== "back") throw new AppError(400, "invalid_side", "Side must be 'front' or 'back'");

    // Upload to media storage (reuse existing media upload logic)
    const mediaId = newId();
    const blobKey = `licenses/${userId}/${mediaId}`;
    
    const chunks: Buffer[] = [];
    for await (const chunk of data.file) chunks.push(chunk);
    const buffer = Buffer.concat(chunks);

    // Store in local media driver or Azure Blob
    if (app.env.MEDIA_DRIVER === "local") {
      const fs = await import("node:fs/promises");
      const path = await import("node:path");
      const mediaDir = path.join(process.cwd(), "media");
      await fs.mkdir(mediaDir, { recursive: true });
      await fs.writeFile(path.join(mediaDir, `${mediaId}`), buffer);
    } else {
      // Azure Blob upload would go here
      const connectionString = app.env.AZURE_STORAGE_CONNECTION_STRING;
      if (!connectionString) throw new AppError(500, "config_missing", "Azure storage not configured");
      const { BlobServiceClient } = await import("@azure/storage-blob");
      const blobService = BlobServiceClient.fromConnectionString(connectionString);
      const container = blobService.getContainerClient(app.env.AZURE_BLOB_CONTAINER);
      const blockBlob = container.getBlockBlobClient(blobKey);
      await blockBlob.upload(buffer, buffer.length);
    }

    const [media] = await db().insert(mediaObjects).values({
      id: mediaId,
      userId,
      blobKey,
      contentType: data.mimetype,
      byteSize: buffer.length,
      sha256: sha256(buffer.toString("base64")),
      purpose: `license_${side}`,
    }).returning();

    return reply.code(201).send({ media_id: media.id });
  });

  // Get family member's license
  app.get("/users/:userId/license", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const targetUserId = (request.params as { userId: string }).userId;

    // Verify same family
    const [myMembership] = await db().select().from(familyMemberships).where(eq(familyMemberships.userId, userId)).limit(1);
    const [targetMembership] = await db().select().from(familyMemberships).where(eq(familyMemberships.userId, targetUserId)).limit(1);
    if (!myMembership || !targetMembership || myMembership.familyId !== targetMembership.familyId) {
      throw new AppError(403, "not_family_member", "Not in the same family");
    }

    const [license] = await db().select().from(drivingLicenses).where(eq(drivingLicenses.userId, targetUserId)).limit(1);
    if (!license) throw new AppError(404, "license_not_found", "No driving license uploaded");
    return publicDrivingLicense(license);
  });
};

export async function getVehicleAccessLevel(db: Db, userId: string, vehicleId: string): Promise<"owner" | "full" | "drive_only" | null> {
  const [vehicle] = await db.select().from(vehicles).where(eq(vehicles.id, vehicleId)).limit(1);
  if (!vehicle) return null;
  const [organizationLink] = await db.select().from(organizationVehicles).where(eq(organizationVehicles.vehicleId, vehicleId)).limit(1);
  if (organizationLink) return null;
  if (vehicle.userId === userId) return "owner";

  const [grant] = await db.select().from(vehicleGrants).where(and(eq(vehicleGrants.vehicleId, vehicleId), eq(vehicleGrants.userId, userId))).limit(1);
  if (!grant) return null;
  const [membership] = await db.select().from(familyMemberships).where(eq(familyMemberships.userId, userId)).limit(1);
  if (!membership) return null;
  const [family] = await db.select().from(families).where(and(eq(families.id, membership.familyId), eq(families.status, "active"))).limit(1);
  if (!family) return null;
  const [vehicleLink] = await db.select().from(familyVehicles).where(and(
    eq(familyVehicles.familyId, family.id), eq(familyVehicles.vehicleId, vehicleId),
  )).limit(1);
  if (!vehicleLink) return null;
  const [ownerMembership] = await db.select().from(familyMemberships).where(and(
    eq(familyMemberships.familyId, family.id), eq(familyMemberships.userId, vehicle.userId),
  )).limit(1);
  return ownerMembership ? grant.permission : null;
}

export async function requireVehicleAccess(
  db: Db,
  userId: string,
  vehicleId: string,
  requiredPermission: "full" | "drive_only"
): Promise<void> {
  const access = await getVehicleAccessLevel(db, userId, vehicleId);
  if (!access) throw new AppError(403, "no_vehicle_access", "No access to this vehicle");
  if (requiredPermission === "full" && access !== "owner" && access !== "full") {
    throw new AppError(403, "insufficient_permission", "Full access required");
  }
}

export async function getFamilyVehicleDetail(db: Db, vehicleId: string, userId: string) {
  const access = await getVehicleAccessLevel(db, userId, vehicleId);
  if (!access) return null;

  const [vehicle] = await db.select().from(vehicles).where(eq(vehicles.id, vehicleId)).limit(1);
  if (!vehicle) return null;

  const grants = await db.select().from(vehicleGrants).where(eq(vehicleGrants.vehicleId, vehicleId));
  const docs = await db.select().from(documents).where(eq(documents.vehicleId, vehicleId));
  const assignedDrivers = [];
  
  for (const grant of grants) {
    if (grant.permission === "drive_only" || grant.permission === "full") {
      const [user] = await db.select().from(users).where(eq(users.id, grant.userId)).limit(1);
      const licenseStatus = await getLicenseStatus(db, grant.userId);
      assignedDrivers.push({
        user_id: grant.userId,
        display_name: user?.displayName ?? user?.email,
        permission: grant.permission,
        license_status: licenseStatus,
      });
    }
  }

  return {
    ...publicVehicle(vehicle),
    grants: grants.map(publicVehicleGrant),
    documents: docs.map((d) => ({
      id: d.id,
      vehicle_id: d.vehicleId,
      name: d.name,
      category: d.category,
      notes: d.notes,
      media_id: d.mediaId,
      created_at: iso(d.createdAt),
    })),
    assigned_drivers: assignedDrivers,
  };
}

export async function getUserDetail(db: Db, userId: string, requestingUserId: string) {
  const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!user) return null;

  // If requesting another user, verify same family
  if (userId !== requestingUserId) {
    const [myMembership] = await db.select().from(familyMemberships).where(eq(familyMemberships.userId, requestingUserId)).limit(1);
    const [targetMembership] = await db.select().from(familyMemberships).where(eq(familyMemberships.userId, userId)).limit(1);
    if (!myMembership || !targetMembership || myMembership.familyId !== targetMembership.familyId) {
      throw new AppError(403, "not_family_member", "Not in the same family");
    }
  }

  const [membership] = await db.select().from(familyMemberships).where(eq(familyMemberships.userId, userId)).limit(1);
  const [license] = await db.select().from(drivingLicenses).where(eq(drivingLicenses.userId, userId)).limit(1);
  const ownedVehicles = await db.select().from(vehicles).where(and(eq(vehicles.userId, userId), eq(vehicles.archived, false)));

  return {
    ...publicUser(user),
    family_id: membership?.familyId ?? null,
    family_role: membership?.role ?? null,
    driving_license: license ? publicDrivingLicense(license) : null,
    owned_vehicles: ownedVehicles.map((v) => publicVehicle(v)),
  };
}
