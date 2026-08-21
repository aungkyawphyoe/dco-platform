import { asc, desc, eq } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import {
  documents,
  expenseParts,
  expenses,
  fuelLogs,
  fuelTypes,
  notificationFeed,
  parts,
  planItems,
  serviceRecordItems,
  serviceRecordParts,
  serviceRecords,
  vehicles,
} from "../db/schema.js";
import { suggestedForFuel } from "../lib/catalog.js";
import { newId } from "../lib/crypto.js";
import { dateOnly, num, recordChange, reqNum } from "../lib/dbx.js";
import { AppError } from "../lib/errors.js";
import { requireOwner } from "./auth.js";
import { getOwnedVehicle } from "./vehicles.js";

const uuid = z.string().uuid();

function dueFrom(intervalDays: number | null | undefined, intervalDistance: number | null | undefined, mileage: number) {
  const nextDueOn =
    intervalDays && intervalDays > 0
      ? new Date(Date.now() + intervalDays * 86400000).toISOString().slice(0, 10)
      : null;
  const nextDueMileage =
    intervalDistance && intervalDistance > 0 ? mileage + intervalDistance : null;
  return { nextDueOn, nextDueMileage };
}

function publicPlan(row: typeof planItems.$inferSelect) {
  return {
    id: row.id,
    vehicle_id: row.vehicleId,
    name: row.name,
    interval_days: row.intervalDays,
    interval_distance: num(row.intervalDistance),
    next_due_mileage: num(row.nextDueMileage),
    next_due_on: dateOnly(row.nextDueOn),
    enabled: row.enabled,
    notes: row.notes,
    catalog_key: row.catalogKey,
  };
}

async function loadService(appDb: Db, id: string) {
  const [row] = await appDb.select().from(serviceRecords).where(eq(serviceRecords.id, id)).limit(1);
  if (!row) return null;
  const items = await appDb.select().from(serviceRecordItems).where(eq(serviceRecordItems.serviceRecordId, id));
  const assigned = await appDb.select().from(serviceRecordParts).where(eq(serviceRecordParts.serviceRecordId, id));
  return {
    id: row.id,
    vehicle_id: row.vehicleId,
    serviced_on: dateOnly(row.servicedOn),
    odometer: reqNum(row.odometer),
    total_cost: reqNum(row.totalCost),
    workshop_name: row.workshopName,
    notes: row.notes,
    receipt_media_id: row.receiptMediaId,
    items: items.map((i) => ({
      id: i.id,
      plan_item_id: i.planItemId,
      name: i.name,
      line_cost: num(i.lineCost),
    })),
    parts: assigned.map((p) => ({ id: p.id, part_id: p.partId, name: p.name })),
  };
}

