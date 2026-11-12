"use client";

import { Button } from "@dco/ui/components/button";
import { Input } from "@dco/ui/components/input";
import type { HandoverPlanItem } from "@/lib/api/types";

export type PlanDraftRow = {
  key: string;
  name: string;
  next_due_on: string;
  next_due_mileage: string;
  initial_service_required: boolean;
  time_count: string;
  time_unit: "days" | "months" | "years";
  interval_days: number | null;
  interval_distance: string;
  warning_days: number | null;
  warning_distance: number | null;
  notes: string;
};

function newKey(): string {
  return globalThis.crypto?.randomUUID?.() ?? Math.random().toString(36).slice(2);
}

export function newPlanRow(name = ""): PlanDraftRow {
  return {
    key: newKey(),
    name,
    next_due_on: "",
    next_due_mileage: "",
    initial_service_required: false,
    time_count: "",
    time_unit: "months",
    interval_days: null,
    interval_distance: "",
    warning_days: null,
    warning_distance: null,
    notes: "",
  };
}

export function planRowsFromItems(items: HandoverPlanItem[]): PlanDraftRow[] {
  return items.map((item) => ({
    key: newKey(),
    name: item.name ?? "",
    next_due_on: item.next_due_on ?? "",
    next_due_mileage:
      item.next_due_mileage == null ? "" : String(item.next_due_mileage),
    initial_service_required: item.initial_service_required ?? false,
    time_count: item.time_count == null ? "" : String(item.time_count),
    time_unit: item.time_unit ?? "months",
    interval_days: item.interval_days ?? null,
    interval_distance:
      item.interval_distance == null ? "" : String(item.interval_distance),
    // Preserve the showroom's reminder lead times; new rows inherit the
    // buyer's own notification defaults instead of inventing thresholds.
    warning_days: item.warning_days ?? null,
    warning_distance: item.warning_distance ?? null,
    notes: item.notes ?? "",
  }));
}

function numberOrNull(value: string): number | null {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : null;
}

export function planItemsFromRows(rows: PlanDraftRow[]): HandoverPlanItem[] {
  return rows.map((row) => {
    const timeCount = numberOrNull(row.time_count);
    const intervalDistance = numberOrNull(row.interval_distance);
    return {
      name: row.name.trim(),
      interval_days: timeCount == null ? row.interval_days : null,
      time_count: timeCount,
      time_unit: timeCount == null ? null : row.time_unit,
      warning_days: row.warning_days,
      warning_distance: row.warning_distance,
      interval_distance: intervalDistance,
      next_due_on: row.next_due_on || null,
      next_due_mileage: numberOrNull(row.next_due_mileage),
      initial_service_required: row.initial_service_required,
      notes: row.notes.trim() || null,
    };
  });
}

export function planRowIssue(row: PlanDraftRow): string | null {
  if (!row.name.trim()) return "Enter a service name.";
  const timeCount = numberOrNull(row.time_count);
  const intervalDistance = numberOrNull(row.interval_distance);
  if (
    row.time_count.trim() &&
    (timeCount == null || !Number.isInteger(timeCount) || timeCount < 1)
  ) {
    return "Repeat time must be a whole number of at least 1.";
  }
  if (row.interval_distance.trim() && (intervalDistance == null || intervalDistance <= 0)) {
    return "Repeat distance must be greater than zero.";
  }
  if (row.next_due_mileage.trim()) {
    const dueMileage = numberOrNull(row.next_due_mileage);
    if (dueMileage == null || dueMileage < 0) {
      return "Due odometer must be zero or greater.";
    }
  }
  if (row.initial_service_required) return null;
  const hasDate = Boolean(row.next_due_on);
  const hasMileage = Boolean(row.next_due_mileage.trim());
  if (!hasDate && !hasMileage) {
    return "Set a due date, a due odometer, or mark the baseline unknown.";
  }
  if ((timeCount != null || row.interval_days != null) && !hasDate) {
    return "Set a first due date for the repeat interval.";
  }
  if (intervalDistance != null && !hasMileage) {
    return "Set a first due odometer for the repeat distance.";
  }
  return null;
}

export function planIssues(rows: PlanDraftRow[]): string[] {
  if (rows.length === 0) {
    return ["Add at least one maintenance plan item."];
  }
  return rows.flatMap((row, index) => {
    const issue = planRowIssue(row);
    return issue ? [`Item ${index + 1}: ${issue}`] : [];
  });
}

/** Type and length errors the API rejects outright, unlike readiness gaps. */
export function planSaveIssues(rows: PlanDraftRow[]): string[] {
  return rows.flatMap((row, index) => {
    const prefix = `Item ${index + 1}: `;
    const issues: string[] = [];
    if (!row.name.trim()) issues.push(`${prefix}enter a service name.`);
    if (row.name.trim().length > 100) {
      issues.push(`${prefix}service name must be 100 characters or fewer.`);
    }
    if (row.time_count.trim()) {
      const count = numberOrNull(row.time_count);
      if (count == null || !Number.isInteger(count) || count < 1) {
        issues.push(`${prefix}repeat time must be a whole number of at least 1.`);
      }
    }
    if (row.interval_distance.trim()) {
      const distance = numberOrNull(row.interval_distance);
      if (distance == null || distance <= 0) {
        issues.push(`${prefix}repeat distance must be greater than zero.`);
      }
    }
    if (row.next_due_mileage.trim()) {
      const due = numberOrNull(row.next_due_mileage);
      if (due == null || due < 0) {
        issues.push(`${prefix}due odometer must be zero or greater.`);
      }
    }
    return issues;
  });
}

