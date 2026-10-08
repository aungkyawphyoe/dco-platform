import { and, eq, inArray, isNotNull, isNull, sql } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import {
  documents,
  drivingLicenses,
  expenses,
  fuelLogs,
  mediaObjects,
  organizationVehicles,
  parts,
  planItems,
  serviceRecords,
  users,
  vehicleShares,
  vehicleShareInvitations,
  vehicles,
} from "../db/schema.js";
import { newId, randomToken, sha256 } from "../lib/crypto.js";
import { dateOnly, iso, recordChange } from "../lib/dbx.js";
import { publicUser, publicVehicle } from "../lib/serialize.js";
import { publicDrivingLicense } from "./licenses.js";
import {
  loadService,
  publicDoc,
  publicExpense,
  publicFuelLog,
  publicPart,
  publicPlan,
} from "../lib/serialize-records.js";
import { AppError } from "../lib/errors.js";
import type { Mailer } from "../lib/mail.js";
import { requireOwner } from "./auth.js";

const uuid = z.string().uuid();

const SHARE_LIMITS = {
  free: { perVehicle: 1, total: 3 },
  premium: { perVehicle: 5, total: 20 },
} as const;

const SHARE_CODE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const SHARE_CODE_EXPIRY_MS = 7 * 86400000;
const INVITE_EXPIRY_MS = 7 * 86400000;

function generateShareCode(): string {
  let code = "";
  for (let i = 0; i < 8; i++) {
    code += SHARE_CODE_CHARS.charAt(Math.floor(Math.random() * SHARE_CODE_CHARS.length));
  }
  return code;
}

/**
 * Best-effort invitation email; a delivery failure never blocks the API
 * response because the invitation row is already durable.
 */
async function sendInviteEmail(
  mailer: Mailer,
  params: { to: string; vehicleName: string; inviterName: string; token: string },
): Promise<void> {
  const url = `dco://vehicle/share/accept?token=${encodeURIComponent(params.token)}`;
  try {
    await mailer.sendVehicleShareInvitation(
      params.to,
      params.vehicleName,
      params.inviterName,
      url,
    );
  } catch {
    // Intentionally swallowed: the invite row is the source of truth.
  }
}

/** Display name used in the invitation email salutation. */
async function inviterLabel(db: Db, userId: string): Promise<string> {
  const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  return user?.displayName ?? user?.email ?? "Someone";
}

async function checkShareLimits(db: Db, ownerId: string, vehicleId: string): Promise<void> {
  const [owner] = await db.select({ plan: users.plan }).from(users).where(eq(users.id, ownerId)).limit(1);
  const plan = owner?.plan ?? "free";
  const limits = SHARE_LIMITS[plan];

  const [perVehicleCount] = await db
    .select({ count: sql`count(*)` })
    .from(vehicleShares)
    .where(and(eq(vehicleShares.vehicleId, vehicleId), eq(vehicleShares.status, "active")));
  if (Number(perVehicleCount?.count ?? 0) >= limits.perVehicle) {
    throw new AppError(403, "share_limit_reached", `Your plan allows ${limits.perVehicle} share(s) per vehicle`);
  }

  const [totalCount] = await db
    .select({ count: sql`count(*)` })
    .from(vehicleShares)
    .innerJoin(vehicles, eq(vehicleShares.vehicleId, vehicles.id))
    .where(and(eq(vehicles.userId, ownerId), eq(vehicleShares.status, "active")));
  if (Number(totalCount?.count ?? 0) >= limits.total) {
    throw new AppError(403, "share_limit_reached", `Your plan allows ${limits.total} total active shares`);
  }
}

function publicVehicleShare(
  row: typeof vehicleShares.$inferSelect,
  user?: typeof users.$inferSelect,
) {
  return {
    id: row.id,
    vehicle_id: row.vehicleId,
    user_id: row.userId,
    granted_by: row.grantedBy,
    access_level: row.accessLevel,
    status: row.status,
    invited_email: row.invitedEmail,
    share_code: row.shareCode,
    qr_code_data: row.qrCodeData,
    accepted_at: iso(row.acceptedAt),
    created_at: iso(row.createdAt),
    display_name: user?.displayName ?? null,
    email: user?.email ?? null,
  };
}

function publicShareInvitation(row: typeof vehicleShareInvitations.$inferSelect) {
  return {
    id: row.id,
    vehicle_id: row.vehicleId,
    invited_email: row.invitedEmail,
    access_level: row.accessLevel,
    share_code: row.shareCode,
    expires_at: iso(row.expiresAt),
    created_at: iso(row.createdAt),
    accepted_at: iso(row.acceptedAt),
  };
}

/**
 * Users whose sync should receive changes for a vehicle: the vehicle owner
 * plus every user holding an active share on it. Shares are revoked when the
 * owner removes them, which shrinks the audience automatically.
 */
