import { currencyPlugin } from './modules/currency.js';
import { currencyDatabaseError } from './lib/operational-currency.js';
import { billingRequest } from "./lib/subscription-access.js";
import { subscriptionsPlugin } from "./modules/subscriptions.js";
import { playBillingPlugin } from "./modules/play-billing.js";
import { promotionsPlugin } from "./modules/promotions.js";
import { fleetAnalyticsPlugin } from "./modules/fleet-analytics.js";
import { socialAuthPlugin } from "./modules/social-auth.js";
import { accountSecurityPlugin } from "./modules/account-security.js";
import Fastify from "fastify";
import cors from "@fastify/cors";
import multipart from "@fastify/multipart";
import { ZodError } from "zod";
import type { Env } from "./config/env.js";
import type { Db } from "./db/client.js";
import { AppError, errorBody } from "./lib/errors.js";
import { attachPublicRateLimits } from "./lib/rate-limit.js";
import type { Mailer } from "./lib/mail.js";
import { MEDIA_MAX_BYTES, type MediaStore } from "./lib/media.js";
import { attachAuth, authPlugin } from "./modules/auth.js";
import { healthPlugin } from "./modules/health.js";
import { pricingPlugin } from "./modules/pricing.js";
import { mePlugin } from "./modules/me.js";
import { vehiclesPlugin } from "./modules/vehicles.js";
import { ownerPlugin, organizationRecordsPlugin } from "./modules/owner.js";
import { vehicleSharesPlugin } from "./modules/vehicle-shares.js";
import { licensesPlugin } from "./modules/licenses.js";
import { mediaPlugin } from "./modules/media.js";
import { organizationSyncPlugin } from "./modules/organization-sync.js";
import { syncPlugin } from "./modules/sync.js";
import { adminPlugin } from "./modules/admin.js";
import { docsPlugin } from "./modules/docs.js";
import { profilePlugin } from "./modules/profile.js";
import { reminderEmailsPlugin } from "./modules/reminder-emails.js";
import { fleetPlugin } from "./modules/fleet.js";
import { fleetOperationsPlugin } from "./modules/fleet-operations.js";
import "./types.js";

export async function buildApp(deps: { env: Env; db: Db; mailer: Mailer; media: MediaStore }) {
  const app = Fastify({ trustProxy: deps.env.AUTH_TRUST_PROXY_HOPS > 0 ? (_address: string, hop: number) => hop < deps.env.AUTH_TRUST_PROXY_HOPS : false, logger: deps.env.APP_ENV === "local" ? false : {
    redact: ["req.headers.authorization", "req.headers.cookie"],
    serializers: { req: (req) => ({ method: req.method, url: req.url?.split("?")[0], remoteAddress: req.ip }) },
  } });
  app.addHook("onRequest", (request, _reply, done) => {
    billingRequest.run({ write: !["GET", "HEAD", "OPTIONS"].includes(request.method) }, done);
  });
  app.decorate("env", deps.env);
  app.decorate("db", deps.db);
  app.decorate("mailer", deps.mailer);
  app.decorate("media", deps.media);

  // Older mobile clients attach JSON Content-Type to bodyless DELETEs.
  // Normalize only requests whose HTTP framing says there is no body;
  // non-empty/chunked payloads must still go through normal JSON validation.
  app.addHook("onRequest", async (request) => {
    if (
      request.method === "DELETE" &&
      request.headers["content-type"]?.split(";")[0]?.trim().toLowerCase() === "application/json" &&
      request.headers["transfer-encoding"] === undefined &&
      (request.headers["content-length"] === undefined || request.headers["content-length"] === "0")
    ) {
      delete request.headers["content-type"];
    }
  });

  app.addHook("onSend", async (request, reply, payload) => {
    reply.header("X-Content-Type-Options", "nosniff").header("Referrer-Policy", "no-referrer");
    if (deps.env.APP_ENV === "prod") reply.header("Strict-Transport-Security", "max-age=31536000");
    if (request.url.startsWith("/v1/") && !request.url.startsWith("/v1/pricing")) reply.header("Cache-Control", "no-store");
    return payload;
  });

  await app.register(cors, {
    origin: deps.env.CORS_ORIGINS.split(",").map((s) => s.trim()),
    methods: ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    exposedHeaders: ["Retry-After"],
  });
  await app.register(multipart, { limits: { fileSize: MEDIA_MAX_BYTES } });

  app.setErrorHandler((err, _request, reply) => {
    const currencyError = currencyDatabaseError(err);
    if (currencyError) return reply.code(currencyError.statusCode).send(errorBody(currencyError));
    if (err instanceof AppError) {
      if (typeof err.details.retry_after === "number") {
        reply.header("Retry-After", String(err.details.retry_after)).header("Cache-Control", "no-store");
      }
      return reply.code(err.statusCode).send(errorBody(err));
    }
    if (err instanceof ZodError) {
      return reply.code(422).send({
        error: { code: "validation", message: "Invalid request", details: { issues: err.issues } },
      });
    }
    if (err instanceof Error && "code" in err && typeof err.code === "string" &&
        err.code.startsWith("FST_ERR_CTP_") && "statusCode" in err &&
        typeof err.statusCode === "number" && err.statusCode >= 400 && err.statusCode < 500) {
      return reply.code(err.statusCode).send({
        error: { code: "invalid_request_body", message: "Invalid request body", details: {} },
      });
    }
    app.log.error(err);
    return reply.code(500).send({
      error: { code: "internal", message: "Internal server error", details: {} },
    });
  });

  await app.register(docsPlugin);

  await app.register(
    async (v1) => {
      attachPublicRateLimits(v1);
      await attachAuth(v1);
      await v1.register(healthPlugin);
      await v1.register(currencyPlugin);
      await v1.register(pricingPlugin);
      await v1.register(subscriptionsPlugin);
      await v1.register(promotionsPlugin);
      await v1.register(playBillingPlugin);
      await v1.register(authPlugin);
      await v1.register(accountSecurityPlugin);
      await v1.register(socialAuthPlugin);
      await v1.register(mePlugin);
      await v1.register(vehiclesPlugin);
      await v1.register(ownerPlugin);
      await v1.register(organizationRecordsPlugin, { prefix: "/organizations/:organizationId/records" });
      await v1.register(vehicleSharesPlugin);
      await v1.register(licensesPlugin);
      await v1.register(mediaPlugin);
      await v1.register(syncPlugin);
      await v1.register(organizationSyncPlugin);
      await v1.register(profilePlugin);
      await v1.register(reminderEmailsPlugin);
      await v1.register(fleetPlugin);
      await v1.register(fleetOperationsPlugin);
      await v1.register(fleetAnalyticsPlugin);
      await v1.register(adminPlugin);
    },
    { prefix: "/v1" },
  );

  return app;
}
