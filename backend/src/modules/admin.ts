import { and, desc, eq, sql } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { auditEvents, documents, families, familyMemberships, familyVehicles, maintenanceCatalog, organizationMembers, organizationVehicles, organizations, partners, refreshTokens, users, vehicles, vehicleGrants, workshopMembers } from "../db/schema.js";
import { hashPassword, newId, randomToken, sha256 } from "../lib/crypto.js";
import { AppError } from "../lib/errors.js";
import { emailTokens } from "../db/schema.js";
import { publicUser } from "../lib/serialize.js";
import { changeUserPlan } from "../lib/entitlements.js";
import { createInvitedOwnerAccount } from "../lib/account-invites.js";
import { requireAdmin } from "./auth.js";

function publicOrganization(row: typeof organizations.$inferSelect) {
  return {
    id: row.id,
    name: row.name,
    type: row.type,
    plan: row.plan,
    status: row.status,
    admin_user_id: row.adminUserId,
    created_by: row.createdBy,
    activated_by: row.activatedBy,
    activated_at: row.activatedAt?.toISOString() ?? null,
    contact_email: row.contactEmail,
    contact_phone: row.contactPhone,
    settings: row.settings,
    created_at: row.createdAt.toISOString(),
    updated_at: row.updatedAt.toISOString(),
  };
}