export async function getVehicleChangeAudience(db: Db, vehicleId: string): Promise<string[]> {
  const [vehicle] = await db
    .select({ userId: vehicles.userId })
    .from(vehicles)
    .where(eq(vehicles.id, vehicleId))
    .limit(1);
  if (!vehicle) return [];
  const shares = await db
    .select({ userId: vehicleShares.userId })
    .from(vehicleShares)
    .where(and(eq(vehicleShares.vehicleId, vehicleId), eq(vehicleShares.status, "active")));
  const userIds = new Set<string>([vehicle.userId, ...shares.map((g) => g.userId)]);
  return [...userIds];
}

/**
 * Record a vehicle-scoped change under every user in the vehicle's change
 * audience (optionally excluding some, e.g. the actor who is recorded
 * separately).
 */
export async function fanOutVehicleChange(
  db: Db,
  params: {
    vehicleId: string;
    entityType: string;
    entityId: string;
    op: "upsert" | "archive" | "delete";
    payload: Record<string, unknown> | null;
    excludeUserIds?: string[];
  },
): Promise<void> {
  if (!params.payload) return;
  const exclude = new Set(params.excludeUserIds ?? []);
  for (const userId of await getVehicleChangeAudience(db, params.vehicleId)) {
    if (exclude.has(userId)) continue;
    await recordChange(db, {
      userId,
      entityType: params.entityType,
      entityId: params.entityId,
      op: params.op,
      payload: params.payload,
    });
  }
}

/**
 * Replay a vehicle's existing history into one user's change log so a shared
 * user receives plan items, service records, parts, fuel logs, documents,
 * and expenses that were logged before the vehicle was shared with them.
 */
export async function seedVehicleHistory(db: Db, vehicleId: string, targetUserId: string): Promise<void> {
  const record = (entityType: string, entityId: string, payload: Record<string, unknown> | null) =>
    payload ? recordChange(db, { userId: targetUserId, entityType, entityId, op: "upsert", payload }) : Promise.resolve();

  const planRows = await db.select().from(planItems).where(eq(planItems.vehicleId, vehicleId));
  for (const row of planRows) await record("plan_item", row.id, publicPlan(row));

  const serviceRows = await db.select().from(serviceRecords).where(eq(serviceRecords.vehicleId, vehicleId));
  for (const row of serviceRows) await record("service_record", row.id, await loadService(db, row.id));

  const partRows = await db.select().from(parts).where(eq(parts.vehicleId, vehicleId));
  for (const row of partRows) await record("part", row.id, publicPart(row));

  const fuelRows = await db.select().from(fuelLogs).where(eq(fuelLogs.vehicleId, vehicleId));
  for (const row of fuelRows) await record("fuel_log", row.id, publicFuelLog(row));

  const docRows = await db.select().from(documents).where(eq(documents.vehicleId, vehicleId));
  for (const row of docRows) await record("document", row.id, publicDoc(row));

  const expenseRows = await db.select().from(expenses).where(eq(expenses.vehicleId, vehicleId));
  for (const row of expenseRows) await record("expense", row.id, await publicExpense(db, row.id));
}

export async function getVehicleAccessLevel(
  db: Db,
  userId: string,
  vehicleId: string,
): Promise<"owner" | "view" | "add_edit_own" | null> {
  const [vehicle] = await db.select().from(vehicles).where(eq(vehicles.id, vehicleId)).limit(1);
  if (!vehicle) return null;
  const [organizationLink] = await db
    .select()
    .from(organizationVehicles)
    .where(eq(organizationVehicles.vehicleId, vehicleId))
    .limit(1);
  if (organizationLink) return null;
  if (vehicle.userId === userId) return "owner";

  const [share] = await db
    .select()
    .from(vehicleShares)
    .where(and(eq(vehicleShares.vehicleId, vehicleId), eq(vehicleShares.userId, userId), eq(vehicleShares.status, "active")))
    .limit(1);
  if (!share) return null;
  return share.accessLevel;
}

export async function requireVehicleAccess(
  db: Db,
  userId: string,
  vehicleId: string,
  requiredLevel: "view" | "add_edit_own",
): Promise<void> {
  const access = await getVehicleAccessLevel(db, userId, vehicleId);
  if (!access) throw new AppError(403, "no_vehicle_access", "No access to this vehicle");
  if (requiredLevel === "add_edit_own" && access !== "owner" && access !== "add_edit_own") {
    throw new AppError(403, "insufficient_permission", "Full access required");
  }
}

