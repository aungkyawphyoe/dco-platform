import { and, desc, eq, inArray, sql } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import {
  driverAssignments,
  organizationMembers,
  organizationVehicles,
  partners,
  planItems,
  serviceRecords,
  transferredVehicles,
  users,
  vehicleHandoverEvents,
  vehicleHandovers,
  vehicleWarranties,
  vehicles,
  warrantyTemplateWorkshops,
  warrantyTemplates,
  workOrders,
} from "../db/schema.js";
import { requireFleetPortal } from "./auth.js";
import { newId } from "../lib/crypto.js";
import { dateOnly, iso, num, recordChange, reqNum } from "../lib/dbx.js";
import { AppError } from "../lib/errors.js";
import { organizationRecord } from "../lib/record-ownership.js";
import { publicPlan } from "../lib/serialize-records.js";
import { publicVehicle } from "../lib/serialize.js";
import { getOrganizationAccess } from "./fleet.js";

const uuid = z.string().uuid();

const planItemInput = z.object({
  name: z.string().trim().min(1).max(100),
  interval_days: z.number().int().positive().nullable().optional(),
  time_count: z.number().int().positive().nullable().optional(),
  time_unit: z.enum(["days", "months", "years"]).nullable().optional(),
  warning_days: z.number().int().min(0).nullable().optional(),
  warning_distance: z.number().min(0).nullable().optional(),
  interval_distance: z.number().positive().nullable().optional(),
  next_due_on: z.string().date().nullable().optional(),
  next_due_mileage: z.number().nonnegative().nullable().optional(),
  initial_service_required: z.boolean().optional(),
  notes: z.string().max(4000).nullable().optional(),
});

type PlanInput = z.infer<typeof planItemInput>;

type PlanSnapshotItem = {
  name: string;
  interval_days: number | null;
  time_count: number | null;
  time_unit: "days" | "months" | "years" | null;
  warning_days: number | null;
  warning_distance: number | null;
  interval_distance: number | null;
  next_due_on: string | null;
  next_due_mileage: number | null;
  initial_service_required: boolean;
  notes: string | null;
};

type HandoverRow = typeof vehicleHandovers.$inferSelect;
type Issue = { code: string; message: string; details?: Record<string, unknown> };

const warrantyChoice = z.enum(["undecided", "none", "template"]);

const draftFields = z.object({
  sale_date: z.string().date().nullable().optional(),
  current_mileage_km: z.number().int().min(0).nullable().optional(),
  plan: z.array(planItemInput).max(100).optional(),
  warranty_choice: warrantyChoice.optional(),
  warranty_template_id: uuid.nullable().optional(),
});

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

function maskEmail(value: string | null): string | null {
  if (!value) return null;
  const [local, domain] = value.split("@");
  if (!local || !domain) return "***";
  return `${local.slice(0, 1)}***@${domain}`;
}

function maskPhone(value: string | null): string | null {
  if (!value) return null;
  const digits = value.replace(/\D/g, "");
  if (!digits) return "***";
  return `***${digits.slice(-4)}`;
}

function normalizePlan(input: PlanInput[]): PlanSnapshotItem[] {
  return input.map((item) => ({
    name: item.name.trim(),
    interval_days: item.interval_days ?? null,
    time_count: item.time_count ?? null,
    time_unit: item.time_unit ?? null,
    warning_days: item.warning_days ?? null,
    warning_distance: item.warning_distance ?? null,
    interval_distance: item.interval_distance ?? null,
    next_due_on: item.next_due_on ?? null,
    next_due_mileage: item.next_due_mileage ?? null,
    initial_service_required: item.initial_service_required ?? false,
    notes: item.notes ?? null,
  }));
}

function planIssues(plan: PlanSnapshotItem[]): Issue[] {
  const issues: Issue[] = [];
  if (plan.length === 0) {
    issues.push({ code: "plan_empty", message: "Add at least one maintenance plan item before handover." });
    return issues;
  }
  plan.forEach((item, index) => {
    if (Boolean(item.time_count) !== Boolean(item.time_unit)) {
      issues.push({ code: "invalid_plan_interval", message: `Plan item ${index + 1} must choose a time count and unit together.` });
    }
    const hasDue = item.next_due_on != null || item.next_due_mileage != null;
    if (!item.initial_service_required && !hasDue) {
      issues.push({ code: "plan_due_required", message: `Plan item ${index + 1} needs a due date, due mileage, or initial-service-required status.` });
    }
    if (!item.initial_service_required && (item.time_count || item.interval_days) && item.next_due_on == null) {
      issues.push({ code: "plan_due_date_required", message: `Plan item ${index + 1} needs a first due date.` });
    }
    if (!item.initial_service_required && item.interval_distance != null && item.next_due_mileage == null) {
      issues.push({ code: "plan_due_mileage_required", message: `Plan item ${index + 1} needs a first due mileage.` });
    }
  });
  return issues;
}