export const ownerPlugin: FastifyPluginAsync = async (app) => {
  const db = () => app.db;
  const uid = (request: { authUser?: { sub: string } }) => request.authUser!.sub;

  app.get("/vehicles/:vehicleId/plan-items", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getOwnedVehicle(db(), uid(request), vehicleId, true);
    const items = await db().select().from(planItems).where(eq(planItems.vehicleId, vehicleId));
    return { items: items.map(publicPlan) };
  });

  app.post("/vehicles/:vehicleId/plan-items", async (request, reply) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const vehicle = await getOwnedVehicle(db(), uid(request), vehicleId);
    const body = z
      .object({
        id: uuid,
        name: z.string().min(1).max(80),
        interval_days: z.number().int().optional().nullable(),
        interval_distance: z.number().optional().nullable(),
        notes: z.string().optional().nullable(),
        catalog_key: z.string().optional().nullable(),
        enabled: z.boolean().optional(),
      })
      .parse(request.body);
    if (!body.interval_days && !body.interval_distance) {
      throw new AppError(422, "invalid_interval", "Provide a time interval, a distance interval, or both");
    }
    const [existing] = await db().select().from(planItems).where(eq(planItems.id, body.id)).limit(1);
    if (existing) return reply.code(201).send(publicPlan(existing));
    const due = dueFrom(body.interval_days, body.interval_distance, reqNum(vehicle.mileage));
    const [row] = await db()
      .insert(planItems)
      .values({
        id: body.id,
        vehicleId,
        name: body.name,
        intervalDays: body.interval_days ?? null,
        intervalDistance: body.interval_distance != null ? String(body.interval_distance) : null,
        nextDueOn: due.nextDueOn,
        nextDueMileage: due.nextDueMileage != null ? String(due.nextDueMileage) : null,
        notes: body.notes ?? null,
        catalogKey: body.catalog_key ?? null,
        enabled: body.enabled ?? true,
      })
      .returning();
    const payload = publicPlan(row);
    await recordChange(db(), { userId: uid(request), entityType: "plan_item", entityId: row.id, op: "upsert", payload });
    return reply.code(201).send(payload);
  });

  app.get("/vehicles/:vehicleId/suggested-plan-items", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const vehicle = await getOwnedVehicle(db(), uid(request), vehicleId);
    return { items: suggestedForFuel(vehicle.fuelType) };
  });

  app.patch("/plan-items/:planItemId", async (request) => {
    requireOwner(request);
    const { planItemId } = request.params as { planItemId: string };
    const [row] = await db().select().from(planItems).where(eq(planItems.id, planItemId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Plan item not found");
    await getOwnedVehicle(db(), uid(request), row.vehicleId, true);
    const body = z
      .object({
        name: z.string().optional(),
        interval_days: z.number().int().nullable().optional(),
        interval_distance: z.number().nullable().optional(),
        notes: z.string().optional().nullable(),
        enabled: z.boolean().optional(),
      })
      .parse(request.body ?? {});
    const [updated] = await db()
      .update(planItems)
      .set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.interval_days !== undefined ? { intervalDays: body.interval_days } : {}),
        ...(body.interval_distance !== undefined
          ? { intervalDistance: body.interval_distance != null ? String(body.interval_distance) : null }
          : {}),
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
        ...(body.enabled !== undefined ? { enabled: body.enabled } : {}),
      })
      .where(eq(planItems.id, planItemId))
      .returning();
    const payload = publicPlan(updated);
    await recordChange(db(), { userId: uid(request), entityType: "plan_item", entityId: updated.id, op: "upsert", payload });
    return payload;
  });

  app.delete("/plan-items/:planItemId", async (request, reply) => {
    requireOwner(request);
    const { planItemId } = request.params as { planItemId: string };
    const [row] = await db().select().from(planItems).where(eq(planItems.id, planItemId)).limit(1);
    if (!row) return reply.code(204).send();
    await getOwnedVehicle(db(), uid(request), row.vehicleId, true);
    await db().delete(planItems).where(eq(planItems.id, planItemId));
    await recordChange(db(), { userId: uid(request), entityType: "plan_item", entityId: planItemId, op: "delete", payload: { id: planItemId } });
    return reply.code(204).send();
  });

  const serviceBody = z.object({
    id: uuid,
    serviced_on: z.string(),
    odometer: z.number().min(0),
    total_cost: z.number().min(0),
    workshop_name: z.string().optional().nullable(),
    notes: z.string().optional().nullable(),
    receipt_media_id: uuid.optional().nullable(),
    items: z.array(z.object({
      id: uuid.optional(),
      plan_item_id: uuid.optional().nullable(),
      name: z.string(),
      line_cost: z.number().optional().nullable(),
    })).min(1),
    parts: z.array(z.object({ part_id: uuid, name: z.string(), id: uuid.optional() })).optional(),
  });

  app.get("/vehicles/:vehicleId/service-records", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getOwnedVehicle(db(), uid(request), vehicleId, true);
    const rows = await db().select().from(serviceRecords).where(eq(serviceRecords.vehicleId, vehicleId)).orderBy(desc(serviceRecords.servicedOn));
    const items = [];
    for (const row of rows) items.push(await loadService(db(), row.id));
    return { items };
  });

  app.post("/vehicles/:vehicleId/service-records", async (request, reply) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const vehicle = await getOwnedVehicle(db(), uid(request), vehicleId);
    const body = serviceBody.parse(request.body);
    const [existing] = await db().select().from(serviceRecords).where(eq(serviceRecords.id, body.id)).limit(1);
    if (existing) return reply.code(201).send(await loadService(db(), existing.id));
    if (body.odometer < reqNum(vehicle.mileage)) {
      throw new AppError(422, "mileage_decrease", "Service odometer cannot be below vehicle mileage");
    }
    await db().insert(serviceRecords).values({
      id: body.id,
      vehicleId,
      servicedOn: body.serviced_on,
      odometer: String(body.odometer),
      totalCost: String(body.total_cost),
      workshopName: body.workshop_name ?? null,
      notes: body.notes ?? null,
      receiptMediaId: body.receipt_media_id ?? null,
    });
    for (const item of body.items) {
      await db().insert(serviceRecordItems).values({
        id: item.id ?? newId(),
        serviceRecordId: body.id,
        planItemId: item.plan_item_id ?? null,
        name: item.name,
        lineCost: item.line_cost != null ? String(item.line_cost) : null,
      });
      if (item.plan_item_id) {
        const [plan] = await db().select().from(planItems).where(eq(planItems.id, item.plan_item_id)).limit(1);
        if (plan) {
          const due = dueFrom(plan.intervalDays, num(plan.intervalDistance), body.odometer);
          await db()
            .update(planItems)
            .set({
              nextDueOn: due.nextDueOn,
              nextDueMileage: due.nextDueMileage != null ? String(due.nextDueMileage) : null,
            })
            .where(eq(planItems.id, plan.id));
        }
      }
    }
    for (const part of body.parts ?? []) {
      await db().insert(serviceRecordParts).values({
        id: part.id ?? newId(),
        serviceRecordId: body.id,
        partId: part.part_id,
        name: part.name,
      });
    }
    if (body.odometer > reqNum(vehicle.mileage)) {
      await db().update(vehicles).set({ mileage: String(body.odometer), updatedAt: new Date() }).where(eq(vehicles.id, vehicleId));
    }
    const payload = await loadService(db(), body.id);
    await recordChange(db(), { userId: uid(request), entityType: "service_record", entityId: body.id, op: "upsert", payload });
    return reply.code(201).send(payload);
  });

  app.get("/service-records/:serviceRecordId", async (request) => {
    requireOwner(request);
    const { serviceRecordId } = request.params as { serviceRecordId: string };
    const payload = await loadService(db(), serviceRecordId);
    if (!payload) throw new AppError(404, "not_found", "Service record not found");
    await getOwnedVehicle(db(), uid(request), payload.vehicle_id, true);
    return payload;
  });

  app.patch("/service-records/:serviceRecordId", async (request) => {
    requireOwner(request);
    const { serviceRecordId } = request.params as { serviceRecordId: string };
    const existing = await loadService(db(), serviceRecordId);
    if (!existing) throw new AppError(404, "not_found", "Service record not found");
    await getOwnedVehicle(db(), uid(request), existing.vehicle_id);
    const body = serviceBody.partial().parse(request.body ?? {});
    await db()
      .update(serviceRecords)
      .set({
        ...(body.serviced_on ? { servicedOn: body.serviced_on } : {}),
        ...(body.odometer !== undefined ? { odometer: String(body.odometer) } : {}),
        ...(body.total_cost !== undefined ? { totalCost: String(body.total_cost) } : {}),
        ...(body.workshop_name !== undefined ? { workshopName: body.workshop_name } : {}),
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
        ...(body.receipt_media_id !== undefined ? { receiptMediaId: body.receipt_media_id } : {}),
      })
      .where(eq(serviceRecords.id, serviceRecordId));
    const payload = await loadService(db(), serviceRecordId);
    await recordChange(db(), { userId: uid(request), entityType: "service_record", entityId: serviceRecordId, op: "upsert", payload });
    return payload;
  });

  app.get("/vehicles/:vehicleId/parts", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getOwnedVehicle(db(), uid(request), vehicleId, true);
    const items = await db().select().from(parts).where(eq(parts.vehicleId, vehicleId)).orderBy(asc(parts.name));
    return {
      items: items.map((p) => ({
        id: p.id,
        vehicle_id: p.vehicleId,
        name: p.name,
        brand: p.brand,
        part_number: p.partNumber,
        notes: p.notes,
      })),
    };
  });

  app.post("/vehicles/:vehicleId/parts", async (request, reply) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getOwnedVehicle(db(), uid(request), vehicleId);
    const body = z.object({
      id: uuid,
      name: z.string().min(1),
      brand: z.string().optional().nullable(),
      part_number: z.string().optional().nullable(),
      notes: z.string().optional().nullable(),
    }).parse(request.body);
    const [existing] = await db().select().from(parts).where(eq(parts.id, body.id)).limit(1);
    if (existing) {
      return reply.code(201).send({
        id: existing.id,
        vehicle_id: existing.vehicleId,
        name: existing.name,
        brand: existing.brand,
        part_number: existing.partNumber,
        notes: existing.notes,
      });
    }
    const [row] = await db()
      .insert(parts)
      .values({
        id: body.id,
        vehicleId,
        name: body.name,
        brand: body.brand ?? null,
        partNumber: body.part_number ?? null,
        notes: body.notes ?? null,
      })
      .returning();
    const payload = {
      id: row.id,
      vehicle_id: row.vehicleId,
      name: row.name,
      brand: row.brand,
      part_number: row.partNumber,
      notes: row.notes,
    };
    await recordChange(db(), { userId: uid(request), entityType: "part", entityId: row.id, op: "upsert", payload });
    return reply.code(201).send(payload);
  });

  app.patch("/parts/:partId", async (request) => {
    requireOwner(request);
    const { partId } = request.params as { partId: string };
    const [row] = await db().select().from(parts).where(eq(parts.id, partId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Part not found");
    await getOwnedVehicle(db(), uid(request), row.vehicleId, true);
    const body = z.object({
      name: z.string().optional(),
      brand: z.string().optional().nullable(),
      part_number: z.string().optional().nullable(),
      notes: z.string().optional().nullable(),
    }).parse(request.body ?? {});
    const [updated] = await db()
      .update(parts)
      .set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.brand !== undefined ? { brand: body.brand } : {}),
        ...(body.part_number !== undefined ? { partNumber: body.part_number } : {}),
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
      })
      .where(eq(parts.id, partId))
      .returning();
    const payload = {
      id: updated.id,
      vehicle_id: updated.vehicleId,
      name: updated.name,
      brand: updated.brand,
      part_number: updated.partNumber,
      notes: updated.notes,
    };
    await recordChange(db(), { userId: uid(request), entityType: "part", entityId: updated.id, op: "upsert", payload });
    return payload;
  });

  const publicFuelType = (row: typeof fuelTypes.$inferSelect) => ({
    id: row.id,
    user_id: row.userId,
    name: row.name,
    kind: row.kind,
    unit: row.unit,
  });

  app.get("/fuel-types", async (request) => {
    requireOwner(request);
    const items = await db().select().from(fuelTypes).where(eq(fuelTypes.userId, uid(request)));
    return { items: items.map(publicFuelType) };
  });

  app.post("/fuel-types", async (request, reply) => {
    requireOwner(request);
    const body = z.object({
      id: uuid,
      name: z.string().min(1),
      kind: z.enum(["liquid", "electric"]),
      unit: z.string().min(1),
    }).parse(request.body);
    const [existing] = await db().select().from(fuelTypes).where(eq(fuelTypes.id, body.id)).limit(1);
    if (existing) return reply.code(201).send(publicFuelType(existing));
    const clash = await db().select().from(fuelTypes).where(eq(fuelTypes.userId, uid(request)));
    if (clash.some((t) => t.name.toLowerCase() === body.name.toLowerCase())) {
      throw new AppError(409, "name_taken", "Fuel type name already exists");
    }
    const [row] = await db()
      .insert(fuelTypes)
      .values({ id: body.id, userId: uid(request), name: body.name, kind: body.kind, unit: body.unit })
      .returning();
    const payload = publicFuelType(row);
    await recordChange(db(), { userId: uid(request), entityType: "fuel_type", entityId: row.id, op: "upsert", payload });
    return reply.code(201).send(payload);
  });

  app.patch("/fuel-types/:fuelTypeId", async (request) => {
    requireOwner(request);
    const { fuelTypeId } = request.params as { fuelTypeId: string };
    const [row] = await db().select().from(fuelTypes).where(eq(fuelTypes.id, fuelTypeId)).limit(1);
    if (!row || row.userId !== uid(request)) throw new AppError(404, "not_found", "Fuel type not found");
    const body = z.object({
      name: z.string().optional(),
      kind: z.enum(["liquid", "electric"]).optional(),
      unit: z.string().optional(),
    }).parse(request.body ?? {});
    const [updated] = await db()
      .update(fuelTypes)
      .set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.kind !== undefined ? { kind: body.kind } : {}),
        ...(body.unit !== undefined ? { unit: body.unit } : {}),
      })
      .where(eq(fuelTypes.id, fuelTypeId))
      .returning();
    const payload = publicFuelType(updated);
    await recordChange(db(), { userId: uid(request), entityType: "fuel_type", entityId: updated.id, op: "upsert", payload });
    return payload;
  });

  const publicFuelLog = (row: typeof fuelLogs.$inferSelect) => ({
    id: row.id,
    user_id: row.userId,
    vehicle_id: row.vehicleId,
    kind: row.kind,
    fuel_type_id: row.fuelTypeId,
    fuel_type_name: row.fuelTypeName,
    unit: row.unit,
    logged_on: dateOnly(row.loggedOn),
    amount: reqNum(row.amount),
    cost: reqNum(row.cost),
  });

  app.get("/vehicles/:vehicleId/fuel-logs", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getOwnedVehicle(db(), uid(request), vehicleId, true);
    const q = request.query as { fuel_type_id?: string; month?: string };
    let rows = await db().select().from(fuelLogs).where(eq(fuelLogs.vehicleId, vehicleId)).orderBy(desc(fuelLogs.loggedOn));
    if (q.fuel_type_id) rows = rows.filter((r) => r.fuelTypeId === q.fuel_type_id);
    if (q.month === "this_month") {
      const prefix = new Date().toISOString().slice(0, 7);
      rows = rows.filter((r) => dateOnly(r.loggedOn)?.startsWith(prefix));
    }
    return { items: rows.map(publicFuelLog) };
  });

  app.post("/vehicles/:vehicleId/fuel-logs", async (request, reply) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const vehicle = await getOwnedVehicle(db(), uid(request), vehicleId);
    const body = z.object({
      id: uuid,
      fuel_type_id: uuid,
      logged_on: z.string(),
      amount: z.number().positive(),
      cost: z.number().min(0),
    }).parse(request.body);
    if (body.logged_on > new Date().toISOString().slice(0, 10)) {
      throw new AppError(422, "invalid_date", "Date cannot be in the future");
    }
    const [existing] = await db().select().from(fuelLogs).where(eq(fuelLogs.id, body.id)).limit(1);
    if (existing) return reply.code(201).send(publicFuelLog(existing));
    const [ft] = await db().select().from(fuelTypes).where(eq(fuelTypes.id, body.fuel_type_id)).limit(1);
    if (!ft || ft.userId !== uid(request)) throw new AppError(422, "invalid_fuel_type", "Unknown fuel type");
    const kind = vehicle.fuelType === "electric" ? "charge" : "refuel";
    if (kind === "charge" && ft.kind !== "electric") {
      throw new AppError(422, "invalid_fuel_type", "Electric vehicles log charge types");
    }
    if (kind === "refuel" && ft.kind !== "liquid") {
      throw new AppError(422, "invalid_fuel_type", "Petrol and hybrid vehicles log liquid types");
    }
    const [row] = await db()
      .insert(fuelLogs)
      .values({
        id: body.id,
        userId: uid(request),
        vehicleId,
        kind,
        fuelTypeId: ft.id,
        fuelTypeName: ft.name,
        unit: ft.unit,
        loggedOn: body.logged_on,
        amount: String(body.amount),
        cost: String(body.cost),
      })
      .returning();
    const payload = publicFuelLog(row);
    await recordChange(db(), { userId: uid(request), entityType: "fuel_log", entityId: row.id, op: "upsert", payload });
    return reply.code(201).send(payload);
  });

  app.get("/fuel-logs/:fuelLogId", async (request) => {
    requireOwner(request);
    const { fuelLogId } = request.params as { fuelLogId: string };
    const [row] = await db().select().from(fuelLogs).where(eq(fuelLogs.id, fuelLogId)).limit(1);
    if (!row || row.userId !== uid(request)) throw new AppError(404, "not_found", "Fuel log not found");
    return publicFuelLog(row);
  });

  app.patch("/fuel-logs/:fuelLogId", async (request) => {
    requireOwner(request);
    const { fuelLogId } = request.params as { fuelLogId: string };
    const [row] = await db().select().from(fuelLogs).where(eq(fuelLogs.id, fuelLogId)).limit(1);
    if (!row || row.userId !== uid(request)) throw new AppError(404, "not_found", "Fuel log not found");
    const body = z.object({
      fuel_type_id: uuid.optional(),
      logged_on: z.string().optional(),
      amount: z.number().optional(),
      cost: z.number().optional(),
    }).parse(request.body ?? {});
    let fuelTypeName = row.fuelTypeName;
    let unit = row.unit;
    let fuelTypeId = row.fuelTypeId;
    if (body.fuel_type_id) {
      const [ft] = await db().select().from(fuelTypes).where(eq(fuelTypes.id, body.fuel_type_id)).limit(1);
      if (!ft || ft.userId !== uid(request)) throw new AppError(422, "invalid_fuel_type", "Unknown fuel type");
      fuelTypeName = ft.name;
      unit = ft.unit;
      fuelTypeId = ft.id;
    }
    const [updated] = await db()
      .update(fuelLogs)
      .set({
        ...(body.logged_on ? { loggedOn: body.logged_on } : {}),
        ...(body.amount !== undefined ? { amount: String(body.amount) } : {}),
        ...(body.cost !== undefined ? { cost: String(body.cost) } : {}),
        fuelTypeId,
        fuelTypeName,
        unit,
      })
      .where(eq(fuelLogs.id, fuelLogId))
      .returning();
    const payload = publicFuelLog(updated);
    await recordChange(db(), { userId: uid(request), entityType: "fuel_log", entityId: updated.id, op: "upsert", payload });
    return payload;
  });

  const publicDoc = (row: typeof documents.$inferSelect) => ({
    id: row.id,
    vehicle_id: row.vehicleId,
    name: row.name,
    category: row.category,
    notes: row.notes,
    media_id: row.mediaId,
    created_at: row.createdAt.toISOString(),
  });

  app.get("/vehicles/:vehicleId/documents", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getOwnedVehicle(db(), uid(request), vehicleId, true);
    const category = (request.query as { category?: string }).category;
    let rows = await db().select().from(documents).where(eq(documents.vehicleId, vehicleId));
    if (category) rows = rows.filter((r) => r.category === category);
    return { items: rows.map(publicDoc) };
  });

  app.post("/vehicles/:vehicleId/documents", async (request, reply) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getOwnedVehicle(db(), uid(request), vehicleId);
    const body = z.object({
      id: uuid,
      name: z.string().min(1).max(120),
      category: z.enum(["insurance", "registration", "invoice", "warranty", "receipt", "other"]),
      notes: z.string().optional().nullable(),
      media_id: uuid.optional().nullable(),
    }).parse(request.body);
    const [existing] = await db().select().from(documents).where(eq(documents.id, body.id)).limit(1);
    if (existing) return reply.code(201).send(publicDoc(existing));
    const [row] = await db()
      .insert(documents)
      .values({
        id: body.id,
        vehicleId,
        name: body.name,
        category: body.category,
        notes: body.notes ?? null,
        mediaId: body.media_id ?? null,
      })
      .returning();
    const payload = publicDoc(row);
    await recordChange(db(), { userId: uid(request), entityType: "document", entityId: row.id, op: "upsert", payload });
    return reply.code(201).send(payload);
  });

  app.get("/documents/:documentId", async (request) => {
    requireOwner(request);
    const { documentId } = request.params as { documentId: string };
    const [row] = await db().select().from(documents).where(eq(documents.id, documentId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Document not found");
    await getOwnedVehicle(db(), uid(request), row.vehicleId, true);
    return publicDoc(row);
  });

  app.patch("/documents/:documentId", async (request) => {
    requireOwner(request);
    const { documentId } = request.params as { documentId: string };
    const [row] = await db().select().from(documents).where(eq(documents.id, documentId)).limit(1);
    if (!row) throw new AppError(404, "not_found", "Document not found");
    await getOwnedVehicle(db(), uid(request), row.vehicleId, true);
    const body = z.object({
      name: z.string().optional(),
      category: z.enum(["insurance", "registration", "invoice", "warranty", "receipt", "other"]).optional(),
      notes: z.string().optional().nullable(),
      media_id: uuid.optional().nullable(),
    }).parse(request.body ?? {});
    const [updated] = await db()
      .update(documents)
      .set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.category !== undefined ? { category: body.category } : {}),
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
        ...(body.media_id !== undefined ? { mediaId: body.media_id } : {}),
      })
      .where(eq(documents.id, documentId))
      .returning();
    const payload = publicDoc(updated);
    await recordChange(db(), { userId: uid(request), entityType: "document", entityId: updated.id, op: "upsert", payload });
    return payload;
  });

  app.delete("/documents/:documentId", async (request, reply) => {
    requireOwner(request);
    const { documentId } = request.params as { documentId: string };
    const [row] = await db().select().from(documents).where(eq(documents.id, documentId)).limit(1);
    if (row) {
      await getOwnedVehicle(db(), uid(request), row.vehicleId, true);
      await db().delete(documents).where(eq(documents.id, documentId));
      await recordChange(db(), { userId: uid(request), entityType: "document", entityId: documentId, op: "delete", payload: { id: documentId } });
    }
    return reply.code(204).send();
  });

  const publicExpense = async (id: string) => {
    const [row] = await db().select().from(expenses).where(eq(expenses.id, id)).limit(1);
    if (!row) return null;
    const assigned = await db().select().from(expenseParts).where(eq(expenseParts.expenseId, id));
    return {
      id: row.id,
      vehicle_id: row.vehicleId,
      category: row.category,
      amount: reqNum(row.amount),
      incurred_on: dateOnly(row.incurredOn),
      notes: row.notes,
      receipt_media_id: row.receiptMediaId,
      parts: assigned.map((p) => ({ id: p.id, part_id: p.partId, name: p.name })),
    };
  };

  const expenseBody = z.object({
    id: uuid,
    category: z.enum(["fuel", "maintenance", "insurance", "parking", "tolls", "parts", "other"]),
    amount: z.number().min(0.01).max(999999.99),
    incurred_on: z.string(),
    notes: z.string().max(500).optional().nullable(),
    receipt_media_id: uuid.optional().nullable(),
    parts: z.array(z.object({ part_id: uuid, name: z.string(), id: uuid.optional() })).optional(),
  });

  app.get("/vehicles/:vehicleId/expenses", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getOwnedVehicle(db(), uid(request), vehicleId, true);
    const category = (request.query as { category?: string }).category;
    let rows = await db().select().from(expenses).where(eq(expenses.vehicleId, vehicleId)).orderBy(desc(expenses.incurredOn));
    if (category) rows = rows.filter((r) => r.category === category);
    const items = [];
    for (const row of rows) items.push(await publicExpense(row.id));
    return { items };
  });

  app.post("/vehicles/:vehicleId/expenses", async (request, reply) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getOwnedVehicle(db(), uid(request), vehicleId);
    const body = expenseBody.parse(request.body);
    const [existing] = await db().select().from(expenses).where(eq(expenses.id, body.id)).limit(1);
    if (existing) return reply.code(201).send(await publicExpense(existing.id));
    await db().insert(expenses).values({
      id: body.id,
      vehicleId,
      category: body.category,
      amount: String(body.amount),
      incurredOn: body.incurred_on,
      notes: body.notes ?? null,
      receiptMediaId: body.receipt_media_id ?? null,
    });
    for (const part of body.parts ?? []) {
      await db().insert(expenseParts).values({
        id: part.id ?? newId(),
        expenseId: body.id,
        partId: part.part_id,
        name: part.name,
      });
    }
    const payload = await publicExpense(body.id);
    await recordChange(db(), { userId: uid(request), entityType: "expense", entityId: body.id, op: "upsert", payload });
    return reply.code(201).send(payload);
  });

  app.get("/vehicles/:vehicleId/expenses/summary", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getOwnedVehicle(db(), uid(request), vehicleId, true);
    const rows = await db().select().from(expenses).where(eq(expenses.vehicleId, vehicleId));
    const prefix = new Date().toISOString().slice(0, 7);
    const total = rows.reduce((s, e) => s + reqNum(e.amount), 0);
    const thisMonth = rows.filter((e) => dateOnly(e.incurredOn)?.startsWith(prefix)).reduce((s, e) => s + reqNum(e.amount), 0);
    const byCat = new Map<string, number>();
    for (const e of rows) byCat.set(e.category, (byCat.get(e.category) ?? 0) + reqNum(e.amount));
    return {
      this_month: thisMonth,
      total,
      by_category: [...byCat.entries()].map(([category, amount]) => ({
        category,
        amount,
        percent: total ? (amount / total) * 100 : 0,
      })),
    };
  });

  app.patch("/expenses/:expenseId", async (request) => {
    requireOwner(request);
    const { expenseId } = request.params as { expenseId: string };
    const current = await publicExpense(expenseId);
    if (!current) throw new AppError(404, "not_found", "Expense not found");
    await getOwnedVehicle(db(), uid(request), current.vehicle_id, true);
    const body = expenseBody.partial().parse(request.body ?? {});
    await db()
      .update(expenses)
      .set({
        ...(body.category ? { category: body.category } : {}),
        ...(body.amount !== undefined ? { amount: String(body.amount) } : {}),
        ...(body.incurred_on ? { incurredOn: body.incurred_on } : {}),
        ...(body.notes !== undefined ? { notes: body.notes } : {}),
        ...(body.receipt_media_id !== undefined ? { receiptMediaId: body.receipt_media_id } : {}),
      })
      .where(eq(expenses.id, expenseId));
    const payload = await publicExpense(expenseId);
    await recordChange(db(), { userId: uid(request), entityType: "expense", entityId: expenseId, op: "upsert", payload });
    return payload;
  });

  app.delete("/expenses/:expenseId", async (request, reply) => {
    requireOwner(request);
    const { expenseId } = request.params as { expenseId: string };
    const current = await publicExpense(expenseId);
    if (current) {
      await getOwnedVehicle(db(), uid(request), current.vehicle_id, true);
      await db().delete(expenseParts).where(eq(expenseParts.expenseId, expenseId));
      await db().delete(expenses).where(eq(expenses.id, expenseId));
      await recordChange(db(), { userId: uid(request), entityType: "expense", entityId: expenseId, op: "delete", payload: { id: expenseId } });
    }
    return reply.code(204).send();
  });

  app.get("/notifications", async (request) => {
    requireOwner(request);
    const rows = await db()
      .select()
      .from(notificationFeed)
      .where(eq(notificationFeed.userId, uid(request)))
      .orderBy(desc(notificationFeed.createdAt));
    return {
      items: rows.map((n) => ({
        id: n.id,
        vehicle_id: n.vehicleId,
        plan_item_id: n.planItemId,
        title: n.title,
        body: n.body,
        status: n.status,
        due_reason: n.dueReason,
        created_at: n.createdAt.toISOString(),
      })),
    };
  });

  app.patch("/notifications/:notificationId", async (request) => {
    requireOwner(request);
    const { notificationId } = request.params as { notificationId: string };
    const body = z.object({ status: z.enum(["unread", "read", "done", "dismissed"]) }).parse(request.body ?? {});
    const [row] = await db().select().from(notificationFeed).where(eq(notificationFeed.id, notificationId)).limit(1);
    if (!row || row.userId !== uid(request)) throw new AppError(404, "not_found", "Notification not found");
    const [updated] = await db()
      .update(notificationFeed)
      .set({ status: body.status })
      .where(eq(notificationFeed.id, notificationId))
      .returning();
    const payload = {
      id: updated.id,
      vehicle_id: updated.vehicleId,
      plan_item_id: updated.planItemId,
      title: updated.title,
      body: updated.body,
      status: updated.status,
      due_reason: updated.dueReason,
      created_at: updated.createdAt.toISOString(),
    };
    await recordChange(db(), { userId: uid(request), entityType: "notification", entityId: updated.id, op: "upsert", payload });
    return payload;
  });
};
