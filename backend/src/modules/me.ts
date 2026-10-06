import { and, eq, sql } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { deviceTokens, users, vehicles, vehicleShares, organizationMembers, organizations } from "../db/schema.js";
import { newId } from "../lib/crypto.js";
import { AppError } from "../lib/errors.js";
import { getUser } from "../lib/dbx.js";
import { publicUser } from "../lib/serialize.js";
import { requireFleetClient, requireOwner } from "./auth.js";
import { getVehicleAccessLevel, getUserDetail } from "./vehicle-shares.js";

const SHARE_LIMITS = {
  free: { perVehicle: 1, total: 3 },
  premium: { perVehicle: 5, total: 20 },
} as const;

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

    const [organizationMembership] = await app.db.select({ membership: organizationMembers, organization: organizations })
      .from(organizationMembers)
      .innerJoin(organizations, eq(organizationMembers.orgId, organizations.id))
      .where(eq(organizationMembers.userId, userId))
      .limit(1);
    const organization = organizationMembership?.organization ?? null;
    const fleetFeature = Boolean(organization && organization.plan === "enterprise" && organization.status === "active");

    const limits = SHARE_LIMITS[user.plan];
    const [activeShares] = await app.db.select({ count: sql`count(*)` })
      .from(vehicleShares)
      .innerJoin(vehicles, eq(vehicleShares.vehicleId, vehicles.id))
      .where(and(eq(vehicles.userId, userId), eq(vehicleShares.status, "active")));

    return {
      plan: user.plan,
      vehicle_sharing: {
        available: true,
        can_share: true,
        limits: {
          per_vehicle: limits.perVehicle,
          total: limits.total,
        },
        active_shares: Number(activeShares?.count ?? 0),
      },
      organization: organization && organizationMembership ? {
        id: organization.id,
        type: organization.type,
        plan: organization.plan,
        status: organization.status,
        role: organizationMembership.membership.role,
      } : null,
      features: { vehicle_sharing: true, fleet: fleetFeature },
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
      // Owned vehicles and shared vehicles the user can access are
      // both valid active-vehicle targets (shared users can activate a
      // shared car to log maintenance/fuel/expenses against it).
      const allowed =
        v &&
        !v.archived &&
        (v.userId === userId ||
          (await getVehicleAccessLevel(app.db, userId, v.id)) !== null);
      if (!allowed) {
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

  // User detail with shared vehicles, owned vehicles
  app.get("/users/:userId/detail", async (request) => {
    requireOwner(request);
    const requestingUserId = request.authUser!.sub;
    const targetUserId = (request.params as { userId: string }).userId;
    // Malformed ids (e.g. a client bug) would surface as a Postgres cast
    // error — report them as not found instead of 500.
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(targetUserId)) {
      throw new AppError(404, "user_not_found", "User not found");
    }
    const detail = await getUserDetail(app.db, targetUserId, requestingUserId);
    if (!detail) throw new AppError(404, "user_not_found", "User not found");
    return detail;
  });
};
