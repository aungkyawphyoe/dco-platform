import { eq } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { users } from "../db/schema.js";
import { AppError } from "../lib/errors.js";
import { getUser } from "../lib/dbx.js";
import { requireOwner } from "./auth.js";

function settings(user: typeof users.$inferSelect) {
  return {
    enabled: user.emailRemindersEnabled,
    lead_days: user.emailReminderLeadDays,
    available: Boolean(user.email && user.emailVerified),
  };
}

export const reminderEmailsPlugin: FastifyPluginAsync = async (app) => {
  app.get("/me/reminder-emails", async (request) => {
    requireOwner(request);
    const user = await getUser(app.db, request.authUser!.sub);
    if (!user) throw new AppError(401, "unauthorized", "Unknown user");
    return settings(user);
  });

  app.put("/me/reminder-emails", async (request) => {
    requireOwner(request);
    const body = z.object({
      enabled: z.boolean(),
      lead_days: z.number().int().min(7).max(60),
    }).parse(request.body ?? {});
    const user = await getUser(app.db, request.authUser!.sub);
    if (!user) throw new AppError(401, "unauthorized", "Unknown user");
    if (body.enabled && (!user.email || !user.emailVerified)) {
      throw new AppError(409, "email_verification_required", "Verify your email before enabling email reminders");
    }
    const [updated] = await app.db
      .update(users)
      .set({
        emailRemindersEnabled: body.enabled,
        emailReminderLeadDays: body.lead_days,
      })
      .where(eq(users.id, user.id))
      .returning();
    return settings(updated);
  });
};
