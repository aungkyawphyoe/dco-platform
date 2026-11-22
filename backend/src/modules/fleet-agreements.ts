import { randomUUID } from "node:crypto";
import { and, asc, desc, eq, getTableColumns, inArray, isNull, sql } from "drizzle-orm";
import type { FastifyPluginAsync, FastifyRequest } from "fastify";
import { z } from "zod";
import type { Db } from "../db/client.js";
import {
  auditEvents, documents, fleetAgreementKindEnum, fleetAgreementNotices, fleetAgreements, fleetAgreementTerms,
  fleetAgreementTermVehicles, organizationMembers, organizationVehicles, vehicleOwnershipPeriods,
} from "../db/schema.js";
import { AppError } from "../lib/errors.js";
import { requireFleetPortal } from "./auth.js";
import { assertPasswordChangeClear, getOrganizationAccess } from "./fleet.js";

const uuid = z.string().uuid();
const date = z.string().date();
const params = z.object({ id: uuid });
const agreementParams = params.extend({ agreementId: uuid });
const termFields = z.object({
  provider: z.string().trim().min(1).max(200),
  starts_on: date,
  ends_on: date,
  reminder_lead_days: z.number().int().positive().max(2147483647),
  document_id: uuid.optional(),
  vehicle_ids: z.array(uuid).min(1).transform(ids => [...new Set(ids.map(id => id.toLowerCase()))]),
});
const validDates = (term: z.infer<typeof termFields>) => term.ends_on >= term.starts_on;
const createInput = termFields.extend({
  kind: z.enum(fleetAgreementKindEnum.enumValues),
  responsible_member_id: uuid,
}).refine(validDates, { path: ["ends_on"], message: "End date must be on or after start date" });
const renewInput = termFields.extend({
  expected_term_number: z.number().int().positive(),
}).refine(validDates, { path: ["ends_on"], message: "End date must be on or after start date" });

type Transaction = Parameters<Parameters<Db["transaction"]>[0]>[0];

async function validateTermReferences(tx: Transaction, orgId: string, input: z.infer<typeof termFields>) {
  const vehicles = await tx.select({ id: organizationVehicles.vehicleId }).from(organizationVehicles)
    .where(and(eq(organizationVehicles.orgId, orgId), inArray(organizationVehicles.vehicleId, input.vehicle_ids)))
    .orderBy(asc(organizationVehicles.vehicleId)).for("share");
  if (vehicles.length !== input.vehicle_ids.length) {
    throw new AppError(422, "invalid_agreement_vehicles", "Choose vehicles currently in this organization");
  }
  if (input.document_id) {
    const [document] = await tx.select({ id: documents.id }).from(documents)
      .innerJoin(vehicleOwnershipPeriods, and(eq(documents.ownershipPeriodId, vehicleOwnershipPeriods.id),
        eq(documents.vehicleId, vehicleOwnershipPeriods.vehicleId)))
      .where(and(eq(documents.id, input.document_id), eq(vehicleOwnershipPeriods.orgId, orgId),
        isNull(vehicleOwnershipPeriods.endedAt), inArray(documents.vehicleId, input.vehicle_ids)))
      .for("share");
    if (!document) throw new AppError(422, "invalid_agreement_document", "Choose an organization document for a covered vehicle");
  }
}

async function activeMember(tx: Transaction, orgId: string, memberId: string) {
  const [member] = await tx.select({ id: organizationMembers.id }).from(organizationMembers)
    .where(and(eq(organizationMembers.id, memberId), eq(organizationMembers.orgId, orgId),
      eq(organizationMembers.status, "active"))).for("share");
  if (!member) throw new AppError(422, "invalid_responsible_member", "Choose an active organization member");
  return member.id;
}

async function lockAgreement(tx: Transaction, orgId: string, agreementId: string) {
  const [agreement] = await tx.select().from(fleetAgreements)
    .where(and(eq(fleetAgreements.id, agreementId), eq(fleetAgreements.orgId, orgId))).for("update");
  if (!agreement) throw new AppError(404, "agreement_not_found", "Agreement not found");
  return agreement;
}

function termValues(input: z.infer<typeof termFields>) {
  return {
    provider: input.provider, startsOn: input.starts_on, endsOn: input.ends_on,
    reminderLeadDays: input.reminder_lead_days, documentId: input.document_id ?? null,
  };
}

async function insertTerm(tx: Transaction, orgId: string, agreementId: string, termNumber: number, input: z.infer<typeof termFields>) {
  await validateTermReferences(tx, orgId, input);
  const [term] = await tx.insert(fleetAgreementTerms).values({
    id: randomUUID(), agreementId, termNumber, ...termValues(input),
  }).returning();
  await tx.insert(fleetAgreementTermVehicles).values(input.vehicle_ids.map(vehicleId => ({ termId: term.id, vehicleId })));
  return { ...term, vehicleIds: input.vehicle_ids };
}

