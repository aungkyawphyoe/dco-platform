import Fastify from "fastify";
import cors from "@fastify/cors";
import multipart from "@fastify/multipart";
import { ZodError } from "zod";
import type { Env } from "./config/env.js";
import type { Db } from "./db/client.js";
import { AppError, errorBody } from "./lib/errors.js";
import type { Mailer } from "./lib/mail.js";
import { MEDIA_MAX_BYTES, type MediaStore } from "./lib/media.js";
import { attachAuth, authPlugin } from "./modules/auth.js";
import { healthPlugin } from "./modules/health.js";
import { mePlugin } from "./modules/me.js";
import { vehiclesPlugin } from "./modules/vehicles.js";
import { ownerPlugin } from "./modules/owner.js";
import { mediaPlugin } from "./modules/media.js";
import { syncPlugin } from "./modules/sync.js";
import { adminPlugin } from "./modules/admin.js";
import "./types.js";

export async function buildApp(deps: { env: Env; db: Db; mailer: Mailer; media: MediaStore }) {
  const app = Fastify({ logger: deps.env.APP_ENV !== "local" });
  app.decorate("env", deps.env);
  app.decorate("db", deps.db);
  app.decorate("mailer", deps.mailer);
  app.decorate("media", deps.media);

  await app.register(cors, {
    origin: deps.env.CORS_ORIGINS.split(",").map((s) => s.trim()),
  });
  await app.register(multipart, { limits: { fileSize: MEDIA_MAX_BYTES } });

  app.setErrorHandler((err, _request, reply) => {
    if (err instanceof AppError) {
      return reply.code(err.statusCode).send(errorBody(err));
    }
    if (err instanceof ZodError) {
      return reply.code(422).send({
        error: { code: "validation", message: "Invalid request", details: { issues: err.issues } },
      });
    }
    app.log.error(err);
    return reply.code(500).send({
      error: { code: "internal", message: "Internal server error", details: {} },
    });
  });

  await app.register(
    async (v1) => {
      await attachAuth(v1);
      await v1.register(healthPlugin);
      await v1.register(authPlugin);
      await v1.register(mePlugin);
      await v1.register(vehiclesPlugin);
      await v1.register(ownerPlugin);
      await v1.register(mediaPlugin);
      await v1.register(syncPlugin);
      await v1.register(adminPlugin);
    },
    { prefix: "/v1" },
  );

  return app;
}
