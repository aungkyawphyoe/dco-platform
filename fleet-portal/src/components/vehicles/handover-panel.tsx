"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useQueryClient } from "@tanstack/react-query";
import { Badge } from "@dco/ui/components/badge";
import { Button } from "@dco/ui/components/button";
import { Input } from "@dco/ui/components/input";
import { Modal } from "@dco/ui/components/modal";
import { Select } from "@dco/ui/components/select";
import { Skeleton } from "@dco/ui/components/skeleton";
import { ApiError } from "@/lib/api/client";
import {
  useCancelHandover,
  useCompleteHandover,
  useCreateHandover,
  useHandover,
  useLookupHandoverBuyer,
  useMembers,
  useReviewHandover,
  useUpdateHandover,
  useVehicleHandovers,
  useWarrantyTemplates,
} from "@/lib/api/hooks";
import type {
  FleetVehicle,
  HandoverBuyer,
  HandoverCompletion,
  HandoverDraftInput,
  HandoverPlanItem,
  HandoverWarrantyChoice,
  VehicleHandover,
  VehicleHandoverDetail,
  VehiclePlanItem,
} from "@/lib/api/types";
import { useOrgRole, useSession } from "@/lib/auth/session-context";
import { formatDate, formatDateTime } from "@dco/ui/lib/format";
import {
  HandoverPlanEditor,
  planIssues,
  planItemsFromRows,
  planRowsFromItems,
  planSaveIssues,
  type PlanDraftRow,
} from "./handover-plan-editor";
import { QrScanner } from "./qr-scanner";

// The handover API validates sale dates against the UTC calendar day.
function serverToday(): string {
  return new Date().toISOString().slice(0, 10);
}

