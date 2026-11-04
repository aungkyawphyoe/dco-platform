import { credentialBody, isDriver, publicDrivingLicense, saveCredentials } from "../lib/driver-credentials.js";
import { eq } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import type { Db } from "../db/client.js";
import { drivingLicenses, users } from "../db/schema.js";
import { recordChange } from "../lib/dbx.js";
import { AppError } from "../lib/errors.js";
import { requireOwner } from "./auth.js";

export const licensesPlugin: FastifyPluginAsync = async (app) => {
  const db = () => app.db;
  const uid = (request: { authUser?: { sub: string } }) => request.authUser!.sub;

  app.get("/users/me/license", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const [license] = await db().select().from(drivingLicenses).where(eq(drivingLicenses.userId, userId)).limit(1);
    if (!license) throw new AppError(404, "license_not_found", "No driving license saved yet");
    return publicDrivingLicense(license);
  });

  app.put("/users/me/license", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const body = credentialBody.parse(request.body);
    return db().transaction(tx => saveCredentials(tx, userId, body));

  });

  app.delete("/users/me/license", async (request, reply) => {
    requireOwner(request);
    const userId = uid(request);
    await db().transaction(async tx => {
      await tx.select().from(users).where(eq(users.id, userId)).for("update");
      const [license] = await tx.select().from(drivingLicenses).where(eq(drivingLicenses.userId, userId));
      if (await isDriver(tx,userId)) throw new AppError(422,"driver_credentials_required","Fleet drivers must retain their credentials");
      if (!license) return;
      await tx.delete(drivingLicenses).where(eq(drivingLicenses.id, license.id));
      await recordChange(tx as unknown as Db, { userId, entityType: "driving_license", entityId: license.id, op: "delete", payload: { id: license.id } });
    });
    return reply.code(204).send();
  });

  app.get("/users/:userId/license", async (request) => {
    requireOwner(request);
    const userId = uid(request);
    const targetUserId = (request.params as { userId: string }).userId;

    if (targetUserId !== userId) {
      throw new AppError(403, "private_document", "Driving licenses are private");
    }

    const [license] = await db().select().from(drivingLicenses).where(eq(drivingLicenses.userId, targetUserId)).limit(1);
    if (!license) throw new AppError(404, "license_not_found", "No driving license saved");
    return publicDrivingLicense(license);
  });
};
