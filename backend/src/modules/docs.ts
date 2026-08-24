import { existsSync } from "node:fs";
import path from "node:path";
import type { FastifyPluginAsync } from "fastify";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";

export const docsPlugin: FastifyPluginAsync = async (app) => {
  if (app.env.APP_ENV === "prod") return;

  const specPath = path.resolve(
    process.cwd(),
    app.env.OPENAPI_SPEC_PATH ?? "../architecture/openapi.yaml",
  );
  if (!existsSync(specPath)) {
    app.log.warn(`OpenAPI spec not found at ${specPath} — /docs disabled`);
    return;
  }

  await app.register(swagger, {
    mode: "static",
    specification: {
      path: specPath,
      baseDir: path.dirname(specPath),
    },
  });

  await app.register(swaggerUi, {
    routePrefix: "/docs",
    uiConfig: {
      persistAuthorization: true,
      displayOperationId: true,
      filter: true,
      tryItOutEnabled: true,
    },
  });

  app.log.info(`Swagger UI at /docs (spec: ${specPath})`);
};