export function HandoverPlanEditor({
  rows,
  onChange,
  disabled = false,
}: {
  rows: PlanDraftRow[];
  onChange: (rows: PlanDraftRow[]) => void;
  disabled?: boolean;
}) {
  function update(key: string, patch: Partial<PlanDraftRow>) {
    onChange(rows.map((row) => (row.key === key ? { ...row, ...patch } : row)));
  }

  return (
    <div className="flex flex-col gap-4">
      {rows.length === 0 ? (
        <p className="rounded-md border border-dashed border-line-strong px-4 py-5 text-sm text-ink-caption">
          No maintenance items yet. Add the services the buyer should track.
        </p>
      ) : null}

      {rows.map((row, index) => {
        const issue = planRowIssue(row);
        return (
          <fieldset
            key={row.key}
            disabled={disabled}
            className="rounded-md border border-line-subtle bg-panel p-4"
          >
            <legend className="px-1 text-xs font-medium text-ink-caption">
              Plan item {index + 1}
            </legend>
            <div className="flex flex-wrap items-end gap-3">
              <div className="min-w-48 flex-1">
                <Input
                  label="Service"
                  required
                  maxLength={100}
                  value={row.name}
                  onChange={(event) => update(row.key, { name: event.target.value })}
                />
              </div>
              <Button
                type="button"
                size="sm"
                variant="destructive"
                className="mb-0.5"
                onClick={() => onChange(rows.filter((item) => item.key !== row.key))}
                disabled={disabled}
              >
                Remove
              </Button>
            </div>

            <div className="mt-3 grid gap-3 sm:grid-cols-2">
              <Input
                label="Next due date"
                type="date"
                value={row.next_due_on}
                onChange={(event) => update(row.key, { next_due_on: event.target.value })}
              />
              <Input
                label="Next due odometer (km)"
                type="number"
                min={0}
                step={1}
                inputMode="numeric"
                value={row.next_due_mileage}
                onChange={(event) =>
                  update(row.key, { next_due_mileage: event.target.value })
                }
              />
            </div>

            <label className="mt-3 flex items-start gap-2 text-sm text-ink">
              <input
                type="checkbox"
                className="mt-0.5"
                checked={row.initial_service_required}
                onChange={(event) =>
                  update(row.key, { initial_service_required: event.target.checked })
                }
              />
              <span>
                Initial service required
                <span className="mt-0.5 block text-xs text-ink-caption">
                  Use this when the real baseline is unknown. The buyer will see a
                  first-service reminder instead of a fabricated due target.
                </span>
              </span>
            </label>

            <div className="mt-3 grid gap-3 sm:grid-cols-3">
              <Input
                label="Repeat every"
                type="number"
                min={1}
                step={1}
                inputMode="numeric"
                value={row.time_count}
                onChange={(event) => update(row.key, { time_count: event.target.value })}
                hint="Optional"
              />
              <label className="flex flex-col gap-1.5 text-xs font-medium text-ink-caption">
                Time unit
                <select
                  className="h-11 rounded-md border border-line-strong bg-field px-3 text-sm text-ink focus-visible:outline-2 focus-visible:outline-focus"
                  value={row.time_unit}
                  onChange={(event) =>
                    update(row.key, {
                      time_unit: event.target.value as PlanDraftRow["time_unit"],
                    })
                  }
                  disabled={disabled}
                >
                  <option value="days">Days</option>
                  <option value="months">Months</option>
                  <option value="years">Years</option>
                </select>
              </label>
              <Input
                label="Repeat distance (km)"
                type="number"
                min={1}
                step={1}
                inputMode="numeric"
                value={row.interval_distance}
                onChange={(event) =>
                  update(row.key, { interval_distance: event.target.value })
                }
                hint="Optional"
              />
            </div>

            <label className="mt-3 flex flex-col gap-1.5 text-xs font-medium text-ink-caption">
              Notes for the buyer plan
              <textarea
                className="min-h-16 rounded-md border border-line-strong bg-field p-3 text-sm text-ink focus-visible:outline-2 focus-visible:outline-focus"
                rows={2}
                maxLength={4000}
                value={row.notes}
                onChange={(event) => update(row.key, { notes: event.target.value })}
                disabled={disabled}
              />
            </label>

            {issue ? (
              <p role="alert" className="mt-3 text-xs text-danger">
                {issue}
              </p>
            ) : null}
          </fieldset>
        );
      })}

      <div>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          onClick={() => onChange([...rows, newPlanRow()])}
          disabled={disabled}
        >
          Add plan item
        </Button>
      </div>
    </div>
  );
}
