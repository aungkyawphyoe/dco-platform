"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Card } from "@dco/ui/components/card";
import { Badge } from "@dco/ui/components/badge";
import { Button } from "@dco/ui/components/button";
import { Select } from "@dco/ui/components/select";
import { Modal } from "@dco/ui/components/modal";
import { Skeleton } from "@dco/ui/components/skeleton";
import { EmptyState } from "@dco/ui/components/empty-state";
import { DataPlate } from "@dco/ui/components/data-plate";
import { SectionHeading } from "@dco/ui/components/section-heading";
import {
  useAssignVehicleTemplate,
  useGenerateMaintenancePlan,
  useMaintenanceTemplates,
  useVehicleAnalytics,
  useVehiclePlanItems,
  useVehicleServiceRecords,
  useVehicles,
} from "@/lib/api/hooks";
import type {
  FleetVehicle,
  FuelType,
  MaintenanceTemplate,
  VehicleClass,
  VehiclePlanItem,
} from "@/lib/api/types";
import {
  fuelTypeOptions,
  lifecycleTemplateOptions,
  vehicleClassOptions,
} from "@/lib/api/types";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";
import { formatDate, money } from "@dco/ui/lib/format";

// ── Formatting ──────────────────────────────────────────────────────────────

function classLabel(value: string | null | undefined) {
  return vehicleClassOptions.find((o) => o.value === value)?.label ?? value ?? "";
}

function fuelLabel(value: string | null | undefined) {
  return fuelTypeOptions.find((o) => o.value === value)?.label ?? value ?? "";
}

function lifecycleLabel(value: string | null | undefined) {
  return lifecycleTemplateOptions.find((o) => o.value === value)?.label ?? value ?? "";
}

function vehicleStatusTone(status: string): "success" | "warning" | "danger" | "info" | "neutral" {
  if (["available", "in_service", "listed"].includes(status)) return "success";
  if (["maintenance", "inspection", "return", "reserved"].includes(status)) return "warning";
  if (["retired", "sold"].includes(status)) return "danger";
  return "info";
}

/// "15,000 km or 365 days" — the interval this row is checked on.
function intervalSummary(t: {
  interval_days?: number | null;
  interval_distance?: number | null;
}) {
  const parts: string[] = [];
  if (t.interval_distance) parts.push(`${t.interval_distance.toLocaleString()} km`);
  if (t.interval_days) parts.push(`${t.interval_days} ${t.interval_days === 1 ? "day" : "days"}`);
  return parts.length ? parts.join(" or ") : "no interval set";
}

// ── Due state ───────────────────────────────────────────────────────────────

type Tone = "danger" | "warning" | "success" | "neutral";

const toneBg: Record<Tone, string> = {
  danger: "bg-danger",
  warning: "bg-warning",
  success: "bg-success",
  neutral: "bg-line-strong",
};

function planDueTone(item: VehiclePlanItem, mileage: number): Tone {
  if (!item.enabled) return "neutral";
  const dueOn = item.next_due_on ? new Date(item.next_due_on) : null;
  const overdue =
    (dueOn !== null && dueOn.getTime() < Date.now()) ||
    (item.next_due_mileage !== null &&
      item.next_due_mileage !== undefined &&
      mileage >= item.next_due_mileage);
  if (overdue) return "danger";
  const soon =
    (dueOn !== null && dueOn.getTime() - Date.now() < 14 * 24 * 60 * 60 * 1000) ||
    (item.next_due_mileage !== null &&
      item.next_due_mileage !== undefined &&
      mileage >= item.next_due_mileage - 500);
  return soon ? "warning" : "success";
}

function planDueLabel(item: VehiclePlanItem, mileage: number): { label: string; tone: Tone } {
  const tone = planDueTone(item, mileage);
  const label =
    tone === "danger"
      ? "Overdue"
      : tone === "warning"
        ? "Due soon"
        : tone === "neutral"
          ? "Disabled"
          : "Scheduled";
  return { label, tone };
}

