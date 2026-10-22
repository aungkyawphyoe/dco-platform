import { desc, eq } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { playSubscriptions } from "../db/schema.js";
import { AppError } from "../lib/errors.js";
import { effectiveSubscription } from "../lib/gifts.js";
import { GooglePlayGateway, PLAY_PRODUCTS, playAccountId, playConfigured, playEnabled, verifyPlayPush } from "../lib/google-play.js";
import { syncPlayPurchase } from "../lib/play-subscriptions.js";
import { assertPersonalGarageAllowed } from "../lib/personal-garage.js";
import { requireOwner } from "./auth.js";
import { authLimit } from "./account-security.js";

export const playBillingPlugin: FastifyPluginAsync = async app => {
  const gateway = new GooglePlayGateway(app.env);
  const configured = () => {
    if (!playConfigured(app.env)) throw new AppError(503, "billing_unavailable", "Google Play billing is not enabled");
  };
  app.get("/me/play-billing", async request => {
    requireOwner(request);
    const userId = request.authUser!.sub;
    await assertPersonalGarageAllowed(app.db, userId);
    const sub = await effectiveSubscription(app.db, userId);
    const [latest] = await app.db.select().from(playSubscriptions).where(eq(playSubscriptions.userId, userId)).orderBy(desc(playSubscriptions.expiresAt)).limit(1);
    // Holds/paused/pending subscriptions must be resolved, not bought again.
    const existing = latest && !["SUBSCRIPTION_STATE_EXPIRED", "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED", "REPLACED"].includes(latest.state) &&
      (latest.expiresAt > new Date() || ["SUBSCRIPTION_STATE_ON_HOLD", "SUBSCRIPTION_STATE_PAUSED", "SUBSCRIPTION_STATE_PENDING"].includes(latest.state));
    return { enabled: playEnabled(app.env), account_id: playAccountId(userId),
      can_purchase: playEnabled(app.env) && sub.user.emailVerified && sub.plan === "free" && !existing,
      license_kid: app.env.LICENSE_KID, products: Object.keys(PLAY_PRODUCTS), package_name: app.env.PLAY_PACKAGE_NAME };
  });
  app.post("/me/play-purchases", async request => {
    requireOwner(request); configured();
    const userId = request.authUser!.sub;
    await assertPersonalGarageAllowed(app.db, userId);
    await authLimit(app.db, `play-verify:${userId}`, 60, 600);
    const body = z.object({ purchase_token: z.string().min(1).max(4096) }).strict().parse(request.body);
    return syncPlayPurchase(app.db, gateway, userId, body.purchase_token);
  });
  app.post("/billing/google-play/notifications", { config: { public: true } }, async (request, reply) => {
    configured();
    await verifyPlayPush(app.env, request.headers.authorization);
    const body = z.object({ message: z.object({ data: z.string().max(20000) }) }).parse(request.body);
    let decoded: unknown;
    try { decoded = JSON.parse(Buffer.from(body.message.data, "base64").toString("utf8")); }
    catch { throw new AppError(400, "invalid_notification", "Invalid notification payload"); }
    const data = z.object({ packageName: z.string(), testNotification: z.unknown().optional(),
      subscriptionNotification: z.object({ purchaseToken: z.string().max(4096) }).optional() }).parse(decoded);
    if (data.packageName !== app.env.PLAY_PACKAGE_NAME) throw new AppError(400, "invalid_package", "Wrong package");
    if (data.subscriptionNotification) {
      const token = data.subscriptionNotification.purchaseToken;
      const [row] = await app.db.select().from(playSubscriptions).where(eq(playSubscriptions.purchaseToken, token));
      // Unknown initial tokens are bound by authenticated app verification/restore.
      if (row) await syncPlayPurchase(app.db, gateway, row.userId, token);
    }
    return reply.code(204).send();
  });
};
