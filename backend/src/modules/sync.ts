import { and, eq, gt } from "drizzle-orm";
import type { FastifyInstance } from "fastify";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { changeLog } from "../db/schema.js";
import { AppError } from "../lib/errors.js";
import { requireOwner } from "./auth.js";

const opSchema = z.object({
  entity_type: z.enum([
    "vehicle",
    "plan_item",
    "service_record",
    "document",
    "expense",
    "notification",
    "media",
    "part",
    "fuel_type",
    "fuel_log",
  ]),
  entity_id: z.string().uuid(),
  op: z.enum(["upsert", "archive", "delete"]),
  payload: z.record(z.unknown()),
  client_ts: z.string(),
});

type Op = z.infer<typeof opSchema>;

export const syncPlugin: FastifyPluginAsync = async (app) => {
  app.post("/sync/push", async (request) => {
    requireOwner(request);
    const body = z.object({ operations: z.array(opSchema) }).parse(request.body);
    const auth = request.headers.authorization ?? "";
    const results = [];
    for (const op of body.operations) {
      try {
        const status = await applyOp(app, auth, op);
        results.push({ entity_id: op.entity_id, status, server_ts: new Date().toISOString() });
      } catch (err) {
        const appErr = err as { statusCode?: number; code?: string; message?: string; details?: unknown };
        results.push({
          entity_id: op.entity_id,
          status: appErr.statusCode === 409 ? "conflict" : "rejected",
          server_ts: new Date().toISOString(),
          error: {
            error: {
              code: appErr.code ?? "rejected",
              message: appErr.message ?? "Rejected",
              details: appErr.details ?? {},
            },
          },
        });
      }
    }
    return { results };
  });

  app.get("/sync/changes", async (request) => {
    requireOwner(request);
    const cursorRaw = (request.query as { cursor?: string }).cursor;
    if (cursorRaw === undefined) throw new AppError(400, "invalid_cursor", "cursor is required");
    let after = 0;
    if (cursorRaw !== "") {
      const parsed = Number(Buffer.from(cursorRaw, "base64url").toString("utf8"));
      if (!Number.isFinite(parsed)) throw new AppError(400, "invalid_cursor", "Cursor rejected");
      after = parsed;
    }
    const rows = await app.db
      .select()
      .from(changeLog)
      .where(and(eq(changeLog.userId, request.authUser!.sub), gt(changeLog.seq, after)))
      .orderBy(changeLog.seq);
    const limited = rows.slice(0, 200);
    const nextSeq = limited.length ? limited[limited.length - 1].seq : after;
    return {
      cursor: Buffer.from(String(nextSeq), "utf8").toString("base64url"),
      changes: limited.map((row) => ({
        entity_type: row.entityType,
        entity_id: row.entityId,
        op: row.op,
        payload: row.payload,
        server_ts: row.serverTs.toISOString(),
      })),
    };
  });
};

async function applyOp(app: FastifyInstance, auth: string, op: Op): Promise<"applied" | "idempotent"> {
  const headers = { authorization: auth };
  const payload = { id: op.entity_id, ...op.payload };
  const vehicleId = String(op.payload.vehicle_id ?? "");

  const call = async (method: "GET" | "POST" | "PATCH" | "DELETE", url: string, body?: object) => {
    return app.inject({
      method,
      url: `/v1${url}`,
      headers,
      ...(body ? { payload: body } : {}),
    });
  };

  if (op.entity_type === "vehicle" && op.op === "upsert") {
    const existing = await call("GET", `/vehicles/${op.entity_id}`);
    if (existing.statusCode === 200) {
      const res = await call("PATCH", `/vehicles/${op.entity_id}`, op.payload);
      return finish(res);
    }
    const res = await call("POST", "/vehicles", payload);
    return finish(res);
  }
  if (op.entity_type === "vehicle" && op.op === "archive") {
    return finish(await call("POST", `/vehicles/${op.entity_id}/archive`));
  }
  if (op.entity_type === "plan_item" && op.op === "upsert") {
    if (vehicleId) return finish(await call("POST", `/vehicles/${vehicleId}/plan-items`, payload));
    return finish(await call("PATCH", `/plan-items/${op.entity_id}`, op.payload));
  }
  if (op.entity_type === "plan_item" && op.op === "delete") {
    return finish(await call("DELETE", `/plan-items/${op.entity_id}`));
  }
  if (op.entity_type === "service_record" && op.op === "upsert") {
    return finish(await call("POST", `/vehicles/${vehicleId}/service-records`, payload));
  }
  if (op.entity_type === "document" && op.op === "upsert") {
    return finish(await call("POST", `/vehicles/${vehicleId}/documents`, payload));
  }
  if (op.entity_type === "document" && op.op === "delete") {
    return finish(await call("DELETE", `/documents/${op.entity_id}`));
  }
  if (op.entity_type === "expense" && op.op === "upsert") {
    return finish(await call("POST", `/vehicles/${vehicleId}/expenses`, payload));
  }
  if (op.entity_type === "expense" && op.op === "delete") {
    return finish(await call("DELETE", `/expenses/${op.entity_id}`));
  }
  if (op.entity_type === "part" && op.op === "upsert") {
    return finish(await call("POST", `/vehicles/${vehicleId}/parts`, payload));
  }
  if (op.entity_type === "fuel_type" && op.op === "upsert") {
    return finish(await call("POST", "/fuel-types", payload));
  }
  if (op.entity_type === "fuel_log" && op.op === "upsert") {
    return finish(await call("POST", `/vehicles/${vehicleId}/fuel-logs`, payload));
  }
  if (op.entity_type === "notification" && op.op === "upsert") {
    return finish(await call("PATCH", `/notifications/${op.entity_id}`, op.payload));
  }
  throw new AppError(422, "unsupported", `Unsupported ${op.entity_type} ${op.op}`);
}

function finish(res: { statusCode: number; json: () => unknown }): "applied" | "idempotent" {
  if (res.statusCode === 201) return "idempotent";
  if (res.statusCode === 200 || res.statusCode === 204) return "applied";
  const body = typeof res.json === "function" ? res.json() : undefined;
  const errBody = body as { error?: { code?: string; message?: string; details?: unknown } } | undefined;
  throw new AppError(
    res.statusCode,
    errBody?.error?.code ?? "sync_rejected",
    errBody?.error?.message ?? "Sync operation rejected",
    (errBody?.error?.details as Record<string, unknown>) ?? {},
  );
}