/// The template set for a class: enabled rows matching class + fuel and a
/// compatible lifecycle (NULL rows always match), deduped by name with the org
/// copy winning — mirrors the backend templateSetRows().
function templateSet(
  all: MaintenanceTemplate[],
  vehicle: FleetVehicle,
  cls: string,
): MaintenanceTemplate[] {
  const matching = all.filter(
    (t) =>
      t.enabled &&
      t.vehicle_class === cls &&
      t.fuel_types.includes(vehicle.fuel_type as FuelType) &&
      (!t.lifecycle_template || t.lifecycle_template === vehicle.lifecycle_template),
  );
  const byName = new Map<string, MaintenanceTemplate>();
  for (const t of matching) {
    const key = t.name.trim().toLowerCase();
    const current = byName.get(key);
    if (!current || (current.source === "global" && t.source === "org")) byName.set(key, t);
  }
  return [...byName.values()].sort(
    (a, b) => a.sort_order - b.sort_order || a.name.localeCompare(b.name),
  );
}

// ── Identity plate ──────────────────────────────────────────────────────────

function VehicleDataPlate({ vehicle }: { vehicle: FleetVehicle }) {
  return (
    <DataPlate
      fields={[
        { label: "VIN", value: vehicle.vin, mono: true },
        { label: "Class", value: classLabel(vehicle.vehicle_class ?? "car") },
        { label: "Fuel", value: fuelLabel(vehicle.fuel_type) },
        {
          label: "Odometer",
          value: `${vehicle.mileage.toLocaleString()} ${vehicle.mileage_unit ?? "km"}`,
          mono: true,
        },
        { label: "Lifecycle", value: lifecycleLabel(vehicle.lifecycle_template) },
        { label: "Revenue label", value: vehicle.revenue_label ?? "—" },
        { label: "Added", value: vehicle.added_at ? formatDate(vehicle.added_at) : "—" },
      ]}
    />
  );
}

// ── Instrument band: condition + cost ───────────────────────────────────────

function ConditionStrip({ items, mileage }: { items: VehiclePlanItem[]; mileage: number }) {
  const sorted = useMemo(() => {
    const rank: Record<Tone, number> = { danger: 0, warning: 1, success: 2, neutral: 3 };
    return [...items].sort((a, b) => rank[planDueTone(a, mileage)] - rank[planDueTone(b, mileage)]);
  }, [items, mileage]);

  const counts = useMemo(() => {
    const c: Record<Tone, number> = { danger: 0, warning: 0, success: 0, neutral: 0 };
    for (const item of items) c[planDueTone(item, mileage)] += 1;
    return c;
  }, [items, mileage]);

  const nextDue = useMemo(() => {
    const enabled = items.filter((i) => i.enabled);
    const withDate = enabled
      .filter((i) => i.next_due_on)
      .sort((a, b) => new Date(a.next_due_on as string).getTime() - new Date(b.next_due_on as string).getTime());
    if (withDate.length) {
      const upcoming = withDate.filter((i) => new Date(i.next_due_on as string).getTime() >= Date.now());
      const chosen = (upcoming.length ? upcoming : withDate)[0];
      return { name: chosen.name, when: formatDate(chosen.next_due_on as string) };
    }
    const withKm = enabled
      .filter((i) => i.next_due_mileage !== null && i.next_due_mileage !== undefined)
      .sort((a, b) => (a.next_due_mileage as number) - (b.next_due_mileage as number));
    if (withKm.length) {
      const upcoming = withKm.filter((i) => (i.next_due_mileage as number) >= mileage);
      const chosen = (upcoming.length ? upcoming : withKm)[0];
      return { name: chosen.name, when: `${(chosen.next_due_mileage as number).toLocaleString()} km` };
    }
    return null;
  }, [items, mileage]);

  if (items.length === 0) {
    return (
      <p className="mt-4 max-w-md text-sm text-ink-caption">
        No maintenance plan yet. Assign this vehicle&apos;s template set and generate the plan to
        start tracking due intervals.
      </p>
    );
  }

  const legend: { tone: Tone; label: string }[] = [
    { tone: "danger", label: "overdue" },
    { tone: "warning", label: "due soon" },
    { tone: "success", label: "scheduled" },
    { tone: "neutral", label: "disabled" },
  ];

  return (
    <>
      <div
        className="mt-4 flex items-end gap-1 overflow-x-auto border-b border-line-subtle pb-1"
        aria-hidden="true"
      >
        {sorted.map((item) => (
          <span
            key={item.id}
            title={`${item.name} — ${planDueLabel(item, mileage).label}`}
            className={`h-10 w-1.5 shrink-0 rounded-sm ${toneBg[planDueTone(item, mileage)]}`}
          />
        ))}
      </div>

      <div className="mt-4 flex flex-wrap gap-x-6 gap-y-2">
        {legend
          .filter((entry) => counts[entry.tone] > 0)
          .map((entry) => (
            <p key={entry.tone} className="flex items-center gap-2 text-sm text-ink-muted">
              <span className={`size-2 rounded-full ${toneBg[entry.tone]}`} />
              <span className="font-mono text-ink">{counts[entry.tone]}</span>
              {entry.label}
            </p>
          ))}
      </div>

      {nextDue ? (
        <p className="mt-4 text-sm text-ink-caption">
          Next due: <span className="text-ink">{nextDue.name}</span>{" "}
          <span className="font-mono text-ink-muted">{nextDue.when}</span>
        </p>
      ) : null}
    </>
  );
}

