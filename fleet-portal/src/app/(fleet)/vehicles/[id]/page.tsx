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
  useVehicles,
} from "@/lib/api/hooks";
import type { FleetVehicle, MaintenanceTemplate } from "@/lib/api/types";
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

      <VehicleTemplateCard orgId={orgId} vehicle={vehicle} />
    </div>
  );
}
