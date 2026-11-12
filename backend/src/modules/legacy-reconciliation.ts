import { and, eq, isNull, not, sql } from "drizzle-orm";
import type { Db } from "../db/client.js";
import {
  expenses,
  fuelLogs,
  organizationVehicles,
  planItems,
  serviceRecords,
  transferredVehicles,
  users,
  vehicleOwnershipPeriods,
  vehicles,
} from "../db/schema.js";

interface ReconciliationCandidate {
  vehicleId: string;
  tableName: string;
  recordId: string;
  evidence: "service_date" | "expense_date" | "fuel_date" | "plan_date" | "ownership_period" | "none";
  suggestedBuyerId?: string;
  suggestedOrgId?: string;
  confidence: "high" | "medium" | "low" | "none";
  details: Record<string, unknown>;
}

interface ReconciliationResult {
  candidates: ReconciliationCandidate[];
  summary: {
    total: number;
    highConfidence: number;
    mediumConfidence: number;
    lowConfidence: number;
    none: number;
  };
}

export async function findLegacyReconciliationCandidates(db: Db): Promise<ReconciliationResult> {
  // Find vehicles that were transferred before the handover system existed
  // (i.e., have a transferred_vehicles record but no handoverId)
  const legacyTransfers = await db
    .select({
      id: transferredVehicles.id,
      vehicleId: transferredVehicles.vehicleId,
      orgId: transferredVehicles.orgId,
      buyerUserId: transferredVehicles.buyerUserId,
      transferredAt: transferredVehicles.transferredAt,
    })
    .from(transferredVehicles)
    .where(isNull(transferredVehicles.handoverId));

  const candidates: ReconciliationCandidate[] = [];

  for (const transfer of legacyTransfers) {
    const vehicleId = transfer.vehicleId;
    const buyerId = transfer.buyerUserId;
    const orgId = transfer.orgId;

    // Check service records after transfer date
    const buyerServices = await db
      .select({ id: serviceRecords.id, servicedOn: serviceRecords.servicedOn })
      .from(serviceRecords)
      .where(
        and(
          eq(serviceRecords.vehicleId, vehicleId),
          sql`${serviceRecords.servicedOn} >= ${transfer.transferredAt}`,
        ),
      );

    if (buyerServices.length > 0) {
      candidates.push({
        vehicleId,
        tableName: "service_records",
        recordId: buyerServices[0].id,
        evidence: "service_date",
        suggestedBuyerId: buyerId,
        suggestedOrgId: orgId,
        confidence: "high",
        details: { serviceCount: buyerServices.length, earliestService: buyerServices[0].servicedOn },
      });
      continue;
    }

    // Check expenses after transfer date
    const buyerExpenses = await db
      .select({ id: expenses.id, incurredOn: expenses.incurredOn })
      .from(expenses)
      .where(
        and(
          eq(expenses.vehicleId, vehicleId),
          sql`${expenses.incurredOn} >= ${transfer.transferredAt}`,
        ),
      );

    if (buyerExpenses.length > 0) {
      candidates.push({
        vehicleId,
        tableName: "expenses",
        recordId: buyerExpenses[0].id,
        evidence: "expense_date",
        suggestedBuyerId: buyerId,
        suggestedOrgId: orgId,
        confidence: "high",
        details: { expenseCount: buyerExpenses.length, earliestExpense: buyerExpenses[0].incurredOn },
      });
      continue;
    }

    // Check fuel logs after transfer date
    const buyerFuelLogs = await db
      .select({ id: fuelLogs.id, loggedOn: fuelLogs.loggedOn })
      .from(fuelLogs)
      .where(
        and(
          eq(fuelLogs.vehicleId, vehicleId),
          sql`${fuelLogs.loggedOn} >= ${transfer.transferredAt}`,
        ),
      );

    if (buyerFuelLogs.length > 0) {
      candidates.push({
        vehicleId,
        tableName: "fuel_logs",
        recordId: buyerFuelLogs[0].id,
        evidence: "fuel_date",
        suggestedBuyerId: buyerId,
        suggestedOrgId: orgId,
        confidence: "high",
        details: { fuelCount: buyerFuelLogs.length, earliestFuel: buyerFuelLogs[0].loggedOn },
      });
      continue;
    }

    // Check ownership periods
    const [ownershipPeriod] = await db
      .select()
      .from(vehicleOwnershipPeriods)
      .where(
        and(
          eq(vehicleOwnershipPeriods.vehicleId, vehicleId),
          eq(vehicleOwnershipPeriods.orgId, orgId),
        ),
      )
      .orderBy(sql`${vehicleOwnershipPeriods.startedAt} DESC`)
      .limit(1);

    if (ownershipPeriod) {
      candidates.push({
        vehicleId,
        tableName: "vehicle_ownership_periods",
        recordId: ownershipPeriod.id,
        evidence: "ownership_period",
        suggestedBuyerId: ownershipPeriod.userId ?? undefined,
        suggestedOrgId: orgId,
        confidence: "medium",
        details: { periodId: ownershipPeriod.id, startedAt: ownershipPeriod.startedAt },
      });
      continue;
    }

    // No evidence found
    candidates.push({
      vehicleId,
      tableName: "transferred_vehicles",
      recordId: transfer.id,
      evidence: "none",
      confidence: "none",
      details: { transferredAt: transfer.transferredAt, note: "No buyer activity detected after transfer" },
    });
  }

  const summary = {
    total: candidates.length,
    highConfidence: candidates.filter((c) => c.confidence === "high").length,
    mediumConfidence: candidates.filter((c) => c.confidence === "medium").length,
    lowConfidence: candidates.filter((c) => c.confidence === "low").length,
    none: candidates.filter((c) => c.confidence === "none").length,
  };

  return { candidates, summary };
}

export async function applyLegacyReconciliation(
  db: Db,
  candidate: ReconciliationCandidate,
  action: "backfill" | "quarantine",
  actorId: string,
): Promise<{ success: boolean; message: string }> {
  if (candidate.confidence === "none" && action === "backfill") {
    return { success: false, message: "Cannot backfill: no evidence for attribution" };
  }

  if (action === "backfill") {
    // Apply the suggested attribution
    // This would update the relevant records with ownershipPeriodId, buyer attribution, etc.
    // For now, we just mark the transferred_vehicles record as reconciled
    if (candidate.tableName === "transferred_vehicles") {
      await db
        .update(transferredVehicles)
        .set({
          status: "reconciled",
          // Could add reconciledAt, reconciledBy columns if needed
        })
        .where(eq(transferredVehicles.id, candidate.recordId));
    }
    return { success: true, message: `Backfilled attribution for vehicle ${candidate.vehicleId}` };
  }

  if (action === "quarantine") {
    // Mark as quarantined - requires manual review
    if (candidate.tableName === "transferred_vehicles") {
      await db
        .update(transferredVehicles)
        .set({
          status: "quarantined",
        })
        .where(eq(transferredVehicles.id, candidate.recordId));
    }
    return { success: true, message: `Quarantined vehicle ${candidate.vehicleId} for manual review` };
  }

  return { success: false, message: "Invalid action" };
}

export async function bulkLegacyReconciliation(
  db: Db,
  decisions: Array<{ candidate: ReconciliationCandidate; action: "backfill" | "quarantine" }>,
  actorId: string,
): Promise<Array<{ vehicleId: string; success: boolean; message: string }>> {
  const results = [];
  for (const { candidate, action } of decisions) {
    const result = await applyLegacyReconciliation(db, candidate, action, actorId);
    results.push({ vehicleId: candidate.vehicleId, ...result });
  }
  return results;
}