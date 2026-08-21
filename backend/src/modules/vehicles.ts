import { and, asc, desc, eq } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import { documents, expenses, planItems, serviceRecords, users, vehicles } from "../db/schema.js";
import { AppError } from "../lib/errors.js";
import { dateOnly, getUser, num, recordChange, reqNum } from "../lib/dbx.js";
import { publicUser, publicVehicle } from "../lib/serialize.js";
import { requireOwner } from "./auth.js";

const fuelEnum = z.enum(["petrol", "electric", "hybrid_plugin"]);

const vehicleWrite = z.object({
  id: z.string().uuid(),
  name: z.string().min(1),
  nickname: z.string().optional().nullable(),
  make: z.string().min(1),
  model: z.string().min(1),
  year: z.number().int(),
  license_plate: z.string().min(1).max(20),
  vin: z.string().length(17).optional().nullable(),
  color: z.string().optional().nullable(),
  fuel_type: fuelEnum,
  mileage: z.number().min(0),
  mileage_unit: z.enum(["mi", "km"]).optional(),
  purchase_date: z.string().optional().nullable(),
  purchase_price: z.number().optional().nullable(),
  photo_media_id: z.string().uuid().optional().nullable(),
});

const vehiclePatch = vehicleWrite.partial().omit({ id: true });

function yearOk(year: number): boolean {
  return year >= 1900 && year <= new Date().getFullYear() + 1;
}

export async function nextMaintenance(db: Db, vehicleId: string, mileage: number) {
    const items = await db.select().from(planItems).where(and(eq(planItems.vehicleId, vehicleId), eq(planItems.enabled, true)));
  let best: (typeof items)[number] | null = null;
  let bestScore = Number.POSITIVE_INFINITY;
  const today = new Date().toISOString().slice(0, 10);
  for (const item of items) {
    const dueMileage = num(item.nextDueMileage);
    const dueOn = dateOnly(item.nextDueOn);
    let score = Number.POSITIVE_INFINITY;
    if (dueMileage != null) score = Math.min(score, dueMileage - mileage);
    if (dueOn) {
      const days = (Date.parse(dueOn) - Date.parse(today)) / 86400000;
      score = Math.min(score, days);
    }
    if (score < bestScore) {
      bestScore = score;
      best = item;
    }
  }
  if (!best) return null;
  const dueMileage = num(best.nextDueMileage);
  const dueOn = dateOnly(best.nextDueOn);
  const overdue = (dueMileage != null && dueMileage <= mileage) || (dueOn != null && dueOn <= today);
  return {
    plan_item_id: best.id,
    name: best.name,
    due_mileage: dueMileage,
    due_on: dueOn,
    overdue,
  };
}

export async function getOwnedVehicle(db: Db, userId: string, vehicleId: string, includeArchived = false) {
  const [row] = await db.select().from(vehicles).where(eq(vehicles.id, vehicleId)).limit(1);
  if (!row || row.userId !== userId) throw new AppError(404, "not_found", "Vehicle not found");
  if (!includeArchived && row.archived) throw new AppError(404, "not_found", "Vehicle not found");
  return row;
}

async function assertPlateVin(db: Db, userId: string, plate: string, vin: string | null | undefined, exceptId?: string) {
  const all = await db.select().from(vehicles).where(eq(vehicles.userId, userId));
  const plateTaken = all.find(
    (v) => !v.archived && v.licensePlate.toLowerCase() === plate.toLowerCase() && v.id !== exceptId,
  );
  if (plateTaken) throw new AppError(409, "plate_taken", "License plate already used on this account");
  if (vin) {
    const vinRows = await db.select().from(vehicles);
    const vinTaken = vinRows.find((v) => !v.archived && v.vin && v.vin === vin && v.id !== exceptId);
    if (vinTaken) throw new AppError(409, "vin_taken", "VIN already belongs to another vehicle");
  }
}

