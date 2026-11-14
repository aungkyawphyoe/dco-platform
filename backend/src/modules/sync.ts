import { and, eq, gt, isNull, or } from "drizzle-orm";
import type { FastifyInstance } from "fastify";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { currentRecord } from "../lib/record-ownership.js";
import { getVehicleAccessLevel } from "./vehicle-shares.js";
import { changeLog, planItems, serviceRecords, parts, fuelLogs, documents, expenses, mediaObjects, transferredVehicles } from "../db/schema.js";
import { assertPersonalGarageAllowed } from "../lib/personal-garage.js";
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
    const body = z.object({ operations: z.array(opSchema).max(100) }).parse(request.body);
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
    await assertPersonalGarageAllowed(app.db, request.authUser!.sub);
    const cursorRaw = (request.query as { cursor?: string }).cursor;
    if (cursorRaw === undefined) throw new AppError(400, "invalid_cursor", "cursor is required");
    let after = 0;
    if (cursorRaw !== "") {
      const parsed = Number(Buffer.from(cursorRaw, "base64url").toString("utf8"));
      if (!Number.isSafeInteger(parsed) || parsed < 0) throw new AppError(400, "invalid_cursor", "Cursor rejected");
      after = parsed;
    }
    const rows = await app.db
      .select()
      .from(changeLog)
      .where(and(eq(changeLog.userId, request.authUser!.sub), gt(changeLog.seq, after)))
      .orderBy(changeLog.seq).limit(200);
    const limited = rows;
    const nextSeq = limited.length ? limited[limited.length - 1].seq : after;
    const tables = { plan_item: planItems, service_record: serviceRecords, part: parts,
      fuel_log: fuelLogs, document: documents, expense: expenses, media: mediaObjects };
    const changes = [];
    for (const row of limited) {
      const payload = row.payload as Record<string, unknown>;
      const table = tables[row.entityType as keyof typeof tables];
      const vehicleId = row.entityType === "vehicle" ? row.entityId : typeof payload.vehicle_id === "string" ? payload.vehicle_id : undefined;
      let visible = !vehicleId || Boolean(await getVehicleAccessLevel(app.db, request.authUser!.sub, vehicleId));
      if (table && row.op !== "delete") {
        const scope = row.entityType === "media"
          ? or(isNull(mediaObjects.vehicleId), currentRecord(mediaObjects))
          : currentRecord(table);
        const [record] = await app.db.select({ vehicleId: table.vehicleId }).from(table)
          .where(and(eq(table.id, row.entityId), scope));
        // Standalone media is not vehicle history.
        visible = visible && Boolean(record);
        if (record?.vehicleId) visible = visible && Boolean(await getVehicleAccessLevel(app.db, request.authUser!.sub, record.vehicleId));
      }
      let responsePayload = payload;
      if (visible && row.entityType === "vehicle" && row.op !== "delete") {
        const [transfer] = await app.db.select({ id: transferredVehicles.id }).from(transferredVehicles)
          .where(and(eq(transferredVehicles.vehicleId, row.entityId), eq(transferredVehicles.buyerUserId, request.authUser!.sub))).limit(1);
        responsePayload = { ...payload, transfer_limit_exempt: Boolean(transfer) };
      }
      changes.push({ entity_type: row.entityType, entity_id: row.entityId,
        op: visible ? row.op : "delete", payload: visible ? responsePayload : { id: row.entityId, ...(vehicleId ? { vehicle_id: vehicleId } : {}) },
        server_ts: row.serverTs.toISOString() });
    }
    return {
      cursor: Buffer.from(String(nextSeq), "utf8").toString("base64url"),
      changes,
    };
  });
};

async function applyOp(app: FastifyInstance, auth: string, op: Op): Promise<"applied" | "idempotent"> {
  const headers = { authorization: auth };
  const payload = { ...op.payload, id: op.entity_id };
  const vehicleId = String(op.payload.vehicle_id ?? "");

  const call = async (method: "GET" | "POST" | "PATCH" | "DELETE", url: string, body?: object) => {
    return app.inject({
      method,
      url: `/v1${url}`,
      headers,
      ...(body ? { payload: body } : {}),
    });
  };

  // Upserts must update an existing row when the entity is already on the
  // server: POST create endpoints return 201 without applying changes, so
  // edits would be silently dropped. Try PATCH first, fall back to POST.
  const upsert = async (patchUrl: string, postUrl: string) => {
    const patched = await call("PATCH", patchUrl, payload);
    if (patched.statusCode === 404) return finish(await call("POST", postUrl, payload));
    return finish(patched);
  };

  if (op.entity_type === "vehicle" && op.op === "upsert") {
    const existing = await call("GET", `/vehicles/${op.entity_id}`);
    if (existing.statusCode === 200) {
      const changes = { ...op.payload };
      const currentMileage = existing.json().mileage;
      // Offline records can advance mileage before an older queued vehicle edit.
      // Preserve max(local, remote), while still applying the other edited fields.
      if (typeof changes.mileage === "number" && changes.mileage >= 0 &&
          typeof currentMileage === "number" && changes.mileage < currentMileage) {
        delete changes.mileage;
      }
      const res = await call("PATCH", `/vehicles/${op.entity_id}`, changes);
      return finish(res);
    }
    const res = await call("POST", "/vehicles", payload);
    return finish(res);
  }
  if (op.entity_type === "vehicle" && op.op === "archive") {
    return finish(await call("POST", `/vehicles/${op.entity_id}/archive`));
  }
  if (op.entity_type === "plan_item" && op.op === "upsert") {
    return upsert(`/plan-items/${op.entity_id}`, `/vehicles/${vehicleId}/plan-items`);
  }
  if (op.entity_type === "plan_item" && op.op === "delete") {
    return finish(await call("DELETE", `/plan-items/${op.entity_id}`));
  }
  if (op.entity_type === "service_record" && op.op === "delete") {
    return finish(await call("DELETE", `/service-records/${op.entity_id}`));
  }
  if (op.entity_type === "service_record" && op.op === "upsert") {
    return upsert(`/service-records/${op.entity_id}`, `/vehicles/${vehicleId}/service-records`);
  }
  if (op.entity_type === "document" && op.op === "upsert") {
    const existing = await call("GET", `/documents/${op.entity_id}`);
    if (existing.statusCode === 200) {
      return finish(await call("PATCH", `/documents/${op.entity_id}`, op.payload));
    }
    return finish(await call("POST", `/vehicles/${vehicleId}/documents`, payload));
  }
  if (op.entity_type === "document" && op.op === "delete") {
    return finish(await call("DELETE", `/documents/${op.entity_id}`));
  }
  if (op.entity_type === "expense" && op.op === "upsert") {
    return upsert(`/expenses/${op.entity_id}`, `/vehicles/${vehicleId}/expenses`);
  }
  if (op.entity_type === "expense" && op.op === "delete") {
    return finish(await call("DELETE", `/expenses/${op.entity_id}`));
  }
  if (op.entity_type === "part" && op.op === "upsert") {
    return upsert(`/parts/${op.entity_id}`, `/vehicles/${vehicleId}/parts`);
  }
  if (op.entity_type === "fuel_type" && op.op === "upsert") {
    return upsert(`/fuel-types/${op.entity_id}`, "/fuel-types");
  }
  if (op.entity_type === "fuel_log" && op.op === "upsert") {
    return upsert(`/fuel-logs/${op.entity_id}`, `/vehicles/${vehicleId}/fuel-logs`);
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
