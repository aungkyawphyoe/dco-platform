import { eq } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { deviceTokens, users, vehicles } from "../db/schema.js";
import { newId } from "../lib/crypto.js";
import { AppError } from "../lib/errors.js";
import { getUser } from "../lib/dbx.js";
import { publicUser } from "../lib/serialize.js";
import { requireOwner } from "./auth.js";

export const mePlugin: FastifyPluginAsync = async (app) => {
  app.get("/me", async (request) => {
    const user = await getUser(app.db, request.authUser!.sub);
    if (!user) throw new AppError(401, "unauthorized", "Unknown user");
    return publicUser(user);
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
};