async function buyerProfile(db: Db, userId: string) {
  const [buyer] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!buyer) return null;
  const eligible = buyer.role === "owner" && buyer.status === "active";
  return {
    user_id: buyer.id,
    display_name: buyer.displayName,
    email_masked: maskEmail(buyer.email),
    phone_masked: maskPhone(buyer.contactPhone),
    eligible,
    reason: eligible ? null : "Buyer must be an existing active personal account.",
  };
}

async function loadWarrantySnapshot(db: Db, orgId: string, templateId: string) {
  const [template] = await db.select().from(warrantyTemplates).where(and(
    eq(warrantyTemplates.id, templateId), eq(warrantyTemplates.orgId, orgId),
  )).limit(1);
  if (!template) throw new AppError(404, "warranty_template_not_found", "Warranty template not found in this organization");
  const workshops = await db.select({ id: partners.id, name: partners.name })
    .from(warrantyTemplateWorkshops)
    .innerJoin(partners, eq(warrantyTemplateWorkshops.partnerId, partners.id))
    .where(eq(warrantyTemplateWorkshops.templateId, template.id));
  return {
    template_id: template.id,
    name: template.name,
    duration_years: template.durationYears,
    mileage_limit_km: template.mileageLimitKm,
    coverage_categories: template.coverageCategories,
    exclusions: template.exclusions,
    approved_workshops: workshops,
    captured_at: new Date().toISOString(),
  };
}

function serializeHandover(row: HandoverRow, buyer: Awaited<ReturnType<typeof buyerProfile>>) {
  return {
    id: row.id,
    org_id: row.orgId,
    vehicle_id: row.vehicleId,
    buyer: buyer ?? { user_id: row.buyerUserId, display_name: null, email_masked: null, phone_masked: null, eligible: false, reason: "Buyer account not found." },
    status: row.status,
    revision: row.revision,
    reviewed_revision: row.reviewedRevision,
    reviewed_by: row.reviewedBy,
    reviewed_at: iso(row.reviewedAt),
    sale_date: dateOnly(row.saleDate),
    current_mileage_km: row.currentMileageKm,
    plan: row.planSnapshot,
    warranty_choice: row.warrantyChoice,
    warranty_template_id: row.warrantyTemplateId,
    warranty: row.warrantySnapshot,
    result: row.resultSnapshot,
    cancellation_reason: row.cancellationReason,
    created_by: row.createdBy,
    created_at: iso(row.createdAt),
    updated_at: iso(row.updatedAt),
    completed_by: row.completedBy,
    completed_at: iso(row.completedAt),
    cancelled_by: row.cancelledBy,
    cancelled_at: iso(row.cancelledAt),
  };
}