export async function getVehicleSharesDetail(db: Db, vehicleId: string, userId: string) {
  const access = await getVehicleAccessLevel(db, userId, vehicleId);
  if (!access) return null;

  const [vehicle] = await db.select().from(vehicles).where(eq(vehicles.id, vehicleId)).limit(1);
  if (!vehicle) return null;

  // The share roster — who else holds a share, their statuses, and the share
  // code — is owner-managed data. Sharees get the vehicle, its documents, and
  // its history, but never a view of other participants.
  const shares = access === "owner" ? await db.select().from(vehicleShares).where(eq(vehicleShares.vehicleId, vehicleId)) : [];
  const docs = await db.select().from(documents).where(eq(documents.vehicleId, vehicleId));

  const sharedUsers: Array<{
    user_id: string;
    display_name: string | null;
    access_level: string;
    status: string;
    share_code: string | null;
  }> = [];
  for (const share of shares) {
    const [user] = await db.select().from(users).where(eq(users.id, share.userId)).limit(1);
    sharedUsers.push({
      user_id: share.userId,
      display_name: user?.displayName ?? user?.email ?? null,
      access_level: share.accessLevel,
      status: share.status,
      share_code: share.shareCode,
    });
  }

  return {
    ...publicVehicle(vehicle),
    shares: shares.map((s) => publicVehicleShare(s)),
    documents: docs.map((d) => ({
      id: d.id,
      vehicle_id: d.vehicleId,
      name: d.name,
      category: d.category,
      notes: d.notes,
      expires_on: dateOnly(d.expiresOn),
      media_id: d.mediaId,
      created_at: iso(d.createdAt),
      created_by: d.createdBy,
    })),
    shared_users: sharedUsers,
  };
}

export async function getUserDetail(db: Db, userId: string, requestingUserId: string) {
  const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!user) return null;

  // If requesting another user, verify they share at least one vehicle with the requester
  if (userId !== requestingUserId) {
    const myShares = await db
      .select({ vehicleId: vehicleShares.vehicleId })
      .from(vehicleShares)
      .where(and(eq(vehicleShares.userId, requestingUserId), eq(vehicleShares.status, "active")));
    const targetShares = await db
      .select({ vehicleId: vehicleShares.vehicleId })
      .from(vehicleShares)
      .where(and(eq(vehicleShares.userId, userId), eq(vehicleShares.status, "active")));

    const myVehicleIds = new Set(myShares.map((s) => s.vehicleId));
    const sharesVehicles = targetShares.some((s) => myVehicleIds.has(s.vehicleId));

    if (!sharesVehicles) {
      // Target owns a vehicle the requester holds a share on
      const targetOwned = await db
        .select({ id: vehicles.id })
        .from(vehicles)
        .where(eq(vehicles.userId, userId));
      const targetOwnedIds = new Set(targetOwned.map((v) => v.id));
      const shareOnTargetOwned = myShares.some((s) => targetOwnedIds.has(s.vehicleId));

      // Requester owns a vehicle the target holds a share on
      const requesterOwned = await db
        .select({ id: vehicles.id })
        .from(vehicles)
        .where(eq(vehicles.userId, requestingUserId));
      const requesterOwnedIds = new Set(requesterOwned.map((v) => v.id));
      const shareOnRequesterOwned = targetShares.some((s) => requesterOwnedIds.has(s.vehicleId));

      if (!shareOnTargetOwned && !shareOnRequesterOwned) {
        throw new AppError(403, "not_shared", "No shared vehicles between users");
      }
    }
  }

  const ownedVehicles = await db
    .select()
    .from(vehicles)
    .where(and(eq(vehicles.userId, userId), eq(vehicles.archived, false)));

  const sharedWithMe = await db
    .select({ vehicle: vehicles, share: vehicleShares })
    .from(vehicleShares)
    .innerJoin(vehicles, eq(vehicleShares.vehicleId, vehicles.id))
    .where(and(eq(vehicleShares.userId, userId), eq(vehicleShares.status, "active"), eq(vehicles.archived, false)));

  const [license] = await db
    .select()
    .from(drivingLicenses)
    .where(eq(drivingLicenses.userId, userId))
    .limit(1);

  return {
    ...publicUser(user),
    driving_license: license ? publicDrivingLicense(license) : null,
    owned_vehicles: ownedVehicles.map((v) => publicVehicle(v)),
    shared_vehicles: sharedWithMe.map((r) => ({
      ...publicVehicle(r.vehicle),
      access_level: r.share.accessLevel,
      owner_id: r.vehicle.userId,
    })),
  };
}

