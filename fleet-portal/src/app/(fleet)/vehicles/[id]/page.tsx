"use client";

import { useMemo, useState } from "react";
import { useParams } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { Modal } from "@/components/ui/modal";
import { Skeleton } from "@/components/ui/skeleton";
import {
  useAssignVehicleTemplate,
  useGenerateMaintenancePlan,
  useMaintenanceTemplates,
  useVehicleAnalytics,
  useVehiclePlanItems,
  useVehicleServiceRecords,
  useVehicles,
} from "@/lib/api/hooks";
import type { FleetVehicle, MaintenanceTemplate, VehiclePlanItem } from "@/lib/api/types";
import { vehicleClassOptions } from "@/lib/api/types";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";

function templateIntervals(template: MaintenanceTemplate) {
  const parts: string[] = [];
  if (template.interval_days) parts.push(`${template.interval_days} d`);
  if (template.interval_distance) parts.push(`${template.interval_distance.toLocaleString()} km`);
  return parts.length ? parts.join(" · ") : "no interval";
}

function VehicleTemplateCard({ orgId, vehicle }: { orgId: string | null; vehicle: FleetVehicle }) {
  const role = useOrgRole();
  const canManage = role === "org_admin" || role === "org_manager";

  const { data: templatesData } = useMaintenanceTemplates(orgId, {
    vehicle_class: vehicle.vehicle_class ?? "car",
    fuel_type: vehicle.fuel_type,
  });
  const assignTemplate = useAssignVehicleTemplate(orgId);
  const generatePlan = useGenerateMaintenancePlan(orgId);

  const [selected, setSelected] = useState("");
  const [actionError, setActionError] = useState<string | null>(null);
  const [confirmGenerate, setConfirmGenerate] = useState(false);
  const [generateResult, setGenerateResult] = useState<{ created: number; skipped: number } | null>(
    null,
  );

  // The assign set: enabled rows matching class + fuel (server-filtered) and
  // lifecycle (client-side, NULL rows always match), deduped by name with the
  // org copy winning — mirrors backend templateSetRows().
  const options = useMemo(() => {
    const matching = (templatesData?.items ?? []).filter(
      (t) =>
        t.enabled &&
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
  }, [templatesData, vehicle.lifecycle_template]);

  const assigned = vehicle.maintenance_template_id ?? null;
  const assignedTemplate = (templatesData?.items ?? []).find((t) => t.id === assigned) ?? null;

  async function onAssign() {
    if (!selected) return;
    setActionError(null);
    setGenerateResult(null);
    try {
      await assignTemplate.mutateAsync({ vehicleId: vehicle.id, templateId: selected });
    } catch (error) {
      setActionError(error instanceof Error ? error.message : "Failed to assign template");
    }
  }

  async function onClear() {
    setActionError(null);
    setGenerateResult(null);
    try {
      await assignTemplate.mutateAsync({ vehicleId: vehicle.id, templateId: null });
    } catch (error) {
      setActionError(error instanceof Error ? error.message : "Failed to clear template");
    }
  }

  async function onGenerate() {
    setActionError(null);
    try {
      const result = await generatePlan.mutateAsync(vehicle.id);
      setGenerateResult(result);
      setConfirmGenerate(false);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : "Failed to generate plan");
      setConfirmGenerate(false);
    }
  }

  return (
    <Card className="p-5">
      <div className="flex items-center justify-between gap-3">
        <h2 className="font-display text-base font-semibold text-ink">Maintenance template</h2>
        {assigned ? <Badge tone="success">Assigned</Badge> : <Badge tone="neutral">None</Badge>}
      </div>

      <dl className="mt-4 grid grid-cols-2 gap-y-3 text-sm">
        <dt className="text-ink-caption">Current template</dt>
        <dd className="text-ink">
          {assignedTemplate ? (
            <span className="inline-flex items-center gap-2">
              {assignedTemplate.name}
              <Badge tone={assignedTemplate.source === "org" ? "info" : "neutral"}>
                {assignedTemplate.source === "org" ? "Org copy" : "Global"}
              </Badge>
            </span>
          ) : assigned ? (
            <span className="text-ink-caption">Assigned template no longer exists</span>
          ) : (
            "—"
          )}
        </dd>
        <dt className="text-ink-caption">Class</dt>
        <dd className="text-ink">
          {vehicleClassOptions.find((o) => o.value === (vehicle.vehicle_class ?? "car"))?.label ??
            vehicle.vehicle_class ??
            "car"}
        </dd>
      </dl>

      {canManage ? (
        <div className="mt-4 flex flex-wrap items-end gap-3">
          <Select
            label="Template set"
            options={options.map((t) => ({
              value: t.id,
              label: `${t.name} · ${templateIntervals(t)}${t.source === "org" ? " · org copy" : ""}`,
            }))}
            placeholder={options.length ? "Choose a template…" : "No matching templates"}
            value={selected}
            onChange={setSelected}
            className="w-80"
          />
          <Button
            size="sm"
            className="h-11"
            disabled={!selected || assignTemplate.isPending}
            onClick={() => void onAssign()}
          >
            Assign
          </Button>
          {assigned ? (
            <Button
              size="sm"
              variant="secondary"
              className="h-11"
              disabled={assignTemplate.isPending}
              onClick={() => void onClear()}
            >
              Clear
            </Button>
          ) : null}
          <Button
            size="sm"
            variant="secondary"
            className="h-11"
            disabled={!assigned}
            onClick={() => setConfirmGenerate(true)}
          >
            Generate maintenance plan
          </Button>
        </div>
      ) : (
        <p className="mt-4 text-sm text-ink-caption">
          Assigning templates and generating plans requires the Org Admin or Manager role.
        </p>
      )}

      {generateResult ? (
        <p className="mt-3 rounded-md bg-success-dim px-3 py-2 text-sm text-success">
          Plan generated — {generateResult.created} new item{generateResult.created === 1 ? "" : "s"}{" "}
          created, {generateResult.skipped} skipped (already present).
        </p>
      ) : null}
      {actionError ? (
        <p className="mt-3 rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">{actionError}</p>
      ) : null}

      <Modal
        open={confirmGenerate}
        onClose={() => setConfirmGenerate(false)}
        title="Generate maintenance plan"
        confirmLabel="Generate"
        loading={generatePlan.isPending}
        onSubmit={() => void onGenerate()}
      >
        <p>
          Snapshot the assigned template into this vehicle&apos;s maintenance plan? Items whose
          names already exist are skipped, so this is safe to run again.
        </p>
      </Modal>
    </Card>
  );
}