export const vehiclesPlugin: FastifyPluginAsync = async (app) => {
  app.get("/vehicles", async (request) => {
    requireOwner(request);
    const includeArchived = (request.query as { include_archived?: string }).include_archived === "true";
    const userId = request.authUser!.sub;
    const rows = await app.db.select().from(vehicles).where(eq(vehicles.userId, userId));
    const filtered = includeArchived ? rows : rows.filter((v) => !v.archived);
    const items = [];
    for (const row of filtered) {
      items.push(publicVehicle(row, await nextMaintenance(app.db, row.id, reqNum(row.mileage))));
    }
    return { items };
  });

  app.post("/vehicles", async (request, reply) => {
    requireOwner(request);
    const body = vehicleWrite.parse(request.body);
    if (!yearOk(body.year)) throw new AppError(422, "invalid_year", "Year must be 1900 through next year");
    const userId = request.authUser!.sub;
    const [existing] = await app.db.select().from(vehicles).where(eq(vehicles.id, body.id)).limit(1);
    if (existing) {
      if (existing.userId !== userId) throw new AppError(409, "id_conflict", "Vehicle id already exists");
      return reply.code(201).send(publicVehicle(existing, await nextMaintenance(app.db, existing.id, reqNum(existing.mileage))));
    }
    await assertPlateVin(app.db, userId, body.license_plate, body.vin ?? null);
    const [row] = await app.db
      .insert(vehicles)
      .values({
        id: body.id,
        userId,
        name: body.name,
        nickname: body.nickname ?? null,
        make: body.make,
        model: body.model,
        year: body.year,
        licensePlate: body.license_plate,
        vin: body.vin ?? null,
        color: body.color ?? null,
        fuelType: body.fuel_type,
        mileage: String(body.mileage),
        mileageUnit: body.mileage_unit ?? "mi",
        purchaseDate: body.purchase_date ?? null,
        purchasePrice: body.purchase_price != null ? String(body.purchase_price) : null,
        photoMediaId: body.photo_media_id ?? null,
      })
      .returning();
    const [user] = await app.db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (user && !user.activeVehicleId) {
      await app.db.update(users).set({ activeVehicleId: row.id }).where(eq(users.id, userId));
    }
    const payload = publicVehicle(row, null);
    await recordChange(app.db, { userId, entityType: "vehicle", entityId: row.id, op: "upsert", payload });
    return reply.code(201).send(payload);
  });

  app.get("/vehicles/:vehicleId", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const row = await getOwnedVehicle(app.db, request.authUser!.sub, vehicleId, true);
    return publicVehicle(row, await nextMaintenance(app.db, row.id, reqNum(row.mileage)));
  });

  app.patch("/vehicles/:vehicleId", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const body = vehiclePatch.parse(request.body ?? {});
    const row = await getOwnedVehicle(app.db, request.authUser!.sub, vehicleId);
    if (body.year !== undefined && !yearOk(body.year)) {
      throw new AppError(422, "invalid_year", "Year must be 1900 through next year");
    }
    if (body.mileage !== undefined && body.mileage < reqNum(row.mileage)) {
      throw new AppError(409, "mileage_decrease", "Mileage cannot decrease");
    }
    if (body.license_plate || body.vin !== undefined) {
      await assertPlateVin(
        app.db,
        request.authUser!.sub,
        body.license_plate ?? row.licensePlate,
        body.vin === undefined ? row.vin : body.vin,
        row.id,
      );
    }
    const [updated] = await app.db
      .update(vehicles)
      .set({
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.nickname !== undefined ? { nickname: body.nickname } : {}),
        ...(body.make !== undefined ? { make: body.make } : {}),
        ...(body.model !== undefined ? { model: body.model } : {}),
        ...(body.year !== undefined ? { year: body.year } : {}),
        ...(body.license_plate !== undefined ? { licensePlate: body.license_plate } : {}),
        ...(body.vin !== undefined ? { vin: body.vin } : {}),
        ...(body.color !== undefined ? { color: body.color } : {}),
        ...(body.fuel_type !== undefined ? { fuelType: body.fuel_type } : {}),
        ...(body.mileage !== undefined ? { mileage: String(body.mileage) } : {}),
        ...(body.mileage_unit !== undefined ? { mileageUnit: body.mileage_unit } : {}),
        ...(body.purchase_date !== undefined ? { purchaseDate: body.purchase_date } : {}),
        ...(body.purchase_price !== undefined
          ? { purchasePrice: body.purchase_price != null ? String(body.purchase_price) : null }
          : {}),
        ...(body.photo_media_id !== undefined ? { photoMediaId: body.photo_media_id } : {}),
        updatedAt: new Date(),
      })
      .where(eq(vehicles.id, vehicleId))
      .returning();
    const payload = publicVehicle(updated, await nextMaintenance(app.db, updated.id, reqNum(updated.mileage)));
    await recordChange(app.db, {
      userId: request.authUser!.sub,
      entityType: "vehicle",
      entityId: updated.id,
      op: "upsert",
      payload,
    });
    return payload;
  });

  app.post("/vehicles/:vehicleId/archive", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const row = await getOwnedVehicle(app.db, request.authUser!.sub, vehicleId, true);
    const [updated] = await app.db
      .update(vehicles)
      .set({ archived: true, archivedAt: new Date(), updatedAt: new Date() })
      .where(eq(vehicles.id, vehicleId))
      .returning();
    const user = await getUser(app.db, request.authUser!.sub);
    if (user?.activeVehicleId === vehicleId) {
      const rest = await app.db.select().from(vehicles).where(eq(vehicles.userId, request.authUser!.sub));
      const next = rest.find((v) => !v.archived && v.id !== vehicleId);
      await app.db.update(users).set({ activeVehicleId: next?.id ?? null }).where(eq(users.id, request.authUser!.sub));
    }
    const payload = publicVehicle(updated, null);
    await recordChange(app.db, {
      userId: request.authUser!.sub,
      entityType: "vehicle",
      entityId: vehicleId,
      op: "archive",
      payload,
    });
    return payload;
  });

  app.post("/vehicles/:vehicleId/activate", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    await getOwnedVehicle(app.db, request.authUser!.sub, vehicleId);
    const [updated] = await app.db
      .update(users)
      .set({ activeVehicleId: vehicleId })
      .where(eq(users.id, request.authUser!.sub))
      .returning();
    return publicUser(updated);
  });

  app.get("/vehicles/:vehicleId/dashboard", async (request) => {
    requireOwner(request);
    const { vehicleId } = request.params as { vehicleId: string };
    const row = await getOwnedVehicle(app.db, request.authUser!.sub, vehicleId);
    const expenseRows = await app.db.select().from(expenses).where(eq(expenses.vehicleId, vehicleId));
    const now = new Date();
    const monthPrefix = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
    const total = expenseRows.reduce((s, e) => s + reqNum(e.amount), 0);
    const thisMonth = expenseRows
      .filter((e) => dateOnly(e.incurredOn)?.startsWith(monthPrefix))
      .reduce((s, e) => s + reqNum(e.amount), 0);
    const svc = await app.db
      .select()
      .from(serviceRecords)
      .where(eq(serviceRecords.vehicleId, vehicleId))
      .orderBy(desc(serviceRecords.servicedOn));
    const docs = await app.db.select().from(documents).where(eq(documents.vehicleId, vehicleId));
    return {
      vehicle: publicVehicle(row, await nextMaintenance(app.db, row.id, reqNum(row.mileage))),
      ownership: {
        total_spent: total,
        this_month_spent: thisMonth,
        currency: "USD",
        services_count: svc.length,
        documents_count: docs.length,
      },
      recent_services: svc.slice(0, 3).map((s) => ({
        id: s.id,
        serviced_on: dateOnly(s.servicedOn),
        title: s.workshopName || "Service",
        total_cost: reqNum(s.totalCost),
      })),
      next_maintenance: await nextMaintenance(app.db, row.id, reqNum(row.mileage)),
    };
  });
};