async function collectIssues(db: Db, handover: HandoverRow, link: typeof organizationVehicles.$inferSelect | undefined, vehicle: typeof vehicles.$inferSelect | undefined): Promise<Issue[]> {
  const issues: Issue[] = [];
  if (!link || link.orgId !== handover.orgId || link.vehicleId !== handover.vehicleId) {
    issues.push({ code: "vehicle_not_in_org", message: "Vehicle is no longer in this organization." });
  } else if (link.lifecycleTemplate !== "showroom" || link.status !== "reserved") {
    issues.push({ code: "vehicle_not_ready_for_handover", message: "Vehicle must be reserved in the showroom lifecycle before handover." });
  }
  if (!vehicle) {
    issues.push({ code: "vehicle_not_found", message: "Vehicle was not found." });
  }
  const buyer = await buyerProfile(db, handover.buyerUserId);
  if (!buyer?.eligible) {
    issues.push({ code: "buyer_not_eligible", message: "Buyer must be an existing active personal account." });
  }
  if (handover.saleDate == null) {
    issues.push({ code: "sale_date_required", message: "Set the sale date." });
  } else if (dateOnly(handover.saleDate)! > today()) {
    issues.push({ code: "invalid_sale_date", message: "Sale date cannot be in the future." });
  }
  if (handover.currentMileageKm == null) {
    issues.push({ code: "mileage_required", message: "Set the handover mileage." });
  } else if (vehicle && handover.currentMileageKm < Math.floor(reqNum(vehicle.mileage))) {
    issues.push({ code: "invalid_odometer", message: "Handover mileage cannot be below the last recorded mileage." });
  }
  issues.push(...planIssues(handover.planSnapshot as PlanSnapshotItem[]));
  if (handover.warrantyChoice === "undecided") {
    issues.push({ code: "warranty_choice_required", message: "Choose reviewed warranty terms or No warranty." });
  }
  if (handover.warrantyChoice === "template" && !handover.warrantySnapshot) {
    issues.push({ code: "warranty_terms_missing", message: "Reviewed warranty terms are missing." });
  }
  const open = await db.select({ id: workOrders.id }).from(workOrders).where(and(
    eq(workOrders.vehicleId, handover.vehicleId),
    eq(workOrders.orgId, handover.orgId),
    inArray(workOrders.status, ["reported", "in_progress"]),
  ));
  if (open.length) {
    issues.push({
      code: "open_repairs",
      message: "Complete or explicitly cancel all open repairs before handover.",
      details: { work_order_ids: open.map((row) => row.id) },
    });
  }
  return issues;
}

function addYears(dateText: string, years: number): string {
  const date = new Date(`${dateText}T00:00:00Z`);
  date.setUTCFullYear(date.getUTCFullYear() + years);
  return date.toISOString().slice(0, 10);
}