export const adminPlugin: FastifyPluginAsync = async (app) => {
  app.addHook("preHandler", async (request) => {
    requireAdmin(request, app.env.JWT_ADMIN_AUD);
  });

  app.get("/admin/dashboard", async () => {
    const [{ count: usersTotal }] = await app.db.select({ count: sql<number>`count(*)::int` }).from(users);
    const [{ count: vehiclesActive }] = await app.db
      .select({ count: sql<number>`count(*)::int` })
      .from(vehicles)
      .where(eq(vehicles.archived, false));
    const [{ count: partnersTotal }] = await app.db.select({ count: sql<number>`count(*)::int` }).from(partners);
    const recentUsers = await app.db.select().from(users).orderBy(desc(users.createdAt)).limit(5);
    return {
      users_total: Number(usersTotal),
      vehicles_active: Number(vehiclesActive),
      partners_total: Number(partnersTotal),
      sync_errors_24h: 0,
      recent_activity: recentUsers.map((u) => ({
        at: u.createdAt.toISOString(),
        kind: "signup" as const,
        summary: u.email,
      })),
    };
  });

  app.get("/admin/organizations", async (request) => {
    const query = z.object({ q: z.string().optional(), status: z.enum(["pending", "active", "suspended", "archived"]).optional() })
      .parse(request.query ?? {});
    let rows = await app.db.select().from(organizations);
    if (query.status) rows = rows.filter((row) => row.status === query.status);
    if (query.q) {
      const needle = query.q.toLowerCase();
      rows = rows.filter((row) => row.name.toLowerCase().includes(needle) || row.contactEmail?.toLowerCase().includes(needle));
    }
    const items = [];
    for (const organization of rows) {
      const [adminUser] = await app.db.select().from(users).where(eq(users.id, organization.adminUserId)).limit(1);
      items.push({ ...publicOrganization(organization), admin_email: adminUser?.email ?? null });
    }
    return { items };
  });

  app.get("/admin/organizations/:organizationId", async (request) => {
    const { organizationId } = request.params as { organizationId: string };
    const [organization] = await app.db.select().from(organizations).where(eq(organizations.id, organizationId)).limit(1);
    if (!organization) throw new AppError(404, "organization_not_found", "Organization not found");
    const [adminUser] = await app.db.select().from(users).where(eq(users.id, organization.adminUserId)).limit(1);
    const members = await app.db.select().from(organizationMembers).where(eq(organizationMembers.orgId, organizationId));
    return {
      ...publicOrganization(organization),
      admin_email: adminUser?.email ?? null,
      member_count: members.length,
    };
  });

  app.post("/admin/organizations", async (request, reply) => {
    const body = z.object({
      name: z.string().trim().min(1).max(200),
      type: z.enum(["showroom", "dealership", "taxi_fleet", "rental", "commercial", "logistics"]),
      admin_email: z.string().email().max(254),
      contact_email: z.string().email().optional().nullable(),
      contact_phone: z.string().max(20).optional().nullable(),
    }).parse(request.body);
    const adminEmail = body.admin_email.toLowerCase();
    let [orgAdmin] = await app.db.select().from(users).where(eq(users.email, adminEmail)).limit(1);
    let accountInvitationSent = false;
    if (!orgAdmin) {
      const invited = await createInvitedOwnerAccount(app.db, app.mailer, adminEmail);
      orgAdmin = invited.user;
      accountInvitationSent = invited.created;
    }
    if (orgAdmin.role !== "owner" || orgAdmin.status !== "active") {
      throw new AppError(409, "invalid_org_admin_account", "Org Admin must be an active owner account");
    }
    const [existingOrganization] = await app.db.select().from(organizations)
      .where(and(eq(organizations.adminUserId, orgAdmin.id), sql`${organizations.status} <> 'archived'`)).limit(1);
    if (existingOrganization) throw new AppError(409, "org_already_exists", "An active organization already exists for this Org Admin");
    const [existingMembership] = await app.db.select().from(organizationMembers)
      .where(eq(organizationMembers.userId, orgAdmin.id)).limit(1);
    if (existingMembership) throw new AppError(409, "already_in_org", "Org Admin already belongs to an organization");

    const actorId = request.authUser!.sub;
    const organizationId = newId();
    const organization = await app.db.transaction(async (tx) => {
      const [created] = await tx.insert(organizations).values({
        id: organizationId,
        name: body.name,
        type: body.type,
        plan: "enterprise",
        status: "pending",
        adminUserId: orgAdmin.id,
        createdBy: actorId,
        contactEmail: body.contact_email ?? null,
        contactPhone: body.contact_phone ?? null,
      }).returning();
      await tx.insert(organizationMembers).values({
        id: newId(),
        orgId: organizationId,
        userId: orgAdmin.id,
        role: "org_admin",
        invitedBy: actorId,
      });
      return created;
    });
    await audit(app, actorId, "organization.create", { organizationId, adminUserId: orgAdmin.id, plan: "enterprise" });
    let organizationInvitationSent = true;
    try {
      await app.mailer.sendOrganizationInvitation(orgAdmin.email, organization.name, "org_admin");
    } catch (error) {
      organizationInvitationSent = false;
      app.log.error(error);
    }
    return reply.code(201).send({
      ...publicOrganization(organization),
      admin_email: orgAdmin.email,
      account_invitation_sent: accountInvitationSent,
      organization_invitation_sent: organizationInvitationSent,
    });
  });

  app.patch("/admin/organizations/:organizationId", async (request) => {
    const { organizationId } = request.params as { organizationId: string };
    const body = z.object({
      name: z.string().trim().min(1).max(200).optional(),
      type: z.enum(["showroom", "dealership", "taxi_fleet", "rental", "commercial", "logistics"]).optional(),
      contact_email: z.string().email().nullable().optional(),
      contact_phone: z.string().max(20).nullable().optional(),
    }).parse(request.body ?? {});
    const [organization] = await app.db.select().from(organizations).where(eq(organizations.id, organizationId)).limit(1);
    if (!organization) throw new AppError(404, "organization_not_found", "Organization not found");
    if (organization.status === "archived") throw new AppError(410, "org_archived", "Archived organizations cannot be edited");
    const [updated] = await app.db.update(organizations).set({
      ...(body.name !== undefined ? { name: body.name } : {}),
      ...(body.type !== undefined ? { type: body.type } : {}),
      ...(body.contact_email !== undefined ? { contactEmail: body.contact_email } : {}),
      ...(body.contact_phone !== undefined ? { contactPhone: body.contact_phone } : {}),
      updatedAt: new Date(),
    }).where(eq(organizations.id, organizationId)).returning();
    await audit(app, request.authUser!.sub, "organization.update", { organizationId });
    return publicOrganization(updated);
  });

  app.patch("/admin/organizations/:organizationId/status", async (request) => {
    const { organizationId } = request.params as { organizationId: string };
    const body = z.object({ status: z.enum(["active", "suspended", "archived"]) }).parse(request.body);
    const [organization] = await app.db.select().from(organizations).where(eq(organizations.id, organizationId)).limit(1);
    if (!organization) throw new AppError(404, "organization_not_found", "Organization not found");
    if (organization.status === "archived") throw new AppError(410, "org_archived", "Archived organizations cannot be reactivated");
    if (body.status === "active" && organization.status === "active") return publicOrganization(organization);

    const actorId = request.authUser!.sub;
    const now = new Date();
    const [updated] = await app.db.transaction(async (tx) => {
      const [row] = await tx.update(organizations).set({
        status: body.status,
        ...(body.status === "active" && organization.status !== "active" ? { activatedBy: actorId, activatedAt: now } : {}),
        updatedAt: now,
      }).where(eq(organizations.id, organizationId)).returning();
      if (body.status === "archived") {
        await tx.delete(organizationMembers).where(eq(organizationMembers.orgId, organizationId));
        await tx.delete(organizationVehicles).where(eq(organizationVehicles.orgId, organizationId));
      }
      return [row];
    });
    await audit(app, actorId, `organization.${body.status}`, { organizationId, previousStatus: organization.status });
    let activationEmailSent: boolean | null = null;
    if (body.status === "active" && organization.status !== "active") {
      activationEmailSent = true;
      const [orgAdmin] = await app.db.select().from(users).where(eq(users.id, organization.adminUserId)).limit(1);
      if (orgAdmin) {
        try {
          await app.mailer.sendOrganizationActivated(orgAdmin.email, organization.name);
        } catch (error) {
          activationEmailSent = false;
          app.log.error(error);
        }
      }
    }
    return { ...publicOrganization(updated), activation_email_sent: activationEmailSent };
  });

  app.post("/admin/support/invite-resend", async (request, reply) => {
    const body = z.object({ organization_id: z.string().uuid() }).parse(request.body);
    const [organization] = await app.db.select().from(organizations).where(eq(organizations.id, body.organization_id)).limit(1);
    if (!organization) throw new AppError(404, "organization_not_found", "Organization not found");
    const [orgAdmin] = await app.db.select().from(users).where(eq(users.id, organization.adminUserId)).limit(1);
    if (!orgAdmin) throw new AppError(404, "user_not_found", "Organization admin account not found");
    await app.mailer.sendOrganizationInvitation(orgAdmin.email, organization.name, "org_admin");
    await audit(app, request.authUser!.sub, "organization.invite_resend", { organizationId: organization.id });
    return reply.code(202).send();
  });

  app.get("/admin/support/org-lookup", async (request) => {
    const query = z.object({ q: z.string().min(1) }).parse(request.query ?? {});
    const needle = query.q.toLowerCase();
    const rows = await app.db.select().from(organizations);
    const items = [];
    for (const organization of rows) {
      const [orgAdmin] = await app.db.select().from(users).where(eq(users.id, organization.adminUserId)).limit(1);
      if (organization.name.toLowerCase().includes(needle) || (orgAdmin?.email ?? "").toLowerCase().includes(needle)) {
        items.push({ ...publicOrganization(organization), admin_email: orgAdmin?.email ?? null });
      }
    }
    return { items };
  });

  app.get("/admin/fleet-view", async (request) => {
    const query = z.object({ organization_id: z.string().uuid().optional() }).parse(request.query ?? {});
    let rows = await app.db.select().from(organizations);
    if (query.organization_id) rows = rows.filter((row) => row.id === query.organization_id);
    const items = [];
    for (const organization of rows) {
      const members = await app.db.select().from(organizationMembers).where(eq(organizationMembers.orgId, organization.id));
      const fleetVehicles = await app.db.select().from(organizationVehicles).where(eq(organizationVehicles.orgId, organization.id));
      items.push({ ...publicOrganization(organization), member_count: members.length, vehicle_count: fleetVehicles.length });
    }
    return { items, read_only: true };
  });

  app.post("/admin/partners/:partnerId/workshop-accounts", async (request, reply) => {
    const { partnerId } = request.params as { partnerId: string };
    const body = z.object({ email: z.string().email().max(254) }).parse(request.body);
    const [partner] = await app.db.select().from(partners).where(eq(partners.id, partnerId)).limit(1);
    if (!partner || partner.type !== "workshop") throw new AppError(404, "workshop_not_found", "Workshop partner not found");
    if (partner.status !== "verified") throw new AppError(409, "workshop_not_verified", "Workshop must be verified before sign-in is enabled");
    let [user] = await app.db.select().from(users).where(eq(users.email, body.email.toLowerCase())).limit(1);
    let accountInvitationSent = false;
    if (!user) {
      const invited = await createInvitedOwnerAccount(app.db, app.mailer, body.email);
      user = invited.user;
      accountInvitationSent = invited.created;
    }
    if (user.role !== "owner" || user.status !== "active") throw new AppError(409, "invalid_workshop_account", "Workshop users must use an active owner account");
    const [existing] = await app.db.select().from(workshopMembers).where(eq(workshopMembers.userId, user.id)).limit(1);
    if (existing) throw new AppError(409, "workshop_account_already_linked", "User is already linked to a workshop account");
    await app.db.insert(workshopMembers).values({
      id: newId(), partnerId, userId: user.id, invitedBy: request.authUser!.sub,
    });
    await app.mailer.sendWorkshopInvitation(user.email, partner.name);
    await audit(app, request.authUser!.sub, "workshop.account_link", { partnerId, userId: user.id });
    return reply.code(201).send({ user_id: user.id, email: user.email, partner_id: partnerId, account_invitation_sent: accountInvitationSent });
  });

  app.get("/admin/users", async (request) => {
    const q = request.query as { q?: string; status?: "active" | "deactivated" };
    let rows = await app.db.select().from(users);
    if (q.status) rows = rows.filter((u) => u.status === q.status);
    if (q.q) {
      const needle = q.q.toLowerCase();
      rows = rows.filter(
        (u) =>
          u.email.includes(needle) ||
          (u.displayName ?? "").toLowerCase().includes(needle) ||
          (u.contactPhone ?? "").includes(needle),
      );
    }
    const items = [];
    for (const u of rows) {
      const v = await app.db.select().from(vehicles).where(eq(vehicles.userId, u.id));
      const [organizationMembership] = await app.db.select({ membership: organizationMembers, organization: organizations })
        .from(organizationMembers)
        .innerJoin(organizations, eq(organizationMembers.orgId, organizations.id))
        .where(eq(organizationMembers.userId, u.id))
        .limit(1);
      items.push({
        id: u.id,
        email: u.email,
        display_name: u.displayName,
        contact_phone: u.contactPhone,
        plan: u.plan,
        status: u.status,
        organization: organizationMembership ? {
          id: organizationMembership.organization.id,
          name: organizationMembership.organization.name,
          plan: organizationMembership.organization.plan,
          status: organizationMembership.organization.status,
          role: organizationMembership.membership.role,
        } : null,
        vehicle_count: v.filter((x) => !x.archived).length,
        created_at: u.createdAt.toISOString(),
      });
    }
    return { items };
  });

  app.get("/admin/users/:userId", async (request) => {
    const { userId } = request.params as { userId: string };
    const [u] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) throw new AppError(404, "not_found", "User not found");
    const v = await app.db.select().from(vehicles).where(eq(vehicles.userId, userId));
    let documentsCount = 0;
    for (const vehicle of v) {
      const docs = await app.db.select().from(documents).where(eq(documents.vehicleId, vehicle.id));
      documentsCount += docs.length;
    }
    let family = null;
    if (u.familyId) {
      const [fam] = await app.db.select().from(families).where(eq(families.id, u.familyId)).limit(1);
      if (fam) {
        const [membership] = await app.db
          .select()
          .from(familyMemberships)
          .where(eq(familyMemberships.userId, userId))
          .limit(1);
        family = { id: fam.id, name: fam.name, role: membership?.role ?? null };
      }
    }
    const [organizationMembership] = await app.db.select({ membership: organizationMembers, organization: organizations })
      .from(organizationMembers)
      .innerJoin(organizations, eq(organizationMembers.orgId, organizations.id))
      .where(eq(organizationMembers.userId, userId))
      .limit(1);
    return {
      id: u.id,
      email: u.email,
      display_name: u.displayName,
      contact_phone: u.contactPhone,
      address: u.address,
      profile_photo_media_id: u.profilePhotoMediaId,
      plan: u.plan,
      status: u.status,
      vehicle_count: v.filter((x) => !x.archived).length,
      created_at: u.createdAt.toISOString(),
      email_verified: u.emailVerified,
      family,
      organization: organizationMembership ? {
        id: organizationMembership.organization.id,
        name: organizationMembership.organization.name,
        plan: organizationMembership.organization.plan,
        status: organizationMembership.organization.status,
        role: organizationMembership.membership.role,
      } : null,
      vehicles: v.map((veh) => ({
        id: veh.id,
        nickname: veh.nickname ?? veh.name,
        license_plate: veh.licensePlate,
      })),
      documents_count: documentsCount,
    };
  });

  app.patch("/admin/users/:userId", async (request) => {
    const { userId } = request.params as { userId: string };
    const body = z.object({ plan: z.enum(["free", "premium"]).optional() }).parse(request.body ?? {});
    const [u] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) throw new AppError(404, "not_found", "User not found");
    const updated = body.plan ? await changeUserPlan(app.db, userId, body.plan) : u;
    await audit(app, request.authUser!.sub, "user.plan_change", { userId, plan: updated.plan });
    return { id: updated.id, plan: updated.plan, email: updated.email, status: updated.status };
  });

  app.post("/admin/users/:userId/deactivate", async (request, reply) => {
    const { userId } = request.params as { userId: string };
    await app.db.update(users).set({ status: "deactivated" }).where(eq(users.id, userId));
    await app.db.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.userId, userId));
    await audit(app, request.authUser!.sub, "user.deactivate", { userId });
    return reply.code(204).send();
  });

  app.post("/admin/users/:userId/reactivate", async (request, reply) => {
    const { userId } = request.params as { userId: string };
    await app.db.update(users).set({ status: "active" }).where(eq(users.id, userId));
    await audit(app, request.authUser!.sub, "user.reactivate", { userId });
    return reply.code(204).send();
  });

  app.post("/admin/users/:userId/send-password-reset", async (request, reply) => {
    const { userId } = request.params as { userId: string };
    const [u] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) throw new AppError(404, "not_found", "User not found");
    const token = randomToken();
    await app.db.insert(emailTokens).values({
      id: newId(),
      userId,
      purpose: "reset",
      tokenHash: sha256(token),
      expiresAt: new Date(Date.now() + 86400000),
    });
    await app.mailer.sendPasswordReset(u.email, token);
    await audit(app, request.authUser!.sub, "user.send_password_reset", { userId });
    return reply.code(202).send();
  });

  app.post("/admin/users", async (request, reply) => {
    const body = z
      .object({
        email: z.string().email().max(254),
        temporary_password: z.string().min(8),
        display_name: z.string().max(50).optional(),
        role: z.enum(["owner", "admin"]).default("owner"),
        plan: z.enum(["free", "premium"]).default("free"),
      })
      .parse(request.body);

    const [existing] = await app.db.select().from(users).where(eq(users.email, body.email.toLowerCase())).limit(1);
    if (existing) throw new AppError(409, "email_taken", "Email already registered");

    const passwordHash = await hashPassword(body.temporary_password);
    const [created] = await app.db
      .insert(users)
      .values({
        id: newId(),
        email: body.email.toLowerCase(),
        passwordHash,
        displayName: body.display_name ?? null,
        role: body.role,
        plan: body.plan,
        status: "active",
        emailVerified: false,
      })
      .returning();

    await audit(app, request.authUser!.sub, "user.create", { userId: created.id, email: created.email, role: created.role });
    return reply.code(201).send(publicUser(created));
  });

  app.post("/admin/users/:userId/delete", async (request, reply) => {
    const { userId } = request.params as { userId: string };
    const adminId = request.authUser!.sub;

    if (userId === adminId) throw new AppError(409, "cannot_delete_self", "Cannot delete your own account");

    const [u] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) throw new AppError(404, "not_found", "User not found");

    if (u.role === "admin") {
      const [{ count }] = await app.db
        .select({ count: sql<number>`count(*)::int` })
        .from(users)
        .where(eq(users.role, "admin"));
      if (Number(count) <= 1) throw new AppError(409, "last_admin", "Cannot delete the last admin account");
    }

    const [membership] = await app.db
      .select()
      .from(familyMemberships)
      .where(eq(familyMemberships.userId, userId))
      .limit(1);

    if (membership) {
      await app.db.delete(familyMemberships).where(eq(familyMemberships.familyId, membership.familyId));
      await app.db.delete(familyVehicles).where(eq(familyVehicles.familyId, membership.familyId));
      await app.db.delete(vehicleGrants).where(eq(vehicleGrants.userId, userId));
      if (membership.role === "primary_owner") {
        const otherMembers = await app.db
          .select()
          .from(familyMemberships)
          .where(eq(familyMemberships.familyId, membership.familyId));
        if (otherMembers.length === 0) {
          await app.db.update(families).set({ status: "archived", archivedAt: new Date() }).where(eq(families.id, membership.familyId));
        }
      }
    }

    const userVehicles = await app.db.select().from(vehicles).where(eq(vehicles.userId, userId));
    for (const v of userVehicles) {
      await app.db.update(vehicles).set({ archived: true, archivedAt: new Date() }).where(eq(vehicles.id, v.id));
    }

    await app.db.update(users).set({ status: "deactivated", familyId: null }).where(eq(users.id, userId));
    await app.db.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.userId, userId));

    await audit(app, adminId, "user.delete", { userId, email: u.email });
    return reply.code(204).send();
  });

  app.patch("/admin/users/:userId/profile", async (request) => {
    const { userId } = request.params as { userId: string };
    const body = z
      .object({
        display_name: z.string().max(50).optional().nullable(),
        contact_phone: z.string().max(20).optional().nullable(),
        address: z.string().max(500).optional().nullable(),
        plan: z.enum(["free", "premium"]).optional(),
      })
      .parse(request.body ?? {});

    const [u] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!u) throw new AppError(404, "not_found", "User not found");

    const set: Record<string, unknown> = {};
    if (body.display_name !== undefined) set.displayName = body.display_name;
    if (body.contact_phone !== undefined) set.contactPhone = body.contact_phone;
    if (body.address !== undefined) set.address = body.address;
    const planUpdated = body.plan !== undefined ? await changeUserPlan(app.db, userId, body.plan) : null;

    const [profileUpdated] = Object.keys(set).length
      ? await app.db.update(users).set(set).where(eq(users.id, userId)).returning()
      : [u];
    await audit(app, request.authUser!.sub, "user.profile_update", { userId });
    return publicUser(planUpdated ? { ...profileUpdated, plan: planUpdated.plan } : profileUpdated);
  });

  const publicPartner = (row: typeof partners.$inferSelect) => ({
    id: row.id,
    name: row.name,
    type: row.type,
    status: row.status,
    contact_email: row.contactEmail,
    contact_phone: row.contactPhone,
    notes: row.notes,
    updated_at: row.updatedAt.toISOString(),
  });

  app.get("/admin/partners", async (request) => {
    const q = (request.query as { q?: string }).q;
    let rows = await app.db.select().from(partners);
    if (q) {
      const needle = q.toLowerCase();
      rows = rows.filter((p) => p.name.toLowerCase().includes(needle));
    }
    return { items: rows.map(publicPartner) };
  });

  app.post("/admin/partners", async (request, reply) => {
    const body = z
      .object({
        name: z.string().min(1).max(120),
        type: z.enum(["workshop", "insurer"]),
        status: z.enum(["draft", "pending_verification", "verified", "rejected"]).optional(),
        contact_email: z.string().optional().nullable(),
        contact_phone: z.string().optional().nullable(),
        notes: z.string().optional().nullable(),
      })
      .parse(request.body);
    const [row] = await app.db
      .insert(partners)
      .values({
        id: newId(),
        name: body.name,
        type: body.type,
        status: body.status ?? "draft",
        contactEmail: body.contact_email ?? null,
        contactPhone: body.contact_phone ?? null,
        notes: body.notes ?? null,
      })
      .returning();
    await audit(app, request.authUser!.sub, "partner.create", { partnerId: row.id });
    return reply.code(201).send(publicPartner(row));
  });

  app.get("/admin/partners/:partnerId", async (request) => {
    const { partnerId } = request.params as { partnerId: string };
    const [row] = await app.db.select().from(partners).where(eq(partners.id, partnerId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Partner not found");
    return publicPartner(row);
  });

  app.patch("/admin/partners/:partnerId", async (request) => {
    const { partnerId } = request.params as { partnerId: string };
    const [row] = await app.db.select().from(partners).where(eq(partners.id, partnerId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Partner not found");
    const body = z
      .object({
        name: z.string().max(120).optional(),
        type: z.enum(["workshop", "insurer"]).optional(),
        status: z.enum(["draft", "pending_verification", "verified", "rejected"]).optional(),
        contact_email: z.string().optional().nullable(),
        contact_phone: z.string().optional().nullable(),
        notes: z.string().optional().nullable(),
      })
      .parse(request.body ?? {});
    const [updated] = await app.db
      .update(partners)
      .set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.type !== undefined ? { type: body.type } : {}),
        ...(body.status !== undefined ? { status: body.status } : {}),
        ...(body.contact_email !== undefined ? { contactEmail: body.contact_email } : {}),
        ...(body.contact_phone !== undefined ? { contactPhone: body.contact_phone } : {}),
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
        updatedAt: new Date(),
      })
      .where(eq(partners.id, partnerId))
      .returning();
    await audit(app, request.authUser!.sub, "partner.update", { partnerId, status: updated.status });
    return publicPartner(updated);
  });

  // ── Maintenance Catalog ──

  const publicCatalogItem = (row: typeof maintenanceCatalog.$inferSelect) => ({
    id: row.id,
    catalog_key: row.catalogKey,
    name: row.name,
    interval_days: row.intervalDays,
    interval_distance: row.intervalDistance != null ? Number(row.intervalDistance) : null,
    fuel_types: row.fuelTypes,
    sort_order: row.sortOrder,
    enabled: row.enabled,
    created_at: row.createdAt.toISOString(),
    updated_at: row.updatedAt.toISOString(),
  });

  app.get("/admin/maintenance-catalog", async () => {
    const rows = await app.db.select().from(maintenanceCatalog).orderBy(maintenanceCatalog.sortOrder);
    return { items: rows.map(publicCatalogItem) };
  });

  app.post("/admin/maintenance-catalog", async (request, reply) => {
    const body = z
      .object({
        catalog_key: z.string().min(1).max(50),
        name: z.string().min(1).max(80),
        interval_days: z.number().int().positive().optional().nullable(),
        interval_distance: z.number().positive().optional().nullable(),
        fuel_types: z.array(z.enum(["petrol", "electric", "hybrid_plugin"])).min(1),
        sort_order: z.number().int().optional(),
        enabled: z.boolean().optional(),
      })
      .parse(request.body);

    const [existing] = await app.db
      .select()
      .from(maintenanceCatalog)
      .where(eq(maintenanceCatalog.catalogKey, body.catalog_key))
      .limit(1);
    if (existing) throw new AppError(409, "key_taken", "Catalog key already exists");

    const [row] = await app.db
      .insert(maintenanceCatalog)
      .values({
        id: newId(),
        catalogKey: body.catalog_key,
        name: body.name,
        intervalDays: body.interval_days ?? null,
        intervalDistance: body.interval_distance != null ? String(body.interval_distance) : null,
        fuelTypes: body.fuel_types,
        sortOrder: body.sort_order ?? 0,
        enabled: body.enabled ?? true,
      })
      .returning();
    await audit(app, request.authUser!.sub, "catalog.create", { catalogKey: row.catalogKey });
    return reply.code(201).send(publicCatalogItem(row));
  });

  app.patch("/admin/maintenance-catalog/:itemId", async (request) => {
    const { itemId } = request.params as { itemId: string };
    const [row] = await app.db.select().from(maintenanceCatalog).where(eq(maintenanceCatalog.id, itemId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Catalog item not found");
    const body = z
      .object({
        name: z.string().min(1).max(80).optional(),
        interval_days: z.number().int().positive().optional().nullable(),
        interval_distance: z.number().positive().optional().nullable(),
        fuel_types: z.array(z.enum(["petrol", "electric", "hybrid_plugin"])).min(1).optional(),
        sort_order: z.number().int().optional(),
        enabled: z.boolean().optional(),
      })
      .parse(request.body ?? {});
    const [updated] = await app.db
      .update(maintenanceCatalog)
      .set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.interval_days !== undefined ? { intervalDays: body.interval_days } : {}),
        ...(body.interval_distance !== undefined
          ? { intervalDistance: body.interval_distance != null ? String(body.interval_distance) : null }
          : {}),
        ...(body.fuel_types !== undefined ? { fuelTypes: body.fuel_types } : {}),
        ...(body.sort_order !== undefined ? { sortOrder: body.sort_order } : {}),
        ...(body.enabled !== undefined ? { enabled: body.enabled } : {}),
        updatedAt: new Date(),
      })
      .where(eq(maintenanceCatalog.id, itemId))
      .returning();
    await audit(app, request.authUser!.sub, "catalog.update", { catalogKey: updated.catalogKey });
    return publicCatalogItem(updated);
  });

  app.delete("/admin/maintenance-catalog/:itemId", async (request, reply) => {
    const { itemId } = request.params as { itemId: string };
    const [row] = await app.db.select().from(maintenanceCatalog).where(eq(maintenanceCatalog.id, itemId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Catalog item not found");
    await app.db.delete(maintenanceCatalog).where(eq(maintenanceCatalog.id, itemId));
    await audit(app, request.authUser!.sub, "catalog.delete", { catalogKey: row.catalogKey });
    return reply.code(204).send();
  });
};

async function audit(
  app: { db: import("../db/client.js").Db },
  adminUserId: string,
  action: string,
  detail: Record<string, unknown>,
) {
  await app.db.insert(auditEvents).values({ adminUserId, action, detail });
}