export const vehicleSharesPlugin: FastifyPluginAsync = async (app) => {
  const db = () => app.db;
  const uid = (request: { authUser?: { sub: string } }) => request.authUser!.sub;

  // ─── Create Share (email invite or code/QR) ─────────────────────

  app.post("/vehicles/:id/shares", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const vehicleId = (request.params as { id: string }).id;
    const body = z
      .object({
        method: z.enum(["email", "code_qr"]),
        email: z.string().email().optional(),
        access_level: z.enum(["view", "add_edit_own"]).default("view"),
      })
      .parse(request.body);

    if (body.method === "email" && !body.email) {
      throw new AppError(400, "email_required", "Email is required for email invitations");
    }

    const [vehicle] = await db()
      .select()
      .from(vehicles)
      .where(and(eq(vehicles.id, vehicleId), eq(vehicles.userId, userId), eq(vehicles.archived, false)))
      .limit(1);
    if (!vehicle) throw new AppError(404, "vehicle_not_found", "Vehicle not found or not owned by you");

    // Fleet-managed (org-linked) vehicles live in Fleet mode and are not
    // shareable through the personal sharing path.
    const [organizationLink] = await db()
      .select({ vehicleId: organizationVehicles.vehicleId })
      .from(organizationVehicles)
      .where(eq(organizationVehicles.vehicleId, vehicleId))
      .limit(1);
    if (organizationLink) throw new AppError(404, "vehicle_not_found", "Vehicle not found or not owned by you");

    await checkShareLimits(db(), userId, vehicleId);

    if (body.method === "email") {
      // Check the invited email is not already an active share
      const [invitedUser] = await db()
        .select()
        .from(users)
        .where(eq(users.email, body.email!))
        .limit(1);
      if (invitedUser) {
        const [existing] = await db()
          .select()
          .from(vehicleShares)
          .where(and(eq(vehicleShares.vehicleId, vehicleId), eq(vehicleShares.userId, invitedUser.id)))
          .limit(1);
        if (existing) throw new AppError(409, "already_shared", "User already has a share on this vehicle");
      }

      const token = randomToken();
      const invitationId = newId();
      const [invitation] = await db()
        .insert(vehicleShareInvitations)
        .values({
          id: invitationId,
          vehicleId,
          invitedEmail: body.email,
          invitedBy: userId,
          accessLevel: body.access_level,
          token,
          expiresAt: new Date(Date.now() + INVITE_EXPIRY_MS),
        })
        .returning();

      // If the invited user already exists, create a pending share row linked to them
      if (invitedUser) {
        await db()
          .insert(vehicleShares)
          .values({
            id: newId(),
            vehicleId,
            userId: invitedUser.id,
            grantedBy: userId,
            accessLevel: body.access_level,
            status: "pending",
            invitedEmail: body.email,
          })
          .onConflictDoNothing();
      }

      await sendInviteEmail(app.mailer, {
        to: body.email!,
        vehicleName: vehicle.nickname ?? vehicle.name,
        inviterName: await inviterLabel(db(), userId),
        token,
      });

      return reply.code(201).send({
        ...publicShareInvitation(invitation),
        invite_token: token,
        invite_url: `dco://vehicle/share/accept?token=${token}`,
      });
    }

    // code_qr method — replace any outstanding code so regenerating
    // invalidates the previous one.
    await db()
      .delete(vehicleShareInvitations)
      .where(
        and(
          eq(vehicleShareInvitations.vehicleId, vehicleId),
          isNull(vehicleShareInvitations.acceptedAt),
          isNotNull(vehicleShareInvitations.shareCode),
          isNull(vehicleShareInvitations.invitedEmail),
        ),
      );

    const shareCode = generateShareCode();
    const qrCodeData = {
      code: shareCode,
      vehicle_id: vehicleId,
      expires_at: new Date(Date.now() + SHARE_CODE_EXPIRY_MS).toISOString(),
    };

    const token = randomToken();
    const invitationId = newId();
    const [invitation] = await db()
      .insert(vehicleShareInvitations)
      .values({
        id: invitationId,
        vehicleId,
        invitedBy: userId,
        accessLevel: body.access_level,
        token,
        shareCode,
        expiresAt: new Date(Date.now() + SHARE_CODE_EXPIRY_MS),
      })
      .returning();

    return reply.code(201).send({
      ...publicShareInvitation(invitation),
      share_code: shareCode,
      qr_code_data: qrCodeData,
      join_url: `dco://vehicle/share/join?code=${shareCode}`,
    });
  });

  // ─── List Shares for a Vehicle (owner only) ─────────────────────

  app.get("/vehicles/:id/shares", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const vehicleId = (request.params as { id: string }).id;

    const [vehicle] = await db()
      .select()
      .from(vehicles)
      .where(and(eq(vehicles.id, vehicleId), eq(vehicles.userId, userId)))
      .limit(1);
    if (!vehicle) throw new AppError(403, "not_vehicle_owner", "Only the vehicle owner can manage shares");

    const shares = await db().select().from(vehicleShares).where(eq(vehicleShares.vehicleId, vehicleId));
    const sharesWithUsers = [];
    for (const share of shares) {
      const [user] = await db().select().from(users).where(eq(users.id, share.userId)).limit(1);
      sharesWithUsers.push(publicVehicleShare(share, user!));
    }

    const invitations = await db()
      .select()
      .from(vehicleShareInvitations)
      .where(and(eq(vehicleShareInvitations.vehicleId, vehicleId), isNull(vehicleShareInvitations.acceptedAt)));

    const [owner] = await db().select().from(users).where(eq(users.id, userId)).limit(1);
    const limits = SHARE_LIMITS[owner?.plan ?? "free"];
    const [activeCount] = await db()
      .select({ count: sql`count(*)` })
      .from(vehicleShares)
      .where(and(eq(vehicleShares.vehicleId, vehicleId), eq(vehicleShares.status, "active")));

    // The outstanding code/QR invitation is how the owner reads the current
    // share code back on a later visit (it is not stored on the vehicle).
    const codeInvite = invitations.find((row) => row.shareCode);

    return {
      vehicle: publicVehicle(vehicle),
      shares: sharesWithUsers,
      pending_invites: invitations.map(publicShareInvitation),
      share_code: codeInvite?.shareCode ?? null,
      qr_code_data: codeInvite?.shareCode
        ? {
            code: codeInvite.shareCode,
            vehicle_id: vehicleId,
            expires_at: iso(codeInvite.expiresAt),
          }
        : null,
      limits: {
        per_vehicle: limits.perVehicle,
        total: limits.total,
        active_on_vehicle: Number(activeCount?.count ?? 0),
      },
    };
  });

  // ─── Update Share (access level, regenerate code, resend invite) ─

  app.patch("/vehicles/:id/shares/:shareId", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const vehicleId = (request.params as { id: string }).id;
    const shareId = (request.params as { shareId: string }).shareId;
    const body = z
      .object({
        access_level: z.enum(["view", "add_edit_own"]).optional(),
        regenerate_code: z.boolean().optional(),
      })
      .parse(request.body);

    const [vehicle] = await db()
      .select()
      .from(vehicles)
      .where(and(eq(vehicles.id, vehicleId), eq(vehicles.userId, userId)))
      .limit(1);
    if (!vehicle) throw new AppError(403, "not_vehicle_owner", "Only the vehicle owner can manage shares");

    const [share] = await db()
      .select()
      .from(vehicleShares)
      .where(and(eq(vehicleShares.id, shareId), eq(vehicleShares.vehicleId, vehicleId)))
      .limit(1);
    if (!share) throw new AppError(404, "share_not_found", "Share not found");

    const updates: Record<string, unknown> = {};

    if (body.access_level) {
      updates.accessLevel = body.access_level;
    }

    if (body.regenerate_code) {
      const newCode = generateShareCode();
      updates.shareCode = newCode;
      updates.qrCodeData = {
        code: newCode,
        vehicle_id: vehicleId,
        expires_at: new Date(Date.now() + SHARE_CODE_EXPIRY_MS).toISOString(),
      };
    }

    if (Object.keys(updates).length > 0) {
      const [updated] = await db()
        .update(vehicleShares)
        .set(updates)
        .where(eq(vehicleShares.id, shareId))
        .returning();
      const payload = publicVehicleShare(updated);
      // Tell both parties: the owner's roster and the sharee's own copy of the
      // share (which stamps their access level in the mobile client).
      await recordChange(db(), {
        userId,
        entityType: "vehicle_share",
        entityId: shareId,
        op: "upsert",
        payload,
      });
      await recordChange(db(), {
        userId: share.userId,
        entityType: "vehicle_share",
        entityId: shareId,
        op: "upsert",
        payload,
      });
      return payload;
    }

    return publicVehicleShare(share);
  });

  // ─── Revoke Share ────────────────────────────────────────────────

  app.delete("/vehicles/:id/shares/:shareId", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const vehicleId = (request.params as { id: string }).id;
    const shareId = (request.params as { shareId: string }).shareId;

    const [vehicle] = await db()
      .select()
      .from(vehicles)
      .where(and(eq(vehicles.id, vehicleId), eq(vehicles.userId, userId)))
      .limit(1);
    if (!vehicle) throw new AppError(403, "not_vehicle_owner", "Only the vehicle owner can manage shares");

    const [share] = await db()
      .select()
      .from(vehicleShares)
      .where(and(eq(vehicleShares.id, shareId), eq(vehicleShares.vehicleId, vehicleId)))
      .limit(1);
    if (!share) throw new AppError(404, "share_not_found", "Share not found");

    await db().delete(vehicleShares).where(eq(vehicleShares.id, shareId));

    // Also delete any pending invitation for this user
    if (share.invitedEmail) {
      await db()
        .delete(vehicleShareInvitations)
        .where(
          and(
            eq(vehicleShareInvitations.vehicleId, vehicleId),
            eq(vehicleShareInvitations.invitedEmail, share.invitedEmail),
            isNull(vehicleShareInvitations.acceptedAt),
          ),
        );
    }

    // Tell the shared user the share is gone
    await recordChange(db(), {
      userId: share.userId,
      entityType: "vehicle_share",
      entityId: shareId,
      op: "delete",
      payload: { id: shareId, vehicle_id: vehicleId, user_id: share.userId },
    });

    // Tell owner
    await recordChange(db(), {
      userId,
      entityType: "vehicle_share",
      entityId: shareId,
      op: "delete",
      payload: { id: shareId, vehicle_id: vehicleId, user_id: share.userId },
    });

    return reply.code(204).send();
  });

  // ─── Resend a pending email invitation ──────────────────────────

  app.post("/vehicles/:id/invitations/:inviteId/resend", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const vehicleId = (request.params as { id: string }).id;
    const inviteId = (request.params as { inviteId: string }).inviteId;

    const [vehicle] = await db()
      .select()
      .from(vehicles)
      .where(and(eq(vehicles.id, vehicleId), eq(vehicles.userId, userId)))
      .limit(1);
    if (!vehicle) throw new AppError(403, "not_vehicle_owner", "Only the vehicle owner can manage shares");

    const [invitation] = await db()
      .select()
      .from(vehicleShareInvitations)
      .where(and(eq(vehicleShareInvitations.id, inviteId), eq(vehicleShareInvitations.vehicleId, vehicleId)))
      .limit(1);
    if (!invitation) throw new AppError(404, "invitation_not_found", "Invitation not found");
    if (invitation.acceptedAt) throw new AppError(409, "already_accepted", "Invitation already accepted");
    if (!invitation.invitedEmail) throw new AppError(400, "not_email_invite", "Only email invitations can be resent");

    // Rotate the token so the new link supersedes any earlier one.
    const fresh = randomToken();
    await db()
      .update(vehicleShareInvitations)
      .set({ token: fresh, expiresAt: new Date(Date.now() + INVITE_EXPIRY_MS) })
      .where(eq(vehicleShareInvitations.id, inviteId));

    await sendInviteEmail(app.mailer, {
      to: invitation.invitedEmail,
      vehicleName: vehicle.nickname ?? vehicle.name,
      inviterName: await inviterLabel(db(), userId),
      token: fresh,
    });

    return reply.code(200).send({ ...publicShareInvitation({ ...invitation, token: fresh }) });
  });

  // ─── Cancel a pending invitation ────────────────────────────────

  app.delete("/vehicles/:id/invitations/:inviteId", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const vehicleId = (request.params as { id: string }).id;
    const inviteId = (request.params as { inviteId: string }).inviteId;

    const [vehicle] = await db()
      .select()
      .from(vehicles)
      .where(and(eq(vehicles.id, vehicleId), eq(vehicles.userId, userId)))
      .limit(1);
    if (!vehicle) throw new AppError(403, "not_vehicle_owner", "Only the vehicle owner can manage shares");

    const [invitation] = await db()
      .select()
      .from(vehicleShareInvitations)
      .where(and(eq(vehicleShareInvitations.id, inviteId), eq(vehicleShareInvitations.vehicleId, vehicleId)))
      .limit(1);
    if (!invitation) throw new AppError(404, "invitation_not_found", "Invitation not found");
    if (invitation.acceptedAt) throw new AppError(409, "already_accepted", "Invitation already accepted");

    await db().delete(vehicleShareInvitations).where(eq(vehicleShareInvitations.id, inviteId));

    // Drop the placeholder share row created for an already-registered user.
    if (invitation.invitedEmail) {
      await db()
        .delete(vehicleShares)
        .where(
          and(
            eq(vehicleShares.vehicleId, vehicleId),
            eq(vehicleShares.invitedEmail, invitation.invitedEmail),
            eq(vehicleShares.status, "pending"),
          ),
        );
    }

    return reply.code(204).send();
  });

  // ─── List Vehicles Shared With Me ────────────────────────────────

  app.get("/vehicles/shared", async (request) => {
    requireOwner(request);
    const userId = uid(request);

    const rows = await db()
      .select({ vehicle: vehicles, share: vehicleShares })
      .from(vehicleShares)
      .innerJoin(vehicles, eq(vehicleShares.vehicleId, vehicles.id))
      .where(and(eq(vehicleShares.userId, userId), eq(vehicleShares.status, "active"), eq(vehicles.archived, false)));

    // Fleet-managed vehicles are excluded from personal sharing entirely.
    const orgRows = await db().select({ vehicleId: organizationVehicles.vehicleId }).from(organizationVehicles);
    const orgVehicleIds = new Set(orgRows.map((r) => r.vehicleId));
    const visible = rows.filter((r) => !orgVehicleIds.has(r.vehicle.id));

    const ownerIds = [...new Set(visible.map((r) => r.vehicle.userId))];
    const ownerMap = new Map<string, { display_name: string | null; email: string | null }>();
    if (ownerIds.length) {
      const owners = await db().select().from(users).where(inArray(users.id, ownerIds));
      for (const o of owners) ownerMap.set(o.id, { display_name: o.displayName, email: o.email });
    }

    return {
      items: visible.map((r) => ({
        ...publicVehicle(r.vehicle),
        source: "shared",
        access_level: r.share.accessLevel,
        owner: {
          id: r.vehicle.userId,
          display_name: ownerMap.get(r.vehicle.userId)?.display_name ?? null,
          email: ownerMap.get(r.vehicle.userId)?.email ?? null,
        },
      })),
    };
  });

  // ─── Accept Share by Token (email flow) ─────────────────────────

  app.post("/vehicles/shares/accept", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const body = z.object({ token: z.string().min(1) }).parse(request.body);

    const [invitation] = await db()
      .select()
      .from(vehicleShareInvitations)
      .where(eq(vehicleShareInvitations.token, body.token))
      .limit(1);
    if (!invitation) throw new AppError(404, "invitation_not_found", "Invalid or expired invitation");
    if (invitation.acceptedAt) throw new AppError(409, "already_accepted", "Invitation already accepted");
    if (new Date(invitation.expiresAt) < new Date()) {
      throw new AppError(410, "invitation_expired", "Invitation has expired");
    }

    // If invitation was sent to a specific email, verify the user matches
    if (invitation.invitedEmail) {
      const [user] = await db().select().from(users).where(eq(users.id, userId)).limit(1);
      if (user?.email !== invitation.invitedEmail) {
        throw new AppError(403, "email_mismatch", "This invitation was sent to a different email address");
      }
    }

    // Check if already shared
    const [existing] = await db()
      .select()
      .from(vehicleShares)
      .where(and(eq(vehicleShares.vehicleId, invitation.vehicleId), eq(vehicleShares.userId, userId)))
      .limit(1);
    if (existing && existing.status === "active") {
      throw new AppError(409, "already_shared", "You already have access to this vehicle");
    }

    await checkShareLimits(db(), invitation.invitedBy, invitation.vehicleId);

    // Create or update the share
    let share;
    if (existing) {
      [share] = await db()
        .update(vehicleShares)
        .set({ status: "active", accessLevel: invitation.accessLevel, acceptedAt: new Date() })
        .where(eq(vehicleShares.id, existing.id))
        .returning();
    } else {
      [share] = await db()
        .insert(vehicleShares)
        .values({
          id: newId(),
          vehicleId: invitation.vehicleId,
          userId,
          grantedBy: invitation.invitedBy,
          accessLevel: invitation.accessLevel,
          status: "active",
          invitedEmail: invitation.invitedEmail,
          acceptedAt: new Date(),
        })
        .returning();
    }

    await db()
      .update(vehicleShareInvitations)
      .set({ acceptedAt: new Date(), acceptedBy: userId })
      .where(eq(vehicleShareInvitations.id, invitation.id));

    // Hand the accepter the vehicle row plus its history via the change log
    const [vehicle] = await db()
      .select()
      .from(vehicles)
      .where(eq(vehicles.id, invitation.vehicleId))
      .limit(1);
    if (vehicle) {
      await recordChange(db(), {
        userId,
        entityType: "vehicle",
        entityId: vehicle.id,
        op: "upsert",
        payload: publicVehicle(vehicle),
      });
      await recordChange(db(), {
        userId,
        entityType: "vehicle_share",
        entityId: share.id,
        op: "upsert",
        payload: publicVehicleShare(share),
      });
      await seedVehicleHistory(db(), vehicle.id, userId);
    }

    // Notify the inviter
    await recordChange(db(), {
      userId: invitation.invitedBy,
      entityType: "vehicle_share",
      entityId: share.id,
      op: "upsert",
      payload: publicVehicleShare(share),
    });

    return publicVehicleShare(share);
  });

  // ─── Join Share by Code (Code/QR flow) ─────────────────────────

  app.post("/vehicles/shares/join", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const body = z.object({ code: z.string().min(8).max(8) }).parse(request.body);
    const code = body.code.toUpperCase();

    const [invitation] = await db()
      .select()
      .from(vehicleShareInvitations)
      .where(and(eq(vehicleShareInvitations.shareCode, code), isNull(vehicleShareInvitations.acceptedAt)))
      .limit(1);
    if (!invitation) throw new AppError(404, "share_code_not_found", "Invalid or expired share code");
    if (new Date(invitation.expiresAt) < new Date()) {
      throw new AppError(410, "share_code_expired", "Share code has expired");
    }

    // Check if already shared
    const [existing] = await db()
      .select()
      .from(vehicleShares)
      .where(and(eq(vehicleShares.vehicleId, invitation.vehicleId), eq(vehicleShares.userId, userId)))
      .limit(1);
    if (existing && existing.status === "active") {
      throw new AppError(409, "already_shared", "You already have access to this vehicle");
    }

    // Verify the user does not already own this vehicle
    const [vehicle] = await db()
      .select()
      .from(vehicles)
      .where(eq(vehicles.id, invitation.vehicleId))
      .limit(1);
    if (!vehicle) throw new AppError(404, "vehicle_not_found", "Vehicle not found");
    if (vehicle.userId === userId) throw new AppError(409, "owner_cannot_join", "You already own this vehicle");

    await checkShareLimits(db(), invitation.invitedBy, invitation.vehicleId);

    // Create or update the share
    let share;
    if (existing) {
      [share] = await db()
        .update(vehicleShares)
        .set({ status: "active", accessLevel: invitation.accessLevel, acceptedAt: new Date() })
        .where(eq(vehicleShares.id, existing.id))
        .returning();
    } else {
      [share] = await db()
        .insert(vehicleShares)
        .values({
          id: newId(),
          vehicleId: invitation.vehicleId,
          userId,
          grantedBy: invitation.invitedBy,
          accessLevel: invitation.accessLevel,
          status: "active",
          shareCode: code,
          acceptedAt: new Date(),
        })
        .returning();
    }

    await db()
      .update(vehicleShareInvitations)
      .set({ acceptedAt: new Date(), acceptedBy: userId })
      .where(eq(vehicleShareInvitations.id, invitation.id));

    // Hand the joiner the vehicle row plus its history via the change log
    await recordChange(db(), {
      userId,
      entityType: "vehicle",
      entityId: vehicle.id,
      op: "upsert",
      payload: publicVehicle(vehicle),
    });
    await recordChange(db(), {
      userId,
      entityType: "vehicle_share",
      entityId: share.id,
      op: "upsert",
      payload: publicVehicleShare(share),
    });
    await seedVehicleHistory(db(), vehicle.id, userId);

    // Notify the inviter
    await recordChange(db(), {
      userId: invitation.invitedBy,
      entityType: "vehicle_share",
      entityId: share.id,
      op: "upsert",
      payload: publicVehicleShare(share),
    });

    return reply.code(201).send(publicVehicleShare(share));
  });

  // ─── Decline Share by Token ──────────────────────────────────────

  app.post("/vehicles/shares/decline", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    const body = z.object({ token: z.string().min(1) }).parse(request.body);

    const [invitation] = await db()
      .select()
      .from(vehicleShareInvitations)
      .where(eq(vehicleShareInvitations.token, body.token))
      .limit(1);
    if (!invitation) throw new AppError(404, "invitation_not_found", "Invalid invitation");
    if (invitation.acceptedAt) throw new AppError(409, "already_responded", "Invitation already responded to");

    await db()
      .delete(vehicleShareInvitations)
      .where(eq(vehicleShareInvitations.id, invitation.id));

    // Remove any pending share row for this user
    await db()
      .delete(vehicleShares)
      .where(
        and(
          eq(vehicleShares.vehicleId, invitation.vehicleId),
          eq(vehicleShares.userId, userId),
          eq(vehicleShares.status, "pending"),
        ),
      );

    return reply.code(204).send();
  });

  // ─── Lookup Share Code (preview before joining) ─────────────────

  app.get("/vehicles/shares/:code", async (request) => {
    requireOwner(request);
    const code = (request.params as { code: string }).code.toUpperCase();
    const [invitation] = await db()
      .select()
      .from(vehicleShareInvitations)
      .where(and(eq(vehicleShareInvitations.shareCode, code), isNull(vehicleShareInvitations.acceptedAt)))
      .limit(1);
    if (!invitation) throw new AppError(404, "share_code_not_found", "Invalid or expired share code");
    if (new Date(invitation.expiresAt) < new Date()) {
      throw new AppError(410, "share_code_expired", "Share code has expired");
    }

    const [vehicle] = await db()
      .select()
      .from(vehicles)
      .where(eq(vehicles.id, invitation.vehicleId))
      .limit(1);
    if (!vehicle) throw new AppError(404, "vehicle_not_found", "Vehicle not found");

    const [owner] = await db()
      .select()
      .from(users)
      .where(eq(users.id, vehicle.userId))
      .limit(1);

    return {
      vehicle_nickname: vehicle.nickname ?? vehicle.name,
      license_plate: vehicle.licensePlate,
      owner_display_name: owner?.displayName ?? null,
      access_level: invitation.accessLevel,
      expires_at: iso(invitation.expiresAt),
    };
  });
};
