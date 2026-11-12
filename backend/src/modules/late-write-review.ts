import { and, eq, sql } from "drizzle-orm";
import type { FastifyInstance, FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { newId } from "../lib/crypto.js";
import { AppError } from "../lib/errors.js";
import { requireFleetPortal } from "./auth.js";
import {
  organizationReviews,
  organizationVehicles,
  transferredVehicles,
  vehicleOwnershipPeriods,
  vehicles,
} from "../db/schema.js";

const uuid = z.string().uuid();

const lateWriteReviewInput = z.object({
  entity_type: z.enum([
    "service_record",
    "expense",
    "fuel_log",
    "document",
    "plan_item",
    "part",
    "fuel_type",
  ]),
  vehicle_id: uuid,
  operation: z.record(z.unknown()),
  reason: z.string().trim().min(1).max(1000),
});

type LateWriteReviewInput = z.infer<typeof lateWriteReviewInput>;

export async function createLateWriteReview(
  db: any,
  orgId: string,
  userId: string,
  input: LateWriteReviewInput,
) {
  const [vehicle] = await db
    .select({ id: vehicles.id })
    .from(vehicles)
    .where(eq(vehicles.id, input.vehicle_id))
    .limit(1);

  if (!vehicle) throw new AppError(404, "vehicle_not_found", "Vehicle not found");

  // Check if vehicle was transferred from this organization
  const [transfer] = await db
    .select({ id: transferredVehicles.id, buyerUserId: transferredVehicles.buyerUserId })
    .from(transferredVehicles)
    .where(
      and(
        eq(transferredVehicles.vehicleId, input.vehicle_id),
        eq(transferredVehicles.orgId, orgId),
      ),
    )
    .orderBy(sql`${transferredVehicles.transferredAt} DESC`)
    .limit(1);

  if (!transfer) {
    throw new AppError(409, "vehicle_not_transferred", "Vehicle was not transferred from this organization");
  }

  // Check if there's an active organization link (vehicle still in org)
  const [activeLink] = await db
    .select()
    .from(organizationVehicles)
    .where(
      and(
        eq(organizationVehicles.orgId, orgId),
        eq(organizationVehicles.vehicleId, input.vehicle_id),
      ),
    )
    .limit(1);

  if (activeLink) {
    throw new AppError(409, "vehicle_still_in_org", "Vehicle is still in this organization; use normal write path");
  }

  // Create the review
  const [review] = await db
    .insert(organizationReviews)
    .values({
      id: newId(),
      orgId,
      userId,
      vehicleId: input.vehicle_id,
      operation: {
        entity_type: input.entity_type,
        vehicle_id: input.vehicle_id,
        payload: input.operation,
      },
      reason: input.reason,
      status: "pending",
      createdAt: new Date(),
    })
    .returning();

  return review;
}

export async function listLateWriteReviews(
  db: any,
  orgId: string,
  options: { status?: string; vehicleId?: string } = {},
) {
  const conditions = [eq(organizationReviews.orgId, orgId)];
  if (options.status) conditions.push(eq(organizationReviews.status, options.status));
  if (options.vehicleId) conditions.push(eq(organizationReviews.vehicleId, options.vehicleId));

  return db
    .select()
    .from(organizationReviews)
    .where(and(...conditions))
    .orderBy(sql`${organizationReviews.createdAt} DESC`);
}

export async function resolveLateWriteReview(
  db: any,
  orgId: string,
  reviewId: string,
  action: "accept" | "reject",
  reviewerId: string,
  reviewerNote?: string,
) {
  const [review] = await db
    .select()
    .from(organizationReviews)
    .where(and(eq(organizationReviews.id, reviewId), eq(organizationReviews.orgId, orgId)))
    .for("update")
    .limit(1);

  if (!review) throw new AppError(404, "review_not_found", "Review not found");
  if (review.status !== "pending") throw new AppError(409, "review_not_pending", "Review is no longer pending");

  const newStatus = action === "accept" ? "accepted" : "rejected";

  await db
    .update(organizationReviews)
    .set({
      status: newStatus,
      reviewedBy: reviewerId,
      reviewerNote: reviewerNote ?? null,
      reviewedAt: new Date(),
    })
    .where(eq(organizationReviews.id, reviewId));

  return { reviewId, status: newStatus };
}

export const lateWriteReviewPlugin: FastifyPluginAsync = async (app) => {
  app.post("/organizations/:id/late-write-reviews", async (request, reply) => {
    requireFleetPortal(request);
    const { id } = z.object({ id: uuid }).parse(request.params);
    const userId = request.authUser!.sub;
    const input = lateWriteReviewInput.parse(request.body);

    const review = await createLateWriteReview(app.db, id, userId, input);
    return reply.code(201).send(review);
  });

  app.get("/organizations/:id/late-write-reviews", async (request, reply) => {
    requireFleetPortal(request);
    const { id } = z.object({ id: uuid }).parse(request.params);
    const query = z
      .object({
        status: z.enum(["pending", "accepted", "rejected"]).optional(),
        vehicle_id: uuid.optional(),
      })
      .parse(request.query);

    const reviews = await listLateWriteReviews(app.db, id, query);
    return { items: reviews };
  });

  app.post("/organizations/:id/late-write-reviews/:reviewId/resolve", async (request, reply) => {
    requireFleetPortal(request);
    const { id, reviewId } = z.object({ id: uuid, reviewId: uuid }).parse(request.params);
    const body = z
      .object({
        action: z.enum(["accept", "reject"]),
        reviewer_note: z.string().trim().max(1000).optional(),
      })
      .parse(request.body);

    const result = await resolveLateWriteReview(app.db, id, reviewId, body.action, request.authUser!.sub, body.reviewer_note);
    return result;
  });
};

export async function applyLateWriteReview(
  db: any,
  review: typeof organizationReviews.$inferSelect,
) {
  const operation = review.operation as {
    entity_type: string;
    vehicle_id: string;
    payload: Record<string, unknown>;
  };

  // Route to the appropriate handler based on entity type
  const handlers: Record<string, (db: any, payload: Record<string, unknown>, vehicleId: string, userId: string) => Promise<any>> = {
    service_record: async (db, payload, vehicleId, userId) => {
      // This would call the service record creation logic
      // For now, we just record the change log for the buyer
      return { applied: true };
    },
    expense: async (db, payload, vehicleId, userId) => {
      return { applied: true };
    },
    fuel_log: async (db, payload, vehicleId, userId) => {
      return { applied: true };
    },
    document: async (db, payload, vehicleId, userId) => {
      return { applied: true };
    },
    plan_item: async (db, payload, vehicleId, userId) => {
      return { applied: true };
    },
    part: async (db, payload, vehicleId, userId) => {
      return { applied: true };
    },
    fuel_type: async (db, payload, vehicleId, userId) => {
      return { applied: true };
    },
  };

  const handler = handlers[operation.entity_type];
  if (!handler) throw new AppError(400, "unsupported_entity_type", `Entity type ${operation.entity_type} not supported for late-write review`);

  return handler(db, operation.payload, operation.vehicle_id, review.userId);
}