function CostPanel({
  analytics,
  isLoading,
}: {
  analytics: {
    tco: number;
    cost_per_km: number;
    total_km_driven: number;
    utilization_rate: number;
    maintenance_cost: number;
    fuel_cost: number;
    wear_cost: number;
  } | undefined;
  isLoading: boolean;
}) {
  if (isLoading) {
    return <Skeleton className="mt-4 h-24 w-full" />;
  }
  if (!analytics) {
    return (
      <p className="mt-4 max-w-md text-sm text-ink-caption">
        Cost analytics are visible to Org Admins and Managers.
      </p>
    );
  }

  const mix = [
    { label: "Maintenance", value: analytics.maintenance_cost ?? 0, color: "var(--chart-maintenance)" },
    { label: "Fuel", value: analytics.fuel_cost ?? 0, color: "var(--chart-fuel)" },
    { label: "Wear & parts", value: analytics.wear_cost ?? 0, color: "var(--chart-parts)" },
  ];
  const mixTotal = mix.reduce((sum, part) => sum + part.value, 0);

  const figures: { label: string; value: string }[] = [
    { label: "Cost / km", value: money(analytics.cost_per_km ?? 0, 3) },
    { label: "Distance", value: `${(analytics.total_km_driven ?? 0).toLocaleString()} km` },
    { label: "Utilization", value: `${analytics.utilization_rate ?? 0}%` },
  ];

  return (
    <>
      <p className="mt-3 font-mono text-3xl font-medium tracking-tight text-ink">
        {money(analytics.tco ?? 0, 0)}
      </p>
      <p className="mt-1 text-sm text-ink-caption">Total spend to date</p>

      <dl className="mt-5 grid grid-cols-3 gap-4">
        {figures.map((figure) => (
          <div key={figure.label}>
            <dt className="text-xs text-ink-caption">{figure.label}</dt>
            <dd className="mt-1 font-mono text-sm text-ink">{figure.value}</dd>
          </div>
        ))}
      </dl>

      {mixTotal > 0 ? (
        <div className="mt-5">
          <div className="flex h-2 overflow-hidden rounded-full bg-skeleton">
            {mix.map((part) => (
              <span
                key={part.label}
                title={part.label}
                style={{ width: `${(part.value / mixTotal) * 100}%`, background: part.color }}
              />
            ))}
          </div>
          <dl className="mt-2 flex flex-wrap gap-x-5 gap-y-1">
            {mix.map((part) => (
              <div key={part.label} className="flex items-center gap-1.5 text-xs text-ink-caption">
                <span className="size-2 rounded-full" style={{ background: part.color }} />
                <dt>{part.label}</dt>
                <dd className="font-mono text-ink-muted">{money(part.value, 0)}</dd>
              </div>
            ))}
          </dl>
        </div>
      ) : null}
    </>
  );
}

// ── Template set editor (setup + change) ────────────────────────────────────