export const fleetAgreementsPlugin: FastifyPluginAsync = async app => {
  const route = "/organizations/:id/agreements";

  async function access(request: FastifyRequest, orgId: string, adminOnly = false) {
    requireFleetPortal(request);
    const actor = request.authUser!.sub;
    await assertPasswordChangeClear(app.db, actor);
    await getOrganizationAccess(app.db, actor, orgId, adminOnly ? ["org_admin"] : ["org_admin", "org_manager"]);
    return actor;
  }

  app.get(route, async request => {
    const { id } = params.parse(request.params);
    await access(request, id);
    return app.db.select({
      ...getTableColumns(fleetAgreements),
      currentProvider: sql<string | null>`(SELECT ${fleetAgreementTerms.provider} FROM ${fleetAgreementTerms}
        WHERE ${fleetAgreementTerms.agreementId} = "fleet_agreements"."id"
        ORDER BY ${fleetAgreementTerms.termNumber} DESC LIMIT 1)`,
    }).from(fleetAgreements).where(eq(fleetAgreements.orgId, id))
      .orderBy(desc(fleetAgreements.createdAt), asc(fleetAgreements.id));
  });

  app.get(route + "/vehicle-documents/:vehicleId", async request => {
    const { id, vehicleId } = params.extend({ vehicleId: uuid }).parse(request.params);
    await access(request, id);
    return app.db.select({ id: documents.id, name: documents.name }).from(documents)
      .innerJoin(vehicleOwnershipPeriods, and(eq(documents.ownershipPeriodId, vehicleOwnershipPeriods.id),
        eq(documents.vehicleId, vehicleOwnershipPeriods.vehicleId)))
      .innerJoin(organizationVehicles, and(eq(organizationVehicles.vehicleId, documents.vehicleId),
        eq(organizationVehicles.orgId, id)))
      .where(and(eq(documents.vehicleId, vehicleId), eq(vehicleOwnershipPeriods.orgId, id),
        isNull(vehicleOwnershipPeriods.endedAt)))
      .orderBy(asc(documents.name), asc(documents.id));
  });

  app.get(route + "/:agreementId", async request => {
    const { id, agreementId } = agreementParams.parse(request.params);
    await access(request, id);
    const rows = await app.db.select().from(fleetAgreements)
      .leftJoin(fleetAgreementTerms, eq(fleetAgreementTerms.agreementId, fleetAgreements.id))
      .leftJoin(fleetAgreementTermVehicles, eq(fleetAgreementTermVehicles.termId, fleetAgreementTerms.id))
      .where(and(eq(fleetAgreements.orgId, id), eq(fleetAgreements.id, agreementId)))
      .orderBy(desc(fleetAgreementTerms.termNumber), asc(fleetAgreementTermVehicles.vehicleId));
    if (!rows.length) throw new AppError(404, "agreement_not_found", "Agreement not found");
    const terms = new Map<string, typeof fleetAgreementTerms.$inferSelect & { vehicleIds: string[] }>();
    for (const { fleet_agreement_terms: term, fleet_agreement_term_vehicles: coverage } of rows) {
      if (!term) continue;
      const item = terms.get(term.id) ?? { ...term, vehicleIds: [] };
      if (coverage) item.vehicleIds.push(coverage.vehicleId);
      terms.set(term.id, item);
    }
    return { ...rows[0].fleet_agreements, terms: [...terms.values()] };
  });

  app.get(route + "/:agreementId/reminder-deliveries", async request => {
    const { id, agreementId } = agreementParams.parse(request.params);
    await access(request, id, true);
    const rows = await app.db.select({ notice: fleetAgreementNotices }).from(fleetAgreements)
      .leftJoin(fleetAgreementTerms, eq(fleetAgreementTerms.agreementId, fleetAgreements.id))
      .leftJoin(fleetAgreementNotices, eq(fleetAgreementNotices.termId, fleetAgreementTerms.id))
      .where(and(eq(fleetAgreements.orgId, id), eq(fleetAgreements.id, agreementId)))
      .orderBy(desc(fleetAgreementNotices.attemptedAt));
    if (!rows.length) throw new AppError(404, "agreement_not_found", "Agreement not found");
    return rows.flatMap(({ notice }) => notice ? [notice] : []);
  });

  app.post(route, async (request, reply) => {
    const { id } = params.parse(request.params);
    const actor = await access(request, id);
    const body = createInput.parse(request.body);
    const result = await app.db.transaction(async tx => {
      const responsibleMemberId = await activeMember(tx, id, body.responsible_member_id);
      const [agreement] = await tx.insert(fleetAgreements).values({
        id: randomUUID(), orgId: id, kind: body.kind, responsibleMemberId,
      }).returning();
      const term = await insertTerm(tx, id, agreement.id, 1, body);
      await tx.insert(auditEvents).values({
        adminUserId: actor, action: "fleet_agreement_created", detail: { orgId: id, agreementId: agreement.id, termId: term.id },
      });
      return { ...agreement, terms: [term] };
    });
    return reply.code(201).send(result);
  });

  app.post(route + "/:agreementId/renewals", async (request, reply) => {
    const { id, agreementId } = agreementParams.parse(request.params);
    const actor = await access(request, id);
    const body = renewInput.parse(request.body);
    const term = await app.db.transaction(async tx => {
      const agreement = await lockAgreement(tx, id, agreementId);
      if (agreement.archivedAt) throw new AppError(409, "agreement_archived", "Archived agreements cannot be renewed");
      const [previous] = await tx.select().from(fleetAgreementTerms).where(eq(fleetAgreementTerms.agreementId, agreementId))
        .orderBy(desc(fleetAgreementTerms.termNumber)).limit(1);
      if (previous?.termNumber !== body.expected_term_number) {
        throw new AppError(409, "agreement_term_changed", "Reload the agreement before renewing it");
      }
      const next = await insertTerm(tx, id, agreementId, previous.termNumber + 1, body);
      await tx.insert(auditEvents).values({
        adminUserId: actor, action: "fleet_agreement_renewed", detail: { orgId: id, agreementId, termId: next.id },
      });
      return next;
    });
    return reply.code(201).send(term);
  });
  app.put(route + "/:agreementId/current-term", async request => {
    const { id, agreementId } = agreementParams.parse(request.params);
    const actor = await access(request, id);
    const body = renewInput.parse(request.body);
    return app.db.transaction(async tx => {
      const agreement = await lockAgreement(tx, id, agreementId);
      if (agreement.archivedAt) throw new AppError(409, "agreement_archived", "Archived agreements cannot be edited");
      const [current] = await tx.select().from(fleetAgreementTerms)
        .where(eq(fleetAgreementTerms.agreementId, agreementId))
        .orderBy(desc(fleetAgreementTerms.termNumber)).limit(1);
      if (current?.termNumber !== body.expected_term_number) {
        throw new AppError(409, "agreement_term_changed", "Reload the agreement before editing it");
      }
      await validateTermReferences(tx, id, body);
      const [term] = await tx.update(fleetAgreementTerms).set(termValues(body))
        .where(eq(fleetAgreementTerms.id, current.id)).returning();
      await tx.delete(fleetAgreementTermVehicles).where(eq(fleetAgreementTermVehicles.termId, term.id));
      await tx.insert(fleetAgreementTermVehicles).values(body.vehicle_ids.map(vehicleId => ({ termId: term.id, vehicleId })));
      await tx.insert(auditEvents).values({
        adminUserId: actor, action: "fleet_agreement_term_updated", detail: { orgId: id, agreementId, termId: term.id },
      });
      return { ...term, vehicleIds: body.vehicle_ids };
    });
  });

  app.put(route + "/:agreementId/responsible-member", async request => {
    const { id, agreementId } = agreementParams.parse(request.params);
    const actor = await access(request, id, true);
    const body = z.object({ responsible_member_id: uuid }).parse(request.body);
    return app.db.transaction(async tx => {
      const agreement = await lockAgreement(tx, id, agreementId);
      if (agreement.archivedAt) throw new AppError(409, "agreement_archived", "Archived agreements cannot be edited");
      const memberId = await activeMember(tx, id, body.responsible_member_id);
      if (agreement.responsibleMemberId === memberId) return agreement;
      const [updated] = await tx.update(fleetAgreements).set({ responsibleMemberId: memberId })
        .where(eq(fleetAgreements.id, agreementId)).returning();
      await tx.insert(auditEvents).values({
        adminUserId: actor, action: "fleet_agreement_owner_changed",
        detail: { orgId: id, agreementId, previousMemberId: agreement.responsibleMemberId, memberId },
      });
      return updated;
    });
  });

  app.post(route + "/:agreementId/archive", async request => {
    const { id, agreementId } = agreementParams.parse(request.params);
    const actor = await access(request, id);
    return app.db.transaction(async tx => {
      const agreement = await lockAgreement(tx, id, agreementId);
      if (agreement.archivedAt) return agreement;
      const [updated] = await tx.update(fleetAgreements).set({ archivedAt: new Date() })
        .where(eq(fleetAgreements.id, agreementId)).returning();
      await tx.insert(auditEvents).values({
        adminUserId: actor, action: "fleet_agreement_archived", detail: { orgId: id, agreementId },
      });
      return updated;
    });
  });

};
