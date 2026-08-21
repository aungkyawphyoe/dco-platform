import { sql } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";

export const healthPlugin: FastifyPluginAsync = async (app) => {
  app.get("/health", { config: { public: true } }, async () => ({ status: "ok" }));

  app.get("/ready", { config: { public: true } }, async (_request, reply) => {
    try {
      await app.db.execute(sql`select 1`);
      return { status: "ready" };
    } catch {
      return reply.code(503).send({
        error: { code: "not_ready", message: "Database unreachable", details: {} },
      });
    }
  });
};
