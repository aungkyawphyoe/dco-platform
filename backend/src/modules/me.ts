import { eq } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { deviceTokens, users, vehicles } from "../db/schema.js";
import { families, familyMemberships, organizationMembers, organizations } from "../db/schema.js";
import { newId } from "../lib/crypto.js";
import { AppError } from "../lib/errors.js";
import { getUser } from "../lib/dbx.js";
import { publicUser } from "../lib/serialize.js";
import { requireFleetClient, requireOwner } from "./auth.js";
import { getUserDetail } from "./family.js";

export const mePlugin: FastifyPluginAsync = async (app) => {
  app.get("/me", async (request) => {
    const user = await getUser(app.db, request.authUser!.sub);
    if (!user) throw new AppError(401, "unauthorized", "Unknown user");
    return publicUser(user);
  });

  app.get("/me/entitlements", async (request) => {
    requireFleetClient(request);
    const userId = request.authUser!.sub;
    const [user] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!user) throw new AppError(401, "unauthorized", "Unknown user");

    const [familyMembership] = await app.db.select().from(familyMemberships)
      .where(eq(familyMemberships.userId, userId)).limit(1);
    const [activeFamily] = familyMembership
      ? await app.db.select().from(families)
        .where(eq(families.id, familyMembership.familyId)).limit(1)
      : [];
    const familyIsActive = Boolean(activeFamily && activeFamily.status === "active");

    const [organizationMembership] = await app.db.select({ membership: organizationMembers, organization: organizations })
      .from(organizationMembers)
      .innerJoin(organizations, eq(organizationMembers.orgId, organizations.id))
      .where(eq(organizationMembers.userId, userId))
      .limit(1);
    const organization = organizationMembership?.organization ?? null;
    const familyFeature = user.plan === "premium" || familyIsActive;
    const fleetFeature = Boolean(organization && organization.plan === "enterprise" && organization.status === "active");

    return {
      plan: user.plan,
      family: {
        available: familyFeature,
        role: familyIsActive ? familyMembership?.role ?? null : null,
        can_create: user.plan === "premium" && !familyMembership,
        can_manage: user.plan === "premium" && familyIsActive && familyMembership?.role === "primary_owner",
      },
      organization: organization && organizationMembership ? {
        id: organization.id,
        type: organization.type,
        plan: organization.plan,
        status: organization.status,
        role: organizationMembership.membership.role,
      } : null,
      features: { family: familyFeature, fleet: fleetFeature },
    };
  });

  app.patch("/me", async (request) => {
    requireOwner(request);
    const body = z
      .object({
        display_name: z.string().optional(),
        active_vehicle_id: z.string().uuid().nullable().optional(),
      })
      .parse(request.body ?? {});
    const userId = request.authUser!.sub;
    if (body.active_vehicle_id) {
      const [v] = await app.db
        .select()
        .from(vehicles)
        .where(eq(vehicles.id, body.active_vehicle_id))
        .limit(1);
      if (!v || v.userId !== userId || v.archived) {
        throw new AppError(422, "invalid_vehicle", "Active vehicle not found");
      }
    }
    const [updated] = await app.db
      .update(users)
      .set({
        ...(body.display_name !== undefined ? { displayName: body.display_name } : {}),
        ...(body.active_vehicle_id !== undefined ? { activeVehicleId: body.active_vehicle_id } : {}),
      })
      .where(eq(users.id, userId))
      .returning();
    return publicUser(updated);
  });

  app.post("/me/device-tokens", async (request, reply) => {
    const body = z.object({ token: z.string(), platform: z.enum(["ios", "android"]) }).parse(request.body);
    const userId = request.authUser!.sub;
    try {
      await app.db.insert(deviceTokens).values({ id: newId(), userId, token: body.token, platform: body.platform });
    } catch {
      // already registered
    }
    return reply.code(204).send();
  });

  // User detail with family info, license, owned vehicles
  app.get("/users/:userId/detail", async (request) => {
    requireOwner(request);
    const requestingUserId = request.authUser!.sub;
    const targetUserId = (request.params as { userId: string }).userId;
    const detail = await getUserDetail(app.db, targetUserId, requestingUserId);
    if (!detail) throw new AppError(404, "user_not_found", "User not found");
    return detail;
  });
};