function seedPlan(items: VehiclePlanItem[]): HandoverPlanItem[] {
  return items.filter((item) => item.enabled).map((item) => ({
    name: item.name,
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

function handoverError(cause: unknown): string {
  if (cause instanceof ApiError) {
    switch (cause.code) {
      case "handover_changed":
        return "This handover changed since it was loaded. Refresh the checks and review the latest revision again.";
      case "review_required":
        return "Review the current revision before completing the handover.";
      case "transfer_permission_required":
        return "An organization admin must grant you handover completion permission.";
      case "handover_not_ready":
        return "Resolve the blocking issues before continuing.";
      case "handover_pending":
        return "This vehicle already has a pending handover draft. Refresh to continue it.";
      case "handover_not_draft":
        return "This handover can no longer be changed.";
      case "buyer_not_eligible":
        return "The buyer must be an existing active personal account.";
      case "buyer_is_owner":
        return "This account already owns the vehicle.";
      case "buyer_not_found":
        return "No account matches that exact email or account ID.";
      case "vehicle_not_ready_for_handover":
        return "The vehicle must be reserved in the showroom lifecycle.";
      case "warranty_template_required":
        return "Select a warranty template or choose No warranty.";
      case "warranty_terms_missing":
        return "The reviewed warranty terms are missing. Choose the template again and save.";
      case "cancellation_reason_required":
        return "Record why this handover was cancelled.";
      default:
        return cause.message;
    }
  }
  return cause instanceof Error
    ? cause.message
    : "The handover request failed. Please retry.";
}

type DraftSignature = {
  saleDate: string;
  mileage: string;
  rows: PlanDraftRow[];
  warrantyChoice: HandoverWarrantyChoice;
  warrantyTemplateId: string;
};

function draftSignature({
  saleDate,
  mileage,
  rows,
  warrantyChoice,
  warrantyTemplateId,
}: DraftSignature): string {
  const mileageNumber = mileage.trim() ? Math.floor(Number(mileage)) : null;
  return JSON.stringify({
    sale_date: saleDate || null,
    current_mileage_km: Number.isFinite(mileageNumber) ? mileageNumber : null,
    plan: rows.map((row) => {
      const timeCount = row.time_count.trim() ? Number(row.time_count) : null;
      const intervalDistance = row.interval_distance.trim()
        ? Number(row.interval_distance)
        : null;
      const nextDueMileage = row.next_due_mileage.trim()
        ? Number(row.next_due_mileage)
        : null;
      return {
        name: row.name.trim(),
        next_due_on: row.next_due_on || null,
        next_due_mileage: Number.isFinite(nextDueMileage) ? nextDueMileage : null,
        initial_service_required: row.initial_service_required,
        time_count: Number.isFinite(timeCount) ? timeCount : null,
        time_unit:
          timeCount != null && Number.isFinite(timeCount) ? row.time_unit : null,
        interval_distance: Number.isFinite(intervalDistance)
          ? intervalDistance
          : null,
        warning_days: row.warning_days,
        warning_distance: row.warning_distance,
        notes: row.notes.trim() || null,
      };
    }),
    warranty_choice: warrantyChoice,
    warranty_template_id:
      warrantyChoice === "template" ? warrantyTemplateId || null : null,
  });
}

function draftPayload(
  saleDate: string,
  mileage: string,
  rows: PlanDraftRow[],
  warrantyChoice: HandoverWarrantyChoice,
  warrantyTemplateId: string,
): HandoverDraftInput {
  const mileageNumber = mileage.trim() ? Math.floor(Number(mileage)) : null;
  return {
    sale_date: saleDate || null,
    current_mileage_km: Number.isFinite(mileageNumber) ? mileageNumber : null,
    plan: planItemsFromRows(rows),
    warranty_choice: warrantyChoice,
    warranty_template_id:
      warrantyChoice === "template" ? warrantyTemplateId || null : null,
  };
}

function buyerLabel(buyer: HandoverBuyer | null | undefined): string {
  return buyer?.display_name?.trim() || "Matched account";
}

function PlanSummary({ plan }: { plan: HandoverPlanItem[] }) {
  if (plan.length === 0) {
    return <p className="text-sm text-ink-caption">No plan items.</p>;
  }
  return (
    <ul className="divide-y divide-line-subtle rounded-md border border-line-subtle">
      {plan.map((item, index) => {
        const due = [
          item.next_due_on ? `due ${formatDate(item.next_due_on)}` : null,
          item.next_due_mileage != null
            ? `at ${item.next_due_mileage.toLocaleString(undefined, { maximumFractionDigits: 0 })} km`
            : null,
        ]
          .filter(Boolean)
          .join(" ");
        const repeat = [
          item.time_count
            ? `every ${item.time_count} ${item.time_unit ?? "days"}`
            : null,
          item.interval_distance
            ? `every ${item.interval_distance.toLocaleString()} km`
            : null,
        ]
          .filter(Boolean)
          .join(" and ");
        return (
          <li
            key={`${item.name}-${index}`}
            className="flex flex-wrap items-start justify-between gap-2 px-3 py-2 text-sm"
          >
            <div>
              <p className="font-medium text-ink">{item.name}</p>
              <p className="text-xs text-ink-caption">
                {item.initial_service_required
                  ? "Initial service required \u2014 baseline unknown"
                  : due || "No due target"}
                {repeat ? ` \u00b7 ${repeat}` : ""}
              </p>
            </div>
          </li>
        );
      })}
    </ul>
  );
}

function BuyerIdentity({ buyer }: { buyer: HandoverBuyer }) {
  return (
    <div className="rounded-md border border-line-subtle bg-card p-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="font-medium text-ink">{buyerLabel(buyer)}</p>
        <Badge tone={buyer.eligible ? "success" : "danger"}>
          {buyer.eligible ? "Eligible buyer" : "Not eligible"}
        </Badge>
      </div>
      <p className="mt-1 text-sm text-ink-caption">
        {buyer.email_masked ?? "Email unavailable"}
        {buyer.phone_masked ? ` \u00b7 ${buyer.phone_masked}` : ""}
      </p>
      <p className="mt-1 font-mono text-xs text-ink-faint">{buyer.user_id}</p>
      {!buyer.eligible ? (
        <p role="alert" className="mt-2 text-sm text-danger">
          {buyer.reason ?? "This account cannot receive a personal handover."}
        </p>
      ) : null}
    </div>
  );
}

function HandoverHeader({
  status,
  revision,
}: {
  status: VehicleHandover["status"] | null;
  revision?: number;
}) {
  const tone =
    status === "completed"
      ? "success"
      : status === "draft"
        ? "warning"
        : "neutral";
  const label =
    status === "completed"
      ? "Completed"
      : status === "draft"
        ? `Draft${revision ? ` \u00b7 revision ${revision}` : ""}`
        : status === "cancelled"
          ? "Cancelled"
          : "Not started";
  return <Badge tone={tone}>{label}</Badge>;
}

// \u2500\u2500\u2500 Starting a handover \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

function StartHandover({
  orgId,
  vehicle,
  planItems,
}: {
  orgId: string | null;
  vehicle: FleetVehicle;
  planItems: VehiclePlanItem[];
}) {
  const [mode, setMode] = useState<"email" | "account" | "qr">("email");
  const [value, setValue] = useState("");
  const [buyer, setBuyer] = useState<HandoverBuyer | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [qrOpen, setQrOpen] = useState(false);
  const lookup = useLookupHandoverBuyer(orgId);
  const create = useCreateHandover(orgId);
  const queryClient = useQueryClient();

  const busy = lookup.isPending || create.isPending;

  async function findBuyer() {
    setError(null);
    setBuyer(null);
    const trimmed = value.trim();
    if (!trimmed) {
      setError(
        mode === "email"
          ? "Enter the buyer's exact email."
          : "Enter the account ID.",
      );
      return;
    }
    const apiMode = mode === "qr" ? "account" : mode;
    try {
      const found = await lookup.mutateAsync({ mode: apiMode, value: trimmed });
      setBuyer(found);
    } catch (cause) {
      setError(handoverError(cause));
    }
  }

  function handleQrScan(code: string) {
    setValue(code);
    setQrOpen(false);
    setMode("account");
    void findBuyer();
  }

  function closeQr() {
    setQrOpen(false);
    setMode("account");
  }

  async function start() {
    if (!buyer?.eligible || busy) return;
    setError(null);
    try {
      await create.mutateAsync({
        vehicle_id: vehicle.id,
        buyer_user_id: buyer.user_id,
        sale_date: serverToday(),
        current_mileage_km: Math.floor(vehicle.mileage),
        plan: seedPlan(planItems),
        warranty_choice: "undecided",
        warranty_template_id: null,
      });
    } catch (cause) {
      setError(handoverError(cause));
      if (cause instanceof ApiError && cause.code === "handover_pending") {
        await queryClient.invalidateQueries({
          queryKey: ["fleet", "handovers", orgId, vehicle.id],
        });
      }
    }
  }

  if (qrOpen) {
    return (
      <div className="flex flex-col gap-4">
        <p className="max-w-2xl text-sm text-ink-caption">
          Point the camera at the buyer&apos;s account code QR. The buyer finds this
          in their AutoX app under Profile \u2192 Account code.
        </p>
        <QrScanner onScan={handleQrScan} onCancel={closeQr} />
        <Button
          type="button"
          variant="secondary"
          onClick={closeQr}
          disabled={busy}
        >
          Enter account ID manually instead
        </Button>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <p className="max-w-2xl text-sm text-ink-caption">
        Identify an existing active personal account by exact email, account ID,
        or by scanning the buyer&apos;s account code QR.
      </p>

      <div className="grid gap-3 sm:grid-cols-[9rem_1fr_auto_auto] sm:items-end">
        <Select
          label="Lookup by"
          value={mode}
          options={[
            { value: "email", label: "Exact email" },
            { value: "account", label: "Account ID" },
            { value: "qr", label: "Scan QR" },
          ]}
          onChange={(next) => {
            const m = next as "email" | "account" | "qr";
            setMode(m);
            if (m === "qr") {
              setQrOpen(true);
            }
            setValue("");
            setBuyer(null);
            setError(null);
          }}
          disabled={busy}
        />
        <Input
          label={mode === "email" ? "Buyer email" : "Account ID"}
          type={mode === "email" ? "email" : "text"}
          value={value}
          autoComplete="off"
          spellCheck={false}
          placeholder={
            mode === "email"
              ? "buyer@example.com"
              : "Account UUID from the buyer's QR / account code"
          }
          onChange={(event) => {
            setValue(event.target.value);
            setBuyer(null);
            setError(null);
          }}
          onKeyDown={(event) => {
            if (event.key === "Enter") {
              event.preventDefault();
              void findBuyer();
            }
          }}
          disabled={busy || mode === "qr"}
        />
        <Button
          type="button"
          variant="secondary"
          onClick={() => void findBuyer()}
          disabled={busy || mode === "qr"}
        >
          {lookup.isPending ? "Looking up..." : "Find buyer"}
        </Button>
      </div>

      {error ? (
        <p role="alert" className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">
          {error}
        </p>
      ) : null}

      {buyer ? <BuyerIdentity buyer={buyer} /> : null}

      <div className="flex flex-wrap items-center gap-3">
        <Button
          type="button"
          onClick={() => void start()}
          disabled={!buyer?.eligible || busy}
        >
          {create.isPending ? "Starting draft..." : "Start handover draft"}
        </Button>
        <p className="text-xs text-ink-caption">
          The vehicle stays reserved and owned by the showroom until completion.
        </p>
      </div>
    </div>
  );
}

// \u2500\u2500\u2500 Draft preparation, review, and completion \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

function HandoverDraft({
  orgId,
  vehicle,
  handover,
  canComplete,
  onCompleted,
}: {
  orgId: string | null;
  vehicle: FleetVehicle;
  handover: VehicleHandoverDetail;
  canComplete: boolean;
  onCompleted: (receipt: HandoverCompletion) => void;
}) {
  const queryClient = useQueryClient();
  const update = useUpdateHandover(orgId);
  const review = useReviewHandover(orgId);
  const complete = useCompleteHandover(orgId);
  const cancel = useCancelHandover(orgId);
  const templates = useWarrantyTemplates(orgId);

  const [rows, setRows] = useState<PlanDraftRow[]>(() =>
    planRowsFromItems(handover.plan),
  );
  const [saleDate, setSaleDate] = useState(handover.sale_date ?? "");
  const [mileage, setMileage] = useState(
    handover.current_mileage_km == null
      ? ""
      : String(handover.current_mileage_km),
  );
  const [warrantyChoice, setWarrantyChoice] = useState<HandoverWarrantyChoice>(
    handover.warranty_choice,
  );
  const [warrantyTemplateId, setWarrantyTemplateId] = useState(
    handover.warranty_template_id ?? "",
  );
  const [acknowledged, setAcknowledged] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [cancelReason, setCancelReason] = useState("");
  const [cancelError, setCancelError] = useState<string | null>(null);

  const revisionRef = useRef(`${handover.id}:${handover.revision}`);
  useEffect(() => {
    const revisionKey = `${handover.id}:${handover.revision}`;
    if (revisionRef.current === revisionKey) return;
    revisionRef.current = revisionKey;
    setRows(planRowsFromItems(handover.plan));
    setSaleDate(handover.sale_date ?? "");
    setMileage(
      handover.current_mileage_km == null
        ? ""
        : String(handover.current_mileage_km),
    );
    setWarrantyChoice(handover.warranty_choice);
    setWarrantyTemplateId(handover.warranty_template_id ?? "");
    setAcknowledged(false);
    setError(null);
  }, [
    handover.id,
    handover.revision,
    handover.plan,
    handover.sale_date,
    handover.current_mileage_km,
    handover.warranty_choice,
    handover.warranty_template_id,
  ]);

  const currentSignature = draftSignature({
    saleDate,
    mileage,
    rows,
    warrantyChoice,
    warrantyTemplateId,
  });
  const savedSignature = draftSignature({
    saleDate: handover.sale_date ?? "",
    mileage:
      handover.current_mileage_km == null
        ? ""
        : String(handover.current_mileage_km),
    rows: planRowsFromItems(handover.plan),
    warrantyChoice: handover.warranty_choice,
    warrantyTemplateId: handover.warranty_template_id ?? "",
  });
  const dirty = currentSignature !== savedSignature;
  const reviewed = handover.reviewed_revision === handover.revision;

  const localIssues = useMemo(() => {
    const issues = planIssues(rows);
    if (!saleDate) {
      issues.push("Set the sale date.");
    } else if (saleDate > serverToday()) {
      issues.push("Sale date cannot be in the future.");
    }
    if (!mileage.trim()) {
      issues.push("Set the handover mileage.");
    } else {
      const value = Number(mileage);
      if (!Number.isFinite(value) || value < 0) {
        issues.push("Enter a valid handover mileage.");
      } else if (value < Math.floor(vehicle.mileage)) {
        issues.push("Handover mileage cannot be below the last recorded mileage.");
      }
    }
    if (warrantyChoice === "undecided") {
      issues.push("Choose reviewed warranty terms or No warranty.");
    }
    if (warrantyChoice === "template" && !warrantyTemplateId) {
      issues.push("Select a warranty template.");
    }
    return issues;
  }, [rows, saleDate, mileage, warrantyChoice, warrantyTemplateId, vehicle.mileage]);

  const serverIssues = handover.blocking_issues;
  const canReview =
    vehicle.status === "reserved" &&
    !dirty &&
    !reviewed &&
    !review.isPending &&
    localIssues.length === 0 &&
    serverIssues.length === 0;
  const canFinalize =
    canComplete &&
    vehicle.status === "reserved" &&
    reviewed &&
    !dirty &&
    acknowledged &&
    serverIssues.length === 0 &&
    !complete.isPending;

  function refreshChecks() {
    void queryClient.invalidateQueries({
      queryKey: ["fleet", "handover", orgId, handover.id],
    });
    void queryClient.invalidateQueries({
      queryKey: ["fleet", "handovers", orgId, vehicle.id],
    });
  }

  function handleConflict(cause: unknown) {
    if (
      cause instanceof ApiError &&
      ["handover_changed", "handover_not_ready", "review_required"].includes(
        cause.code,
      )
    ) {
      refreshChecks();
    }
    if (
      cause instanceof ApiError &&
      cause.code === "transfer_permission_required"
    ) {
      void queryClient.invalidateQueries({
        queryKey: ["fleet", "members", orgId],
      });
    }
  }

  async function saveDraft() {
    if (update.isPending) return;
    setError(null);
    setNotice(null);
    const saveIssues = planSaveIssues(rows);
    if (saveIssues.length) {
      setError(saveIssues[0]);
      return;
    }
    const mileageValue = mileage.trim() ? Number(mileage) : null;
    if (
      mileageValue != null &&
      (!Number.isFinite(mileageValue) || mileageValue < 0)
    ) {
      setError("Enter a valid handover mileage.");
      return;
    }
    if (saleDate && saleDate > serverToday()) {
      setError("Sale date cannot be in the future.");
      return;
    }
    if (warrantyChoice === "template" && !warrantyTemplateId) {
      setError("Select a warranty template or choose No warranty.");
      return;
    }
    try {
      await update.mutateAsync({
        handoverId: handover.id,
        ...draftPayload(
          saleDate,
          mileage,
          rows,
          warrantyChoice,
          warrantyTemplateId,
        ),
      });
      setNotice("Draft saved. Review the latest revision before completing.");
    } catch (cause) {
      setError(handoverError(cause));
      handleConflict(cause);
    }
  }

  async function reviewDraft() {
    if (!canReview) return;
    setError(null);
    setNotice(null);
    try {
      await review.mutateAsync({
        handoverId: handover.id,
        revision: handover.revision,
      });
      setNotice(`Revision ${handover.revision} reviewed.`);
    } catch (cause) {
      setError(handoverError(cause));
      handleConflict(cause);
    }
  }

  async function completeHandover() {
    if (!canFinalize) return;
    setError(null);
    setNotice(null);
    try {
      const receipt = await complete.mutateAsync({
        handoverId: handover.id,
        reviewedRevision: handover.revision,
      });
      onCompleted(receipt);
    } catch (cause) {
      setError(handoverError(cause));
      handleConflict(cause);
    }
  }

  async function cancelDraft() {
    if (cancel.isPending) return;
    setCancelError(null);
    if (!cancelReason.trim()) {
      setCancelError("Record why this handover is being cancelled.");
      return;
    }
    try {
      await cancel.mutateAsync({
        handoverId: handover.id,
        reason: cancelReason.trim(),
      });
      setCancelOpen(false);
      setCancelReason("");
      refreshChecks();
    } catch (cause) {
      setCancelError(handoverError(cause));
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <section aria-labelledby="handover-buyer-title">
        <h3 id="handover-buyer-title" className="text-sm font-semibold text-ink">
          Buyer
        </h3>
        <div className="mt-2">
          <BuyerIdentity buyer={handover.buyer} />
        </div>
      </section>

      <section aria-labelledby="handover-date-title">
        <h3 id="handover-date-title" className="text-sm font-semibold text-ink">
          Sale and mileage
        </h3>
        <div className="mt-2 grid gap-3 sm:grid-cols-2">
          <Input
            label="Sale date"
            type="date"
            value={saleDate}
            max={serverToday()}
            disabled={update.isPending}
            onChange={(event) => {
              setSaleDate(event.target.value);
              setNotice(null);
              setError(null);
            }}
          />
          <Input
            label="Handover mileage (km)"
            type="number"
            min={0}
            step={1}
            inputMode="numeric"
            value={mileage}
            disabled={update.isPending}
            hint={`Last recorded: ${vehicle.mileage.toLocaleString(undefined, { maximumFractionDigits: 0 })} km`}
            onChange={(event) => {
              setMileage(event.target.value);
              setNotice(null);
              setError(null);
            }}
          />
        </div>
      </section>

      <section aria-labelledby="handover-plan-title">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <h3 id="handover-plan-title" className="text-sm font-semibold text-ink">
              Maintenance plan for the buyer
            </h3>
            <p className="mt-1 text-xs text-ink-caption">
              The buyer receives an independent, editable copy. Showroom plan
              changes after completion do not propagate.
            </p>
          </div>
        </div>
        <div className="mt-3">
          <HandoverPlanEditor
            rows={rows}
            onChange={(next) => {
              setRows(next);
              setNotice(null);
              setError(null);
            }}
            disabled={update.isPending}
          />
        </div>
      </section>

      <section aria-labelledby="handover-warranty-title">
        <h3 id="handover-warranty-title" className="text-sm font-semibold text-ink">
          Warranty
        </h3>
        <p className="mt-1 text-xs text-ink-caption">
          Make an explicit choice. Completion is blocked while warranty is
          undecided.
        </p>
        <div className="mt-3 flex flex-col gap-2">
          <label className="flex items-start gap-2 rounded-md border border-line-subtle bg-card px-3 py-2 text-sm text-ink">
            <input
              type="radio"
              name={`warranty-${handover.id}`}
              className="mt-0.5"
              checked={warrantyChoice === "none"}
              disabled={update.isPending}
              onChange={() => {
                setWarrantyChoice("none");
                setNotice(null);
              }}
            />
            <span>
              No warranty
              <span className="mt-0.5 block text-xs text-ink-caption">
                The buyer receives no warranty instance for this handover.
              </span>
            </span>
          </label>
          <label className="flex items-start gap-2 rounded-md border border-line-subtle bg-card px-3 py-2 text-sm text-ink">
            <input
              type="radio"
              name={`warranty-${handover.id}`}
              className="mt-0.5"
              checked={warrantyChoice === "template"}
              disabled={update.isPending}
              onChange={() => {
                setWarrantyChoice("template");
                setNotice(null);
              }}
            />
            <span>
              Reviewed warranty terms
              <span className="mt-0.5 block text-xs text-ink-caption">
                The selected terms and approved workshops are frozen when the
                draft is saved.
              </span>
            </span>
          </label>
        </div>

        {warrantyChoice === "template" ? (
          <div className="mt-3 flex flex-col gap-3">
            {templates.isLoading ? (
              <Skeleton className="h-11 w-full" />
            ) : templates.isError ? (
              <p role="alert" className="text-sm text-danger">
                Could not load warranty templates.{" "}
                <button
                  type="button"
                  className="underline"
                  onClick={() => void templates.refetch()}
                >
                  Retry
                </button>
              </p>
            ) : (templates.data?.items.length ?? 0) === 0 ? (
              <p className="text-sm text-ink-caption">
                No warranty templates exist yet.{" "}
                <Link href="/warranty-templates" className="underline">
                  Create one
                </Link>{" "}
                or choose No warranty.
              </p>
            ) : (
              <Select
                label="Warranty template"
                placeholder="Choose reviewed terms"
                value={warrantyTemplateId}
                options={(templates.data?.items ?? []).map((template) => ({
                  value: template.id,
                  label: `${template.name} \u00b7 ${template.duration_years} yr / ${template.mileage_limit_km.toLocaleString()} km`,
                }))}
                disabled={update.isPending}
                onChange={(value) => {
                  setWarrantyTemplateId(value);
                  setNotice(null);
                }}
              />
            )}
          </div>
        ) : null}

        {handover.warranty ? (
          <div className="mt-3 rounded-md border border-line-subtle bg-card p-4">
            <p className="text-sm font-medium text-ink">
              Frozen terms: {handover.warranty.name}
            </p>
            <dl className="mt-2 grid gap-x-4 gap-y-1 text-xs text-ink-caption sm:grid-cols-2">
              <div className="flex gap-2">
                <dt>Duration</dt>
                <dd className="font-mono text-ink-muted">
                  {handover.warranty.duration_years} years
                </dd>
              </div>
              <div className="flex gap-2">
                <dt>Mileage limit</dt>
                <dd className="font-mono text-ink-muted">
                  {handover.warranty.mileage_limit_km.toLocaleString()} km
                </dd>
              </div>
            </dl>
            {handover.warranty.coverage_categories.length ? (
              <p className="mt-2 text-xs text-ink-caption">
                Coverage: {handover.warranty.coverage_categories.join(", ")}
              </p>
            ) : null}
            {handover.warranty.exclusions ? (
              <p className="mt-1 text-xs text-ink-caption">
                Exclusions: {handover.warranty.exclusions}
              </p>
            ) : null}
            {handover.warranty.approved_workshops.length ? (
              <p className="mt-1 text-xs text-ink-caption">
                Approved workshops:{" "}
                {handover.warranty.approved_workshops
                  .map((workshop) => workshop.name)
                  .join(", ")}
              </p>
            ) : null}
          </div>
        ) : null}
      </section>

      <section aria-labelledby="handover-readiness-title">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h3
            id="handover-readiness-title"
            className="text-sm font-semibold text-ink"
          >
            Readiness
          </h3>
          <Button type="button" variant="ghost" size="sm" onClick={refreshChecks}>
            Refresh checks
          </Button>
        </div>

        {dirty ? (
          <div className="mt-2 rounded-md bg-warning-dim px-3 py-2 text-sm text-warning">
            <p className="font-medium">Unsaved changes</p>
            <p className="mt-0.5 text-xs">
              Saved readiness checks below do not include these edits. Save the
              draft and review again before completing.
            </p>
            {localIssues.length ? (
              <ul className="mt-2 list-disc space-y-1 pl-5 text-xs">
                {localIssues.map((issue) => (
                  <li key={issue}>{issue}</li>
                ))}
              </ul>
            ) : null}
          </div>
        ) : serverIssues.length ? (
          <ul className="mt-2 list-disc space-y-2 rounded-md bg-warning-dim px-5 py-3 text-sm text-warning">
            {serverIssues.map((issue) => (
              <li key={issue.code}>
                <span>{issue.message}</span>
                {issue.details?.work_order_ids?.length ? (
                  <span className="mt-1 flex flex-wrap gap-2 text-xs">
                    {issue.details.work_order_ids.map((id) => (
                      <Link
                        key={id}
                        href={`/work-orders#order-${id}`}
                        className="font-mono underline"
                      >
                        {id.slice(0, 8)}
                      </Link>
                    ))}
                  </span>
                ) : null}
              </li>
            ))}
          </ul>
        ) : (
          <p className="mt-2 text-sm text-ink-caption">
            No blocking issues. Review this revision to authorize completion.
          </p>
        )}

        {reviewed ? (
          <p className="mt-3 text-sm text-success">
            Revision {handover.reviewed_revision} reviewed
            {handover.reviewed_at
              ? ` \u00b7 ${formatDateTime(handover.reviewed_at)}`
              : ""}
            .
          </p>
        ) : null}

        <div className="mt-4 flex flex-wrap gap-2">
          <Button
            type="button"
            variant="secondary"
            onClick={() => void saveDraft()}
            disabled={!dirty || update.isPending}
          >
            {update.isPending ? "Saving..." : "Save draft"}
          </Button>
          <Button
            type="button"
            onClick={() => void reviewDraft()}
            disabled={!canReview}
          >
            {review.isPending ? "Reviewing..." : "Review revision"}
          </Button>
          <Button
            type="button"
            variant="destructive"
            onClick={() => {
              setCancelError(null);
              setCancelOpen(true);
            }}
            disabled={cancel.isPending}
          >
            Cancel draft
          </Button>
        </div>
        {!dirty && !reviewed && !canReview && !review.isPending ? (
          <p className="mt-2 text-xs text-ink-caption">
            Resolve blocking issues before reviewing.
          </p>
        ) : null}
        {dirty ? (
          <p className="mt-2 text-xs text-ink-caption">
            Save the draft to refresh readiness checks and allow review.
          </p>
        ) : null}
      </section>

      <section aria-labelledby="handover-summary-title">
        <h3 id="handover-summary-title" className="text-sm font-semibold text-ink">
          Review summary
        </h3>
        <dl className="mt-2 grid gap-3 rounded-md border border-line-subtle bg-card p-4 text-sm sm:grid-cols-2">
          <div>
            <dt className="text-xs text-ink-caption">Buyer</dt>
            <dd className="mt-0.5 text-ink">{buyerLabel(handover.buyer)}</dd>
            <dd className="text-xs text-ink-caption">
              {handover.buyer.email_masked ?? "Email unavailable"} \u00b7{" "}
              <span className="font-mono">{handover.buyer.user_id}</span>
            </dd>
          </div>
          <div>
            <dt className="text-xs text-ink-caption">Vehicle</dt>
            <dd className="mt-0.5 text-ink">
              {vehicle.year} {vehicle.make} {vehicle.model}
            </dd>
            <dd className="text-xs text-ink-caption">
              <span className="font-mono">{vehicle.license_plate}</span> \u00b7{" "}
              <span className="font-mono">{vehicle.vin}</span>
            </dd>
          </div>
          <div>
            <dt className="text-xs text-ink-caption">Sale date</dt>
            <dd className="mt-0.5 font-mono text-ink">
              {saleDate ? formatDate(saleDate) : "Not set"}
            </dd>
          </div>
          <div>
            <dt className="text-xs text-ink-caption">Handover mileage</dt>
            <dd className="mt-0.5 font-mono text-ink">
              {mileage.trim()
                ? `${Number(mileage).toLocaleString(undefined, { maximumFractionDigits: 0 })} km`
                : "Not set"}
            </dd>
          </div>
          <div className="sm:col-span-2">
            <dt className="text-xs text-ink-caption">Warranty</dt>
            <dd className="mt-0.5 text-ink">
              {warrantyChoice === "template"
                ? handover.warranty?.name ?? "Reviewed terms selected"
                : warrantyChoice === "none"
                  ? "No warranty"
                  : "Not chosen"}
            </dd>
          </div>
          <div className="sm:col-span-2">
            <dt className="text-xs text-ink-caption">Maintenance plan</dt>
            <dd className="mt-1">
              <PlanSummary plan={planItemsFromRows(rows)} />
            </dd>
          </div>
        </dl>
      </section>

      <section aria-labelledby="handover-finalize-title">
        <h3 id="handover-finalize-title" className="text-sm font-semibold text-ink">
          Finalize
        </h3>
        {canComplete ? (
          <>
            <label className="mt-2 flex items-start gap-2 text-sm text-ink">
              <input
                type="checkbox"
                className="mt-0.5"
                checked={acknowledged}
                onChange={(event) => setAcknowledged(event.target.checked)}
              />
              <span>
                I checked the recipient and vehicle details with the buyer and
                understand that a completed handover can only be corrected by
                platform support.
              </span>
            </label>
            <div className="mt-3">
              <Button
                type="button"
                onClick={() => void completeHandover()}
                disabled={!canFinalize}
              >
                {complete.isPending ? "Completing..." : "Complete handover"}
              </Button>
            </div>
            {!reviewed ? (
              <p className="mt-2 text-xs text-ink-caption">
                Review the current revision before completing.
              </p>
            ) : dirty ? (
              <p className="mt-2 text-xs text-ink-caption">
                Save your changes and review the new revision before completing.
              </p>
            ) : !acknowledged ? (
              <p className="mt-2 text-xs text-ink-caption">
                Confirm the final check to enable completion.
              </p>
            ) : null}
          </>
        ) : (
          <p className="mt-2 text-sm text-ink-caption">
            A manager with handover completion permission or an organization
            admin must finalize this handover.
          </p>
        )}
      </section>

      {notice ? (
        <p role="status" className="rounded-md bg-success-dim px-3 py-2 text-sm text-success">
          {notice}
        </p>
      ) : null}
      {error ? (
        <p role="alert" className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">
          {error}
        </p>
      ) : null}

      <Modal
        open={cancelOpen}
        onClose={() => {
          if (!cancel.isPending) setCancelOpen(false);
        }}
        title="Cancel handover draft"
        confirmLabel="Cancel draft"
        destructive
        loading={cancel.isPending}
        onSubmit={() => void cancelDraft()}
      >
        <div className="flex flex-col gap-3">
          <p>
            The vehicle stays reserved in the showroom. A new draft can be
            started later.
          </p>
          <label className="flex flex-col gap-1.5 text-xs font-medium text-ink-caption">
            Reason
            <textarea
              className="min-h-24 rounded-md border border-line-strong bg-field p-3 text-sm text-ink focus-visible:outline-2 focus-visible:outline-focus"
              rows={3}
              maxLength={1000}
              value={cancelReason}
              onChange={(event) => {
                setCancelReason(event.target.value);
                setCancelError(null);
              }}
            />
          </label>
          {cancelError ? (
            <p role="alert" className="text-sm text-danger">
              {cancelError}
            </p>
          ) : null}
        </div>
      </Modal>
    </div>
  );
}

// \u2500\u2500\u2500 Completed receipt \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

function HandoverCompleted({
  detail,
  receipt,
  vehicle,
}: {
  detail: VehicleHandoverDetail | null;
  receipt: HandoverCompletion | null;
  vehicle: FleetVehicle;
}) {
  const result = receipt ?? (detail?.result as HandoverCompletion | null) ?? null;
  const buyer = detail?.buyer;
  const saleDate = result?.sale_date ?? detail?.sale_date ?? null;
  const mileage = result?.current_mileage_km ?? detail?.current_mileage_km ?? null;
  const completedAt = result?.completed_at ?? detail?.completed_at ?? null;
  const planCount = result?.plan_item_ids?.length ?? detail?.plan.length ?? 0;
  const warranty =
    result?.warranty_instance_id ?? detail?.warranty_template_id ?? null;

  return (
    <div className="flex flex-col gap-4">
      <div className="rounded-md bg-success-dim px-3 py-2 text-sm text-success">
        <p className="font-medium">Handover complete</p>
        <p className="mt-0.5 text-xs">
          Ownership moved to the buyer and the showroom kept its historical
          records.
          {receipt?.idempotent
            ? " This was a repeated request; no second transfer was created."
            : ""}
        </p>
      </div>

      <dl className="grid gap-3 rounded-md border border-line-subtle bg-card p-4 text-sm sm:grid-cols-2">
        <div>
          <dt className="text-xs text-ink-caption">Vehicle</dt>
          <dd className="mt-0.5 text-ink">
            {vehicle.year} {vehicle.make} {vehicle.model} \u00b7{" "}
            <span className="font-mono">{vehicle.license_plate}</span>
          </dd>
        </div>
        <div>
          <dt className="text-xs text-ink-caption">Buyer</dt>
          <dd className="mt-0.5 text-ink">
            {buyer ? buyerLabel(buyer) : result?.buyer_user_id ?? "\u2014"}
          </dd>
          {buyer?.email_masked ? (
            <dd className="text-xs text-ink-caption">{buyer.email_masked}</dd>
          ) : null}
        </div>
        <div>
          <dt className="text-xs text-ink-caption">Sale date</dt>
          <dd className="mt-0.5 font-mono text-ink">
            {saleDate ? formatDate(saleDate) : "\u2014"}
          </dd>
        </div>
        <div>
          <dt className="text-xs text-ink-caption">Handover mileage</dt>
          <dd className="mt-0.5 font-mono text-ink">
            {mileage == null
              ? "\u2014"
              : `${mileage.toLocaleString(undefined, { maximumFractionDigits: 0 })} km`}
          </dd>
        </div>
        <div>
          <dt className="text-xs text-ink-caption">Buyer plan items</dt>
          <dd className="mt-0.5 font-mono text-ink">{planCount}</dd>
        </div>
        <div>
          <dt className="text-xs text-ink-caption">Warranty</dt>
          <dd className="mt-0.5 text-ink">
            {warranty ? "Warranty instance created" : "No warranty"}
          </dd>
        </div>
        <div className="sm:col-span-2">
          <dt className="text-xs text-ink-caption">Completed</dt>
          <dd className="mt-0.5 font-mono text-ink">
            {completedAt ? formatDateTime(completedAt) : "\u2014"}
          </dd>
        </div>
      </dl>

      {receipt?.delivery ? (
        <p className="text-xs text-ink-caption">
          Buyer delivery events: {receipt.delivery.delivered} delivered
          {receipt.delivery.queued ? `, ${receipt.delivery.queued} queued` : ""}.
        </p>
      ) : null}

      <div className="flex flex-wrap gap-2">
        <Link
          href="/transferred"
          className="inline-flex h-11 items-center rounded-md border border-line-strong bg-card px-5 font-display text-sm font-semibold text-ink transition-colors hover:bg-skeleton"
        >
          View transfer audit
        </Link>
        <Link
          href="/vehicles"
          className="inline-flex h-11 items-center rounded-md border border-line-strong bg-card px-5 font-display text-sm font-semibold text-ink transition-colors hover:bg-skeleton"
        >
          Back to inventory
        </Link>
      </div>
    </div>
  );
}

// \u2500\u2500\u2500 Panel \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

export function HandoverPanel({
  orgId,
  vehicle,
  planItems,
  canManage,
}: {
  orgId: string | null;
  vehicle: FleetVehicle;
  planItems: VehiclePlanItem[];
  canManage: boolean;
}) {
  const { user } = useSession();
  const role = useOrgRole();
  const queryClient = useQueryClient();
  const handovers = useVehicleHandovers(orgId, canManage ? vehicle.id : null);
  const latest = handovers.data?.items[0] ?? null;
  const detail = useHandover(orgId, latest?.id ?? null);
  const members = useMembers(orgId, canManage);
  const ownMembership = members.data?.items.find(
    (member) => member.user_id === user?.id,
  );
  const canComplete =
    role === "org_admin" ||
    (role === "org_manager" && ownMembership?.can_complete_handover === true);
  const [receipt, setReceipt] = useState<HandoverCompletion | null>(null);

  if (!canManage) return null;

  const loading =
    handovers.isLoading || (latest !== null && detail.isLoading);
  const activeDetail = detail.data ?? null;
  const hasOpenHandover =
    latest?.status === "draft" ||
    activeDetail?.status === "draft" ||
    activeDetail?.status === "completed" ||
    receipt !== null;

  // A showroom vehicle only exposes handover preparation while reserved, but an
  // existing draft or completed receipt must stay reachable so staff can cancel
  // it or read the result after eligibility changes.
  if (vehicle.status !== "reserved" && !hasOpenHandover) return null;

  const status = receipt
    ? "completed"
    : activeDetail?.status ?? latest?.status ?? null;

  let content: React.ReactNode;
  if (loading) {
    content = <Skeleton className="h-32 w-full" />;
  } else if (receipt || activeDetail?.status === "completed") {
    content = (
      <HandoverCompleted
        detail={activeDetail}
        receipt={receipt}
        vehicle={vehicle}
      />
    );
  } else if (activeDetail?.status === "draft") {
    content = (
      <HandoverDraft
        orgId={orgId}
        vehicle={vehicle}
        handover={activeDetail}
        canComplete={canComplete}
        onCompleted={setReceipt}
      />
    );
  } else {
    content = (
      <div className="flex flex-col gap-4">
        {activeDetail?.status === "cancelled" ? (
          <div className="rounded-md bg-panel px-3 py-2 text-sm text-ink-caption">
            <p className="font-medium text-ink">Previous handover cancelled</p>
            <p className="mt-0.5 text-xs">
              {activeDetail.cancellation_reason ?? "No reason recorded."}
              {activeDetail.cancelled_at
                ? ` \u00b7 ${formatDateTime(activeDetail.cancelled_at)}`
                : ""}
            </p>
          </div>
        ) : null}
        <StartHandover orgId={orgId} vehicle={vehicle} planItems={planItems} />
      </div>
    );
  }

  return (
    <section
      aria-labelledby="handover-title"
      className="rounded-lg border border-line-subtle bg-panel p-5"
    >
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2
            id="handover-title"
            className="font-display text-base font-semibold text-ink"
          >
            Buyer handover
          </h2>
          <p className="mt-1 max-w-2xl text-sm text-ink-caption">
            Prepare the buyer, reviewed maintenance plan, and warranty for this
            reserved showroom vehicle. Completing the handover moves ownership
            to the buyer\u2019s personal account.
          </p>
        </div>
        <HandoverHeader status={status} revision={activeDetail?.revision} />
      </div>
      {vehicle.status !== "reserved" && activeDetail?.status === "draft" ? (
        <p
          role="alert"
          className="mt-4 rounded-md bg-warning-dim px-3 py-2 text-sm text-warning"
        >
          This vehicle is no longer Reserved, so the draft cannot be reviewed or
          completed. Return it to Reserved and review again, or cancel the draft.
        </p>
      ) : null}
      {detail.isError ? (
        <p role="alert" className="mt-4 text-sm text-danger">
          Could not load the handover.{" "}
          <button
            type="button"
            className="underline"
            onClick={() => {
              void queryClient.invalidateQueries({
                queryKey: ["fleet", "handovers", orgId, vehicle.id],
              });
              if (latest?.id) {
                void queryClient.invalidateQueries({
                  queryKey: ["fleet", "handover", orgId, latest.id],
                });
              }
            }}
          >
            Retry
          </button>
        </p>
      ) : (
        <div className="mt-5">{content}</div>
      )}
    </section>
  );
}