/// Read-only service history for the vehicle (Decision 24): every driver
/// log — do-myself records and fleet-logged services — checkable here.
function ServiceHistoryCard({ orgId, vehicleId }: { orgId: string | null; vehicleId: string }) {
  const { data, isLoading } = useVehicleServiceRecords(orgId, vehicleId);
  const records = data?.items ?? [];

  return (
    <Card className="p-5">
      <div className="flex items-center justify-between gap-3">
        <h2 className="font-display text-base font-semibold text-ink">Service history</h2>
        <Badge tone="neutral">{records.length}</Badge>
      </div>

      {isLoading ? (
        <Skeleton className="mt-4 h-24 w-full" />
      ) : records.length === 0 ? (
        <p className="mt-4 text-sm text-ink-caption">
          No services logged yet. Driver &ldquo;Do myself&rdquo; logs and fleet entries appear here.
        </p>
      ) : (
        <ul className="mt-4 divide-y divide-line-subtle">
          {records.map((record) => (
            <li key={record.id} className="flex items-start justify-between gap-4 py-3">
              <div className="min-w-0">
                <p className="truncate text-sm font-medium text-ink">
                  {record.items.length
                    ? record.items.map((item) => item.name).join(", ")
                    : "Service"}
                </p>
                <p className="mt-0.5 text-xs text-ink-caption">
                  {new Date(record.serviced_on).toLocaleDateString()} ·{" "}
                  {record.odometer.toLocaleString()} km
                  {record.workshop_name ? ` · ${record.workshop_name}` : ""}
                </p>
                {record.notes ? (
                  <p className="mt-1 truncate text-xs text-ink-muted">{record.notes}</p>
                ) : null}
              </div>
              <span className="font-mono text-sm text-ink">
                €{record.total_cost.toLocaleString(undefined, { maximumFractionDigits: 3 })}
              </span>
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}

function planDueTone(
  item: VehiclePlanItem,
  mileage: number,
): "danger" | "warning" | "success" | "neutral" {
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

function planDueLabel(
  item: VehiclePlanItem,
  mileage: number,
): { label: string; tone: "danger" | "warning" | "success" | "neutral" } {
  const tone = planDueTone(item, mileage);
  const label = tone === "danger" ? "Overdue" : tone === "warning" ? "Due soon" : tone === "neutral" ? "Disabled" : "Scheduled";
  return { label, tone };
}

/// Read-only maintenance plan for the vehicle (Decision 24): what the driver
/// sees on their Maintenance tab, mirrored for the fleet.
function MaintenancePlanCard({
  orgId,
  vehicleId,
  mileage,
}: {
  orgId: string | null;
  vehicleId: string;
  mileage: number;
}) {
  const { data, isLoading } = useVehiclePlanItems(orgId, vehicleId);
  const items = data?.items ?? [];

  const sorted = [...items].sort((a, b) => {
    const aOverdue = planDueTone(a, mileage) === "danger" ? 0 : 1;
    const bOverdue = planDueTone(b, mileage) === "danger" ? 0 : 1;
    if (aOverdue !== bOverdue) return aOverdue - bOverdue;
    return a.name.localeCompare(b.name);
  });

  return (
    <Card className="p-5">
      <div className="flex items-center justify-between gap-3">
        <h2 className="font-display text-base font-semibold text-ink">Maintenance plan</h2>
        <Badge tone="neutral">{items.length}</Badge>
      </div>

      {isLoading ? (
        <Skeleton className="mt-4 h-24 w-full" />
      ) : items.length === 0 ? (
        <p className="mt-4 text-sm text-ink-caption">
          No plan items yet. Assign a maintenance template and generate the plan above.
        </p>
      ) : (
        <ul className="mt-4 divide-y divide-line-subtle">
          {sorted.map((item) => {
            const intervals = [
              item.interval_days ? `${item.interval_days} d` : null,
              item.interval_distance ? `${item.interval_distance.toLocaleString()} km` : null,
            ].filter(Boolean);
            const due = planDueLabel(item, mileage);
            const dueParts = [
              item.next_due_on ? new Date(item.next_due_on).toLocaleDateString() : null,
              item.next_due_mileage ? `${item.next_due_mileage.toLocaleString()} km` : null,
            ].filter(Boolean);
            return (
              <li key={item.id} className="flex items-center justify-between gap-4 py-3">
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium text-ink">{item.name}</p>
                  <p className="mt-0.5 text-xs text-ink-caption">
                    {intervals.length ? intervals.join(" · ") : "No interval"}
                    {dueParts.length ? ` · Due ${dueParts.join(" · ")}` : ""}
                  </p>
                </div>
                <Badge tone={due.tone}>{due.label}</Badge>
              </li>
            );
          })}
        </ul>
      )}
    </Card>
  );
}

export default function VehicleDetailPage() {
  const params = useParams<{ id: string }>();
  const vehicleId = params.id;
  const orgId = useOrgId();
  const { data: vehicles, isLoading } = useVehicles(orgId);
  const { data: analytics, isLoading: analyticsLoading } = useVehicleAnalytics(
    orgId,
    vehicleId,
  );

  const vehicle = vehicles?.items.find((v) => v.id === vehicleId);

  if (isLoading) {
    return (
      <div className="flex flex-col gap-6">
        <Skeleton className="h-10 w-64" />
        <Skeleton className="h-40 w-full" />
      </div>
    );
  }

  if (!vehicle) {
    return (
      <div className="flex flex-col gap-6">
        <PageHeader title="Vehicle not found" description="This vehicle is not in your organization inventory." />
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={vehicle.name}
        description={`${vehicle.year} ${vehicle.make} ${vehicle.model} · ${vehicle.license_plate}`}
        actions={<Badge tone="info">{vehicle.status}</Badge>}
      />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card className="p-5">
          <h2 className="font-display text-base font-semibold text-ink">Details</h2>
          <dl className="mt-4 grid grid-cols-2 gap-y-3 text-sm">
            <dt className="text-ink-caption">VIN</dt>
            <dd className="font-mono text-xs text-ink">{vehicle.vin}</dd>
            <dt className="text-ink-caption">Fuel</dt>
            <dd className="text-ink">{vehicle.fuel_type}</dd>
            <dt className="text-ink-caption">Class</dt>
            <dd className="text-ink">
              {vehicleClassOptions.find((o) => o.value === (vehicle.vehicle_class ?? "car"))?.label ??
                vehicle.vehicle_class ??
                "car"}
            </dd>
            <dt className="text-ink-caption">Odometer</dt>
            <dd className="text-ink">
              {vehicle.mileage.toLocaleString()} {vehicle.mileage_unit ?? "km"}
            </dd>
            <dt className="text-ink-caption">Lifecycle</dt>
            <dd className="text-ink">{vehicle.lifecycle_template}</dd>
            <dt className="text-ink-caption">Revenue label</dt>
            <dd className="text-ink">{vehicle.revenue_label ?? "—"}</dd>
            <dt className="text-ink-caption">Added</dt>
            <dd className="text-ink">
              {vehicle.added_at ? new Date(vehicle.added_at).toLocaleDateString() : "—"}
            </dd>
          </dl>
        </Card>

        <Card className="p-5">
          <h2 className="font-display text-base font-semibold text-ink">
            Cost analytics
          </h2>
          {analyticsLoading ? (
            <Skeleton className="mt-4 h-24 w-full" />
          ) : analytics ? (
            <dl className="mt-4 grid grid-cols-2 gap-y-3 text-sm">
              {Object.entries(analytics).map(([key, value]) => (
                <div key={key} className="contents">
                  <dt className="text-ink-caption">
                    {key.replaceAll("_", " ")}
                  </dt>
                  <dd className="text-ink">
                    {typeof value === "number"
                      ? key.includes("cost") || key.includes("spend") || key.includes("tco")
                        ? `€${value.toLocaleString(undefined, { maximumFractionDigits: 3 })}`
                        : value.toLocaleString()
                      : String(value)}
                  </dd>
                </div>
              ))}
            </dl>
          ) : (
            <p className="mt-4 text-sm text-ink-caption">
              Analytics unavailable (requires Org Admin / Manager role).
            </p>
          )}
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <ServiceHistoryCard orgId={orgId} vehicleId={vehicle.id} />
        <MaintenancePlanCard orgId={orgId} vehicleId={vehicle.id} mileage={vehicle.mileage} />
      </div>

      <VehicleTemplateCard orgId={orgId} vehicle={vehicle} />
    </div>
  );
}