export const handoverPlugin: FastifyPluginAsync = async (app) => {
  const uid = (request: { authUser?: { sub: string } }) => request.authUser!.sub;

  async function loadHandover(db: Db, orgId: string, handoverId: string) {
    const [row] = await db.select().from(vehicleHandovers).where(and(
      eq(vehicleHandovers.id, handoverId), eq(vehicleHandovers.orgId, orgId),
    )).limit(1);
    if (!row) throw new AppError(404, "handover_not_found", "Handover draft not found");
    return row;
  }

  app.get("/organizations/:id/handover-buyers", async (request) => {
    requireFleetPortal(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
    const body = z.object({ email: z.string().email().max(254) }).parse(request.query);
    const [buyer] = await app.db.select({ id: users.id }).from(users).where(eq(users.email, body.email.toLowerCase())).limit(1);
    if (!buyer) throw new AppError(404, "buyer_not_found", "No account matches that exact email address");
    return buyerProfile(app.db, buyer.id);
  });

  app.get("/organizations/:id/handover-buyers/:userId", async (request) => {
    requireFleetPortal(request);
    const { id, userId } = z.object({ id: uuid, userId: uuid }).parse(request.params);
    await getOrganizationAccess(app.db, uid(request), id, ["org_admin", "org_manager"]);
    const profile = await buyerProfile(app.db, userId);
    if (!profile) throw new AppError(404, "buyer_not_found", "No account matches that account code");
    return profile;
  });

  app.get("/organizations/:id/handovers", async (request) => {
    requireFleetPortal(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    await getOrganizationAccess(app.db, uid(request), orgId, ["org_admin", "org_manager"]);
    const query = z.object({
      status: z.enum(["draft", "completed", "cancelled"]).optional(),
      vehicle_id: uuid.optional(),
    }).parse(request.query);
    const rows = await app.db.select().from(vehicleHandovers).where(and(
      eq(vehicleHandovers.orgId, orgId),
      ...(query.status ? [eq(vehicleHandovers.status, query.status)] : []),
      ...(query.vehicle_id ? [eq(vehicleHandovers.vehicleId, query.vehicle_id)] : []),
    )).orderBy(desc(vehicleHandovers.createdAt));
    const items = [];
    for (const row of rows) items.push(serializeHandover(row, await buyerProfile(app.db, row.buyerUserId)));
    return { items };
  });

  app.get("/organizations/:id/handovers/:handoverId", async (request) => {
    requireFleetPortal(request);
    const { id, handoverId } = z.object({ id: uuid, handoverId: uuid }).parse(request.params);
    await getOrganizationAccess(app.db, uid(request), id, ["org_admin", "org_manager"]);
    const row = await loadHandover(app.db, id, handoverId);
    const [link] = await app.db.select().from(organizationVehicles).where(and(
      eq(organizationVehicles.orgId, id), eq(organizationVehicles.vehicleId, row.vehicleId),
    )).limit(1);
    const [vehicle] = await app.db.select().from(vehicles).where(eq(vehicles.id, row.vehicleId)).limit(1);
    const issues = row.status === "draft" ? await collectIssues(app.db, row, link, vehicle) : [];
    return {
      ...serializeHandover(row, await buyerProfile(app.db, row.buyerUserId)),
      blocking_issues: issues,
      ready_to_review: row.status === "draft" && issues.length === 0,
    };
  });

  app.post("/organizations/:id/handovers", async (request, reply) => {
    requireFleetPortal(request);
    const orgId = uuid.parse((request.params as { id: string }).id);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, orgId, ["org_admin", "org_manager"]);
    const body = z.object({
      vehicle_id: uuid,
      buyer_user_id: uuid,
      ...draftFields.shape,
    }).parse(request.body);
    const row = await app.db.transaction(async (tx) => {
      const [vehicle] = await tx.select().from(vehicles).where(eq(vehicles.id, body.vehicle_id)).for("update");
      if (!vehicle) throw new AppError(404, "vehicle_not_found", "Vehicle not found");
      const [link] = await tx.select().from(organizationVehicles).where(and(
        eq(organizationVehicles.orgId, orgId), eq(organizationVehicles.vehicleId, body.vehicle_id),
      )).for("update");
      if (!link) throw new AppError(404, "vehicle_not_in_org", "Vehicle not found in this organization");
      if (link.lifecycleTemplate !== "showroom" || link.status !== "reserved") {
        throw new AppError(409, "vehicle_not_ready_for_handover", "Vehicle must be reserved in the showroom lifecycle before handover");
      }
      if (body.buyer_user_id === vehicle.userId) throw new AppError(422, "buyer_is_owner", "Buyer already owns this vehicle");
      const buyer = await buyerProfile(tx, body.buyer_user_id);
      if (!buyer) throw new AppError(404, "buyer_not_found", "Buyer account not found");
      if (!buyer.eligible) throw new AppError(422, "buyer_not_eligible", buyer.reason ?? "Buyer is not eligible");
      let warrantySnapshot = null;
      let warrantyTemplateId: string | null = null;
      const choice = body.warranty_choice ?? "undecided";
      if (choice === "template") {
        if (!body.warranty_template_id) throw new AppError(422, "warranty_template_required", "Select a warranty template");
        warrantyTemplateId = body.warranty_template_id;
        warrantySnapshot = await loadWarrantySnapshot(tx, orgId, warrantyTemplateId);
      } else if (choice === "undecided" && body.warranty_template_id) {
        throw new AppError(422, "warranty_choice_required", "Choose warranty template or No warranty");
      }
      const mileage = body.current_mileage_km ?? Math.floor(reqNum(vehicle.mileage));
      if (mileage < Math.floor(reqNum(vehicle.mileage))) throw new AppError(422, "invalid_odometer", "Handover mileage cannot be below the last recorded mileage");
      const saleDate = body.sale_date ?? today();
      if (saleDate > today()) throw new AppError(422, "invalid_sale_date", "Sale date cannot be in the future");
      const [created] = await tx.insert(vehicleHandovers).values({
        id: newId(),
        orgId,
        vehicleId: body.vehicle_id,
        buyerUserId: body.buyer_user_id,
        createdBy: actorId,
        saleDate,
        currentMileageKm: mileage,
        planSnapshot: normalizePlan(body.plan ?? []),
        warrantyChoice: choice,
        warrantyTemplateId,
        warrantySnapshot,
      }).returning();
      return created;
    }).catch((error: { code?: string; cause?: { code?: string }; message?: string }) => {
      if (error.code === "23505" || error.cause?.code === "23505" || error.message?.includes("duplicate key")) throw new AppError(409, "handover_pending", "This vehicle already has a pending handover draft");
      throw error;
    });
    return reply.code(201).send(serializeHandover(row, await buyerProfile(app.db, row.buyerUserId)));
  });

  app.patch("/organizations/:id/handovers/:handoverId", async (request) => {
    requireFleetPortal(request);
    const { id, handoverId } = z.object({ id: uuid, handoverId: uuid }).parse(request.params);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, id, ["org_admin", "org_manager"]);
    const body = draftFields.extend({
      vehicle_id: uuid.optional(),
      buyer_user_id: uuid.optional(),
    }).parse(request.body ?? {});
    const updated = await app.db.transaction(async (tx) => {
      const [current] = await tx.select().from(vehicleHandovers).where(and(
        eq(vehicleHandovers.id, handoverId), eq(vehicleHandovers.orgId, id),
      )).for("update");
      if (!current) throw new AppError(404, "handover_not_found", "Handover draft not found");
      if (current.status !== "draft") throw new AppError(409, "handover_not_draft", "Only a draft handover can be changed");
      if (body.vehicle_id && body.vehicle_id !== current.vehicleId) {
        throw new AppError(422, "vehicle_change_requires_new_draft", "Cancel this draft and start a new handover to change the vehicle");
      }
      if (body.buyer_user_id && body.buyer_user_id !== current.buyerUserId) {
        throw new AppError(422, "buyer_change_requires_new_draft", "Cancel this draft and start a new handover to change the buyer");
      }
      const [vehicle] = await tx.select().from(vehicles).where(eq(vehicles.id, current.vehicleId)).for("update");
      if (!vehicle) throw new AppError(404, "vehicle_not_found", "Vehicle not found");
      let warrantyTemplateId = current.warrantyTemplateId;
      let warrantySnapshot = current.warrantySnapshot as unknown;
      let choice = current.warrantyChoice;
      if (body.warranty_choice !== undefined) choice = body.warranty_choice;
      if (body.warranty_template_id !== undefined) warrantyTemplateId = body.warranty_template_id;
      if (choice === "none") {
        warrantyTemplateId = null;
        warrantySnapshot = null;
      } else if (choice === "template") {
        if (!warrantyTemplateId) throw new AppError(422, "warranty_template_required", "Select a warranty template");
        warrantySnapshot = await loadWarrantySnapshot(tx, id, warrantyTemplateId);
      } else {
        warrantyTemplateId = null;
        warrantySnapshot = null;
      }
      const mileage = body.current_mileage_km === undefined ? current.currentMileageKm : body.current_mileage_km;
      if (mileage != null && mileage < Math.floor(reqNum(vehicle.mileage))) {
        throw new AppError(422, "invalid_odometer", "Handover mileage cannot be below the last recorded mileage");
      }
      const saleDate = body.sale_date === undefined ? current.saleDate : body.sale_date;
      if (saleDate != null && dateOnly(saleDate)! > today()) throw new AppError(422, "invalid_sale_date", "Sale date cannot be in the future");
      const [saved] = await tx.update(vehicleHandovers).set({
        ...(body.sale_date !== undefined ? { saleDate: body.sale_date } : {}),
        ...(body.current_mileage_km !== undefined ? { currentMileageKm: body.current_mileage_km } : {}),
        ...(body.plan !== undefined ? { planSnapshot: normalizePlan(body.plan) } : {}),
        warrantyChoice: choice,
        warrantyTemplateId,
        warrantySnapshot: warrantySnapshot as object | null,
        revision: current.revision + 1,
        reviewedRevision: null,
        reviewedBy: null,
        reviewedAt: null,
        updatedAt: new Date(),
      }).where(eq(vehicleHandovers.id, current.id)).returning();
      return saved;
    });
    return serializeHandover(updated, await buyerProfile(app.db, updated.buyerUserId));
  });

  app.post("/organizations/:id/handovers/:handoverId/review", async (request) => {
    requireFleetPortal(request);
    const { id, handoverId } = z.object({ id: uuid, handoverId: uuid }).parse(request.params);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, id, ["org_admin", "org_manager"]);
    const body = z.object({ revision: z.number().int().positive() }).parse(request.body ?? {});
    const reviewed = await app.db.transaction(async (tx) => {
      const [current] = await tx.select().from(vehicleHandovers).where(and(
        eq(vehicleHandovers.id, handoverId), eq(vehicleHandovers.orgId, id),
      )).for("update");
      if (!current) throw new AppError(404, "handover_not_found", "Handover draft not found");
      if (current.status !== "draft") throw new AppError(409, "handover_not_draft", "Only a draft handover can be reviewed");
      if (body.revision !== current.revision) throw new AppError(409, "handover_changed", "Handover changed. Reload before reviewing.");
      const [link] = await tx.select().from(organizationVehicles).where(and(
        eq(organizationVehicles.orgId, id), eq(organizationVehicles.vehicleId, current.vehicleId),
      )).limit(1);
      const [vehicle] = await tx.select().from(vehicles).where(eq(vehicles.id, current.vehicleId)).limit(1);
      const issues = await collectIssues(tx, current, link, vehicle);
      if (issues.length) {
        throw new AppError(409, "handover_not_ready", "Resolve handover issues before review", { issues });
      }
      const [saved] = await tx.update(vehicleHandovers).set({
        reviewedRevision: current.revision,
        reviewedBy: actorId,
        reviewedAt: new Date(),
        updatedAt: new Date(),
      }).where(eq(vehicleHandovers.id, current.id)).returning();
      return saved;
    });
    return serializeHandover(reviewed, await buyerProfile(app.db, reviewed.buyerUserId));
  });

  app.post("/organizations/:id/handovers/:handoverId/cancel", async (request) => {
    requireFleetPortal(request);
    const { id, handoverId } = z.object({ id: uuid, handoverId: uuid }).parse(request.params);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, id, ["org_admin", "org_manager"]);
    const body = z.object({ reason: z.string().trim().min(1).max(1000) }).parse(request.body);
    const cancelled = await app.db.transaction(async (tx) => {
      const [current] = await tx.select().from(vehicleHandovers).where(and(
        eq(vehicleHandovers.id, handoverId), eq(vehicleHandovers.orgId, id),
      )).for("update");
      if (!current) throw new AppError(404, "handover_not_found", "Handover not found");
      if (current.status === "completed") throw new AppError(409, "handover_completed", "A completed handover requires platform-admin correction");
      if (current.status === "cancelled") return current;
      const [saved] = await tx.update(vehicleHandovers).set({
        status: "cancelled",
        cancellationReason: body.reason,
        cancelledBy: actorId,
        cancelledAt: new Date(),
        updatedAt: new Date(),
      }).where(eq(vehicleHandovers.id, current.id)).returning();
      return saved;
    });
    return serializeHandover(cancelled, await buyerProfile(app.db, cancelled.buyerUserId));
  });

  app.post("/organizations/:id/handovers/:handoverId/complete", async (request, reply) => {
    requireFleetPortal(request);
    const { id, handoverId } = z.object({ id: uuid, handoverId: uuid }).parse(request.params);
    const actorId = uid(request);
    await getOrganizationAccess(app.db, actorId, id, ["org_admin", "org_manager"]);
    const body = z.object({
      reviewed_revision: z.number().int().positive(),
      acknowledged: z.literal(true),
    }).parse(request.body);

    const result = await app.db.transaction(async (tx) => {
      const [pending] = await tx.select({ vehicleId: vehicleHandovers.vehicleId }).from(vehicleHandovers).where(and(
        eq(vehicleHandovers.id, handoverId), eq(vehicleHandovers.orgId, id),
      )).limit(1);
      if (!pending) throw new AppError(404, "handover_not_found", "Handover not found");
      const [vehicle] = await tx.select().from(vehicles).where(eq(vehicles.id, pending.vehicleId)).for("update");
      const [link] = vehicle
        ? await tx.select().from(organizationVehicles).where(and(
          eq(organizationVehicles.orgId, id), eq(organizationVehicles.vehicleId, vehicle.id),
        )).for("update")
        : [undefined];
      const [current] = await tx.select().from(vehicleHandovers).where(and(
        eq(vehicleHandovers.id, handoverId), eq(vehicleHandovers.orgId, id),
      )).for("update");
      if (!current) throw new AppError(404, "handover_not_found", "Handover not found");
      if (!vehicle) throw new AppError(404, "vehicle_not_found", "Vehicle not found");

      const [membership] = await tx.select().from(organizationMembers).where(and(
        eq(organizationMembers.orgId, id), eq(organizationMembers.userId, actorId),
      )).for("update");
      if (!membership || membership.status !== "active") throw new AppError(403, "not_org_member", "User is not a member of this organization");
      if (membership.role !== "org_admin" && !(membership.role === "org_manager" && membership.canCompleteHandover)) {
        throw new AppError(403, "transfer_permission_required", "An admin or a manager with handover permission must complete this handover");
      }

      if (current.status === "completed") {
        return { row: current, result: current.resultSnapshot as Record<string, unknown>, idempotent: true };
      }
      if (current.status === "cancelled") throw new AppError(409, "handover_cancelled", "This handover was cancelled");
      if (current.reviewedRevision == null || current.reviewedRevision !== current.revision) {
        throw new AppError(409, "review_required", "Review the current handover revision before completing");
      }
      if (body.reviewed_revision !== current.revision) {
        throw new AppError(409, "handover_changed", "Handover changed. Reload and review before completing.");
      }
      const issues = await collectIssues(tx, current, link, vehicle);
      if (issues.length) {
        throw new AppError(409, "handover_not_ready", "Resolve handover issues before completing", { issues });
      }

      const buyer = await buyerProfile(tx, current.buyerUserId);
      if (!buyer?.eligible) throw new AppError(422, "buyer_not_eligible", "Buyer must be an existing active personal account");
      const plan = current.planSnapshot as PlanSnapshotItem[];
      const saleDate = current.saleDate!;
      const mileage = current.currentMileageKm!;
      const vehicleSnapshot = {
        id: vehicle.id,
        name: vehicle.name,
        nickname: vehicle.nickname,
        make: vehicle.make,
        model: vehicle.model,
        year: vehicle.year,
        plate: vehicle.licensePlate,
        vin: vehicle.vin,
        color: vehicle.color,
        fuel_type: vehicle.fuelType,
        mileage: reqNum(vehicle.mileage),
        purchase_date: dateOnly(vehicle.purchaseDate),
        purchase_price: num(vehicle.purchasePrice),
        purchase_currency: vehicle.purchaseCurrency,
        photo_media_id: vehicle.photoMediaId,
      };

      const [existingWarranty] = await tx.select().from(vehicleWarranties).where(eq(vehicleWarranties.vehicleId, vehicle.id)).limit(1);
      if (existingWarranty) {
        await tx.update(vehicleHandovers).set({
          priorWarrantySnapshot: {
            id: existingWarranty.id,
            template_id: existingWarranty.templateId,
            sale_date: dateOnly(existingWarranty.saleDate),
            sale_mileage_km: existingWarranty.saleMileageKm,
            warranty_end_date: dateOnly(existingWarranty.warrantyEndDate),
            warranty_end_mileage: existingWarranty.warrantyEndMileage,
            status: existingWarranty.status,
            terms: existingWarranty.termsSnapshot,
          },
        }).where(eq(vehicleHandovers.id, current.id));
        await tx.delete(vehicleWarranties).where(eq(vehicleWarranties.id, existingWarranty.id));
      }

      const [updatedVehicle] = await tx.update(vehicles).set({
        userId: current.buyerUserId,
        mileage: String(mileage),
        mileageUnit: "km",
        purchaseDate: null,
        purchasePrice: null,
        photoMediaId: null,
        updatedAt: new Date(),
      }).where(eq(vehicles.id, vehicle.id)).returning();

      // Deleting the organization link closes the showroom ownership period and
      // opens the buyer period before any buyer-owned plan rows are created.
      await tx.delete(organizationVehicles).where(eq(organizationVehicles.id, link!.id));

      const createdPlans = [];
      for (const item of plan) {
        const [created] = await tx.insert(planItems).values({
          id: newId(),
          vehicleId: vehicle.id,
          name: item.name,
          intervalDays: item.interval_days,
          timeCount: item.time_count,
          timeUnit: item.time_unit,
          warningDays: item.warning_days,
          warningDistance: item.warning_distance == null ? null : String(item.warning_distance),
          intervalDistance: item.interval_distance == null ? null : String(item.interval_distance),
          nextDueOn: item.next_due_on,
          nextDueMileage: item.next_due_mileage == null ? null : String(item.next_due_mileage),
          baselineDueOn: item.next_due_on,
          baselineDueMileage: item.next_due_mileage == null ? null : String(item.next_due_mileage),
          baselineEnabled: true,
          initialServiceRequired: item.initial_service_required,
          notes: item.notes,
          enabled: true,
          createdBy: actorId,
        }).returning();
        createdPlans.push(created);
      }

      let warrantyInstanceId: string | null = null;
      if (current.warrantyChoice === "template") {
        const template = current.warrantySnapshot as { duration_years: number; mileage_limit_km: number } | null;
        if (!template || !current.warrantyTemplateId) throw new AppError(409, "warranty_terms_missing", "Reviewed warranty terms are missing");
        warrantyInstanceId = newId();
        await tx.insert(vehicleWarranties).values({
          id: warrantyInstanceId,
          vehicleId: vehicle.id,
          templateId: current.warrantyTemplateId,
          saleDate,
          saleMileageKm: mileage,
          warrantyEndDate: addYears(saleDate, template.duration_years),
          warrantyEndMileage: mileage + template.mileage_limit_km,
          status: "active",
          termsSnapshot: current.warrantySnapshot as object,
        });
      }

      await tx.update(driverAssignments).set({ status: "completed", unassignedAt: new Date() }).where(and(
        eq(driverAssignments.orgId, id), eq(driverAssignments.vehicleId, vehicle.id), eq(driverAssignments.status, "active"),
      ));

      const serviceHistory = await tx.select().from(serviceRecords).where(and(
        eq(serviceRecords.vehicleId, vehicle.id), organizationRecord(serviceRecords, id),
      ));

      const [transferred] = await tx.insert(transferredVehicles).values({
        id: newId(),
        vehicleId: vehicle.id,
        orgId: id,
        buyerUserId: current.buyerUserId,
        transferredBy: actorId,
        warrantyInstanceId,
        handoverId: current.id,
        vehicleSnapshot,
        serviceSnapshot: serviceHistory.map((row) => ({
          id: row.id,
          serviced_on: dateOnly(row.servicedOn),
          odometer: reqNum(row.odometer),
          total_cost: reqNum(row.totalCost),
          currency: row.currency,
          workshop_name: row.workshopName,
          notes: row.notes,
        })),
      }).returning();

      const completedAt = new Date();
      const completionResult = {
        handover_id: current.id,
        status: "completed",
        vehicle_id: vehicle.id,
        buyer_user_id: current.buyerUserId,
        transferred_vehicle_id: transferred.id,
        sale_date: saleDate,
        current_mileage_km: mileage,
        plan_item_ids: createdPlans.map((row) => row.id),
        warranty_instance_id: warrantyInstanceId,
        completed_at: completedAt.toISOString(),
      };
      const [completed] = await tx.update(vehicleHandovers).set({
        status: "completed",
        completedBy: actorId,
        completedAt,
        resultSnapshot: completionResult,
        vehicleSnapshot,
        updatedAt: completedAt,
      }).where(eq(vehicleHandovers.id, current.id)).returning();

      const vehiclePayload = publicVehicle(updatedVehicle);
      const receiptPayload = { ...completionResult };
      await recordChange(tx, { userId: current.buyerUserId, entityType: "vehicle", entityId: vehicle.id, op: "upsert", payload: vehiclePayload });
      for (const planRow of createdPlans) {
        await recordChange(tx, {
          userId: current.buyerUserId, entityType: "plan_item", entityId: planRow.id, op: "upsert",
          payload: publicPlan(planRow),
        });
      }
      if (warrantyInstanceId) {
        await recordChange(tx, {
          userId: current.buyerUserId, entityType: "warranty", entityId: warrantyInstanceId, op: "upsert",
          payload: {
            id: warrantyInstanceId,
            vehicle_id: vehicle.id,
            sale_date: saleDate,
            sale_mileage_km: mileage,
            status: "active",
            terms: current.warrantySnapshot,
          },
        });
      }
      await recordChange(tx, {
        userId: current.buyerUserId, entityType: "handover_receipt", entityId: current.id, op: "upsert",
        payload: { ...receiptPayload, id: current.id, vehicle_id: vehicle.id },
      });

      await tx.insert(vehicleHandoverEvents).values([
        { id: newId(), handoverId: current.id, buyerUserId: current.buyerUserId, eventType: "vehicle", entityId: vehicle.id },
        ...(createdPlans.length ? [{ id: newId(), handoverId: current.id, buyerUserId: current.buyerUserId, eventType: "plan", entityId: createdPlans[0].id }] : []),
        ...(warrantyInstanceId ? [{ id: newId(), handoverId: current.id, buyerUserId: current.buyerUserId, eventType: "warranty", entityId: warrantyInstanceId }] : []),
        { id: newId(), handoverId: current.id, buyerUserId: current.buyerUserId, eventType: "receipt", entityId: current.id },
      ]);

      return { row: completed, result: completionResult, idempotent: false };
    });

    const delivered = await app.db.update(vehicleHandoverEvents).set({
      status: "delivered",
      attempts: sql`${vehicleHandoverEvents.attempts} + 1`,
      deliveredAt: new Date(),
    }).where(and(eq(vehicleHandoverEvents.handoverId, handoverId), eq(vehicleHandoverEvents.status, "queued"))).returning({ id: vehicleHandoverEvents.id });

    return reply.code(result.idempotent ? 200 : 201).send({
      ...(result.result ?? {}),
      id: handoverId,
      idempotent: result.idempotent,
      delivery: { queued: 0, delivered: delivered.length },
      status: result.row.status,
    });
  });
};