function TemplateSetEditor({
  orgId,
  vehicle,
  templates,
  planItems,
  onDone,
}: {
  orgId: string | null;
  vehicle: FleetVehicle;
  templates: MaintenanceTemplate[];
  planItems: VehiclePlanItem[];
  onDone?: () => void;
}) {
  const assignTemplate = useAssignVehicleTemplate(orgId);
  const generatePlan = useGenerateMaintenancePlan(orgId);

  const vehicleClass = (vehicle.vehicle_class ?? "car") as VehicleClass;
  const assignedClass = vehicle.maintenance_template_class ?? null;

  const [selectedClass, setSelectedClass] = useState<string>(assignedClass ?? "");
  const [selectedItems, setSelectedItems] = useState<Set<string>>(new Set());
  const [actionError, setActionError] = useState<string | null>(null);
  const [confirmGenerate, setConfirmGenerate] = useState(false);
  const [generateResult, setGenerateResult] = useState<{ created: number; skipped: number } | null>(
    null,
  );

  const setForClass = useMemo(
    () => (cls: string) => templateSet(templates, vehicle, cls),
    [templates, vehicle],
  );

  const classOptions = useMemo(() => {
    const present = new Set(templates.filter((t) => t.enabled).map((t) => t.vehicle_class));
    return vehicleClassOptions
      .filter((o) => present.has(o.value))
      .map((o) => ({ ...o, count: setForClass(o.value).length }));
  }, [templates, setForClass]);

  const setItems = useMemo(() => setForClass(vehicleClass), [setForClass, vehicleClass]);

  const existingNames = useMemo(
    () => new Set(planItems.map((item) => item.name.trim().toLowerCase())),
    [planItems],
  );

  // Reset the checklist to "all checked" whenever the set or the plan changes.
  const checklistKey = `${setItems.map((i) => i.id).join(",")}|${[...existingNames]
    .sort()
    .join(",")}`;
  useEffect(() => {
    setSelectedItems(new Set(setItems.map((i) => i.id)));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [checklistKey]);

  useEffect(() => {
    setSelectedClass(assignedClass ?? "");
  }, [assignedClass]);

  const selectableSelected = setItems.filter(
    (item) => selectedItems.has(item.id) && !existingNames.has(item.name.trim().toLowerCase()),
  ).length;

  async function onAssign() {
    if (!selectedClass) return;
    setActionError(null);
    setGenerateResult(null);
    try {
      await assignTemplate.mutateAsync({
        vehicleId: vehicle.id,
        vehicleClass: selectedClass as VehicleClass,
      });
    } catch (error) {
      setActionError(error instanceof Error ? error.message : "Failed to assign template set");
    }
  }

  async function onClear() {
    setActionError(null);
    setGenerateResult(null);
    try {
      await assignTemplate.mutateAsync({ vehicleId: vehicle.id, vehicleClass: null });
    } catch (error) {
      setActionError(error instanceof Error ? error.message : "Failed to clear template set");
    }
  }

  async function onGenerate() {
    setActionError(null);
    try {
      const result = await generatePlan.mutateAsync({
        vehicleId: vehicle.id,
        itemIds: [...selectedItems],
      });
      setGenerateResult(result);
      setConfirmGenerate(false);
      onDone?.();
    } catch (error) {
      setActionError(error instanceof Error ? error.message : "Failed to generate plan");
      setConfirmGenerate(false);
    }
  }

  function toggleItem(id: string) {
    setSelectedItems((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  return (
    <div className="flex flex-col gap-5">
      <div>
        <div className="flex flex-wrap items-end gap-3">
          <Select
            label="Template set"
            options={classOptions.map((o) => ({
              value: o.value,
              label: `${o.label} (${o.count} ${o.count === 1 ? "item" : "items"})`,
              disabled: o.value !== vehicleClass,
            }))}
            placeholder="Choose a template set…"
            value={selectedClass}
            onChange={setSelectedClass}
            className="w-full sm:w-72"
          />
          <Button
            className="h-11"
            disabled={!selectedClass || selectedClass !== vehicleClass || assignTemplate.isPending}
            onClick={() => void onAssign()}
          >
            Assign
          </Button>
          {assignedClass ? (
            <Button
              variant="secondary"
              className="h-11"
              disabled={assignTemplate.isPending}
              onClick={() => void onClear()}
            >
              Clear
            </Button>
          ) : null}
        </div>
        <p className="mt-2 max-w-lg text-xs text-ink-caption">
          Only the {classLabel(vehicleClass)} set applies to this vehicle. Other vehicle classes are
          shown for reference and cannot be assigned here.
        </p>
      </div>

      {assignedClass ? (
        <div>
          <p className="text-sm font-medium text-ink">Items in this set</p>
          <p className="mt-0.5 text-xs text-ink-caption">
            Everything is selected by default. Clear a checkbox to skip that item for now.
          </p>
          {setItems.length === 0 ? (
            <p className="mt-3 text-sm text-ink-caption">
              No enabled catalog items match this vehicle&apos;s class, lifecycle, and fuel.
            </p>
          ) : (
            <ul className="mt-3 divide-y divide-line-subtle border-y border-line-subtle">
              {setItems.map((item) => {
                const already = existingNames.has(item.name.trim().toLowerCase());
                return (
                  <li key={item.id} className="flex items-center gap-3 py-2.5">
                    <input
                      type="checkbox"
                      aria-label={`Include ${item.name}`}
                      checked={selectedItems.has(item.id)}
                      disabled={already}
                      onChange={() => toggleItem(item.id)}
                      className="size-4 accent-[var(--accent)]"
                    />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm text-ink">{item.name}</p>
                      <p className="mt-0.5 text-xs text-ink-caption">{intervalSummary(item)}</p>
                    </div>
                    {already ? <Badge tone="neutral">Already in plan</Badge> : null}
                  </li>
                );
              })}
            </ul>
          )}
          <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
            <p className="text-xs text-ink-caption">
              <span className="font-mono text-ink">{selectableSelected}</span> selected and ready to
              add
            </p>
            <Button
              disabled={selectableSelected === 0 || generatePlan.isPending}
              onClick={() => setConfirmGenerate(true)}
            >
              Generate plan
            </Button>
          </div>
        </div>
      ) : null}

      {generateResult ? (
        <p className="rounded-md bg-success-dim px-3 py-2 text-sm text-success">
          {generateResult.created} item{generateResult.created === 1 ? "" : "s"} added,{" "}
          {generateResult.skipped} skipped because they were already in the plan.
        </p>
      ) : null}
      {actionError ? (
        <p className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">{actionError}</p>
      ) : null}

      <Modal
        open={confirmGenerate}
        onClose={() => setConfirmGenerate(false)}
        title="Generate maintenance plan"
        confirmLabel="Generate plan"
        loading={generatePlan.isPending}
        onSubmit={() => void onGenerate()}
      >
        <p>
          Add the {selectableSelected} selected item{selectableSelected === 1 ? "" : "s"} to this
          vehicle&apos;s plan? Items already in the plan are skipped, so this is safe to run again.
        </p>
      </Modal>
    </div>
  );
}

// ── Working surfaces ────────────────────────────────────────────────────────

function ServiceHistorySection({ orgId, vehicleId }: { orgId: string | null; vehicleId: string }) {
  const { data, isLoading } = useVehicleServiceRecords(orgId, vehicleId);
  const records = data?.items ?? [];

  return (
    <Card className="flex h-full flex-col">
      <SectionHeading title="Service history" count={records.length} />
      <div className="flex-1 p-5">
        {isLoading ? (
          <Skeleton className="h-24 w-full" />
        ) : records.length === 0 ? (
          <EmptyState
            title="No services logged yet"
            description="Entries appear here when a driver logs a service from the mobile app or your team records one in the portal."
          />
        ) : (
          <ul className="divide-y divide-line-subtle">
            {records.map((record) => (
              <li key={record.id} className="flex items-start justify-between gap-6 py-3 first:pt-0 last:pb-0">
                <div className="min-w-0">
                  <p className="text-sm font-medium text-ink">
                    {record.items.length
                      ? record.items.map((item) => item.name).join(", ")
                      : "Service"}
                  </p>
                  <p className="mt-1 text-xs text-ink-caption">
                    {formatDate(record.serviced_on)}
                    <span className="mx-1.5 text-ink-faint">/</span>
                    <span className="font-mono">{record.odometer.toLocaleString()} km</span>
                    {record.workshop_name ? (
                      <>
                        <span className="mx-1.5 text-ink-faint">/</span>
                        {record.workshop_name}
                      </>
                    ) : null}
                  </p>
                  {record.notes ? (
                    <p className="mt-1 line-clamp-2 text-xs text-ink-muted">{record.notes}</p>
                  ) : null}
                </div>
                <span className="shrink-0 font-mono text-sm text-ink">
                  {money(record.total_cost, 2)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </Card>
  );
}

function MaintenancePlanSection({
  orgId,
  vehicle,
  templates,
  planItems,
  canManage,
}: {
  orgId: string | null;
  vehicle: FleetVehicle;
  templates: MaintenanceTemplate[];
  planItems: VehiclePlanItem[];
  canManage: boolean;
}) {
  const [manageOpen, setManageOpen] = useState(false);
  const assignedClass = vehicle.maintenance_template_class ?? null;
  const assignedCount = assignedClass
    ? templateSet(templates, vehicle, assignedClass).length
    : 0;

  const sorted = [...planItems].sort((a, b) => {
    const aOverdue = planDueTone(a, vehicle.mileage) === "danger" ? 0 : 1;
    const bOverdue = planDueTone(b, vehicle.mileage) === "danger" ? 0 : 1;
    if (aOverdue !== bOverdue) return aOverdue - bOverdue;
    return a.name.localeCompare(b.name);
  });

  return (
    <>
      <Card className="flex h-full flex-col">
        <SectionHeading title="Maintenance plan" count={planItems.length}>
          <div className="flex items-center gap-2 text-xs">
            <span className="text-ink-caption">Template set</span>
            <span className="text-ink">
              {assignedClass ? `${classLabel(assignedClass)} (${assignedCount})` : "Not assigned"}
            </span>
            {canManage ? (
              <button
                type="button"
                onClick={() => setManageOpen(true)}
                className="font-display text-xs font-semibold text-gold hover:underline"
              >
                Change
              </button>
            ) : null}
          </div>
        </SectionHeading>

        <div className="flex-1 p-5">
          {planItems.length === 0 ? (
            <EmptyState
              title="No plan items yet"
              description={
                canManage
                  ? "Set up the maintenance template above, then generate the plan to fill this list."
                  : "Nothing has been generated yet. Maintenance setup requires the Org Admin or Manager role."
              }
            />
          ) : (
            <ul className="divide-y divide-line-subtle">
              {sorted.map((item) => {
                const due = planDueLabel(item, vehicle.mileage);
                const dueParts = [
                  item.next_due_on ? formatDate(item.next_due_on) : null,
                  item.next_due_mileage ? `${item.next_due_mileage.toLocaleString()} km` : null,
                ].filter(Boolean);
                return (
                  <li
                    key={item.id}
                    className="flex items-center justify-between gap-4 py-3 first:pt-0 last:pb-0"
                  >
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium text-ink">{item.name}</p>
                      <p className="mt-1 text-xs text-ink-caption">
                        {intervalSummary(item)}
                        {dueParts.length ? (
                          <>
                            <span className="mx-1.5 text-ink-faint">/</span>
                            Due {dueParts.join(" or ")}
                          </>
                        ) : null}
                      </p>
                    </div>
                    <Badge tone={due.tone}>{due.label}</Badge>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      </Card>

      <Modal
        open={manageOpen}
        onClose={() => setManageOpen(false)}
        title="Maintenance template set"
        confirmLabel="Done"
        onSubmit={() => setManageOpen(false)}
      >
        <div className="max-h-[60vh] overflow-y-auto pr-1">
          <TemplateSetEditor
            orgId={orgId}
            vehicle={vehicle}
            templates={templates}
            planItems={planItems}
          />
        </div>
      </Modal>
    </>
  );
}

// ── Page ────────────────────────────────────────────────────────────────────

export default function VehicleDetailPage() {
  const params = useParams<{ id: string }>();
  const vehicleId = params.id;
  const orgId = useOrgId();
  const role = useOrgRole();
  const canManage = role === "org_admin" || role === "org_manager";

  const { data: vehicles, isLoading } = useVehicles(orgId);
  const { data: templatesData } = useMaintenanceTemplates(orgId);
  const { data: planData } = useVehiclePlanItems(orgId, vehicleId);
  const { data: analytics, isLoading: analyticsLoading } = useVehicleAnalytics(orgId, vehicleId);

  const vehicle = vehicles?.items.find((v) => v.id === vehicleId);
  const templates = useMemo(() => templatesData?.items ?? [], [templatesData]);
  const planItems = useMemo(() => planData?.items ?? [], [planData]);

  if (isLoading) {
    return (
      <div className="flex flex-col gap-6">
        <Skeleton className="h-10 w-64" />
        <Skeleton className="h-20 w-full" />
        <Skeleton className="h-40 w-full" />
      </div>
    );
  }

  if (!vehicle) {
    return (
      <div className="flex flex-col gap-6">
        <header className="flex flex-col gap-4">
          <Link
            href="/vehicles"
            className="w-fit text-sm text-ink-caption transition-colors hover:text-ink"
          >
            Vehicle inventory
          </Link>
          <h1 className="font-display text-2xl font-semibold tracking-tight text-ink">
            Vehicle not found
          </h1>
        </header>
        <Card className="p-5">
          <p className="text-sm text-ink-caption">
            This vehicle is not in your organization inventory.
          </p>
        </Card>
      </div>
    );
  }

  const showSetup = canManage && planItems.length === 0;

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-col gap-4">
        <Link
          href="/vehicles"
          className="w-fit text-sm text-ink-caption transition-colors hover:text-ink"
        >
          Vehicle inventory
        </Link>
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <div className="flex flex-wrap items-center gap-3">
              <h1 className="font-display text-3xl font-semibold tracking-tight text-ink">
                {vehicle.name}
              </h1>
              <Badge tone={vehicleStatusTone(vehicle.status)}>{vehicle.status}</Badge>
            </div>
            <p className="mt-1.5 text-sm text-ink-caption">
              {vehicle.year} {vehicle.make} {vehicle.model}
              <span className="mx-2 text-ink-faint">/</span>
              <span className="font-mono text-ink-muted">{vehicle.license_plate}</span>
            </p>
          </div>
          {canManage ? (
            <Link
              href="/maintenance-templates"
              className="inline-flex h-9 items-center rounded-md border border-line-strong bg-card px-4 font-display text-sm font-semibold text-ink transition-colors hover:bg-skeleton"
            >
              Maintenance catalog
            </Link>
          ) : null}
        </div>
      </header>

      <VehicleDataPlate vehicle={vehicle} />

      {showSetup ? (
        <section className="rounded-lg border border-line-strong bg-card p-5 sm:p-6">
          <h2 className="font-display text-lg font-semibold text-ink">Set up maintenance</h2>
          <p className="mt-1 max-w-2xl text-sm text-ink-caption">
            Assign this vehicle&apos;s maintenance template set, choose the items it needs, and
            generate its first plan. You can change the set later from the maintenance plan.
          </p>
          <div className="mt-5">
            <TemplateSetEditor
              orgId={orgId}
              vehicle={vehicle}
              templates={templates}
              planItems={planItems}
            />
          </div>
        </section>
      ) : null}

      <section className="rounded-lg border border-line-subtle bg-panel">
        <div className="grid grid-cols-1 lg:grid-cols-[3fr_2fr] lg:divide-x lg:divide-line">
          <div className="p-5">
            <h2 className="font-display text-base font-semibold text-ink">Service condition</h2>
            <ConditionStrip items={planItems} mileage={vehicle.mileage} />
          </div>
          <div className="border-t border-line-subtle p-5 lg:border-t-0">
            <h2 className="font-display text-base font-semibold text-ink">Cost analytics</h2>
            <CostPanel analytics={analytics} isLoading={analyticsLoading} />
          </div>
        </div>
      </section>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-5">
        <div className="lg:col-span-3">
          <ServiceHistorySection orgId={orgId} vehicleId={vehicle.id} />
        </div>
        <div className="lg:col-span-2">
          <MaintenancePlanSection
            orgId={orgId}
            vehicle={vehicle}
            templates={templates}
            planItems={planItems}
            canManage={canManage}
          />
        </div>
      </div>
    </div>
  );
}
