"use client";

import { useMemo } from "react";
import { HandoverPanel } from "@/components/vehicles/handover-panel";
import { ReminderSetup } from "@/components/vehicles/reminder-setup";
import { VehicleStatus } from "@/components/vehicles/vehicle-status";
import { VehicleDocuments } from "@/components/vehicles/vehicle-documents";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Card } from "@dco/ui/components/card";
import { Badge } from "@dco/ui/components/badge";
import { Skeleton } from "@dco/ui/components/skeleton";
import { EmptyState } from "@dco/ui/components/empty-state";
import { DataPlate } from "@dco/ui/components/data-plate";
import { SectionHeading } from "@dco/ui/components/section-heading";
import {
  useVehicleAnalytics,
  useVehiclePlanItems,
  useVehicleServiceRecords,
  useVehicles,
} from "@/lib/api/hooks";
import type {
  FleetVehicle,
  VehiclePlanItem,
} from "@/lib/api/types";
import {
  fuelTypeOptions,
  lifecycleTemplateOptions,
  vehicleClassOptions,
} from "@/lib/api/types";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";
import { useFleetCurrency } from "@/lib/api/currency";
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
    (dueOn !== null && dueOn.getTime() - Date.now() < (item.warning_days ?? 30) * 24 * 60 * 60 * 1000) ||
    (item.next_due_mileage !== null &&
      item.next_due_mileage !== undefined &&
      mileage >= item.next_due_mileage - (item.warning_distance ?? 500));
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
          value: `${vehicle.mileage.toLocaleString(undefined, { maximumFractionDigits: 0 })} ${vehicle.mileage_unit ?? "km"}`,
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
      return { name: chosen.name, when: `${(chosen.next_due_mileage as number).toLocaleString(undefined, { maximumFractionDigits: 0 })} km` };
    }
    return null;
  }, [items, mileage]);

  if (items.length === 0) {
    return (
      <p className="mt-4 max-w-md text-sm text-ink-caption">
        No maintenance reminders yet. Add the services this vehicle needs to
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
  currency,
  analytics,
  isLoading,
}: {
  currency: string;
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
    { label: "Cost / km", value: money(analytics.cost_per_km ?? 0, 3, currency) },
    { label: "Distance", value: `${(analytics.total_km_driven ?? 0).toLocaleString(undefined, { maximumFractionDigits: 0 })} km` },
    { label: "Utilization", value: `${analytics.utilization_rate ?? 0}%` },
  ];

  return (
    <>
      <p className="mt-3 font-mono text-3xl font-medium tracking-tight text-ink">
        {money(analytics.tco ?? 0, 0, currency)}
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
                <dd className="font-mono text-ink-muted">{money(part.value, 0, currency)}</dd>
              </div>
            ))}
          </dl>
        </div>
      ) : null}
    </>
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
                    <span className="font-mono">{record.odometer.toLocaleString(undefined, { maximumFractionDigits: 0 })} km</span>
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
                  {record.total_cost.toLocaleString(undefined, { maximumFractionDigits: 20 })} {record.currency}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </Card>
  );
}

// ── Page ────────────────────────────────────────────────────────────────────

export default function VehicleDetailPage() {
  const params = useParams<{ id: string }>();
  const vehicleId = params.id;
  const orgId = useOrgId();
  const fleetCurrency = useFleetCurrency(orgId);
  const role = useOrgRole();
  const canManage = role === "org_admin" || role === "org_manager";

  const { data: vehicles, isLoading } = useVehicles(orgId);
  const { data: planData } = useVehiclePlanItems(orgId, vehicleId);
  const { data: analytics, isLoading: analyticsLoading } = useVehicleAnalytics(orgId, vehicleId);

  const vehicle = vehicles?.items.find((v) => v.id === vehicleId);
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
      <VehicleStatus key={vehicle.id} vehicle={vehicle} orgId={orgId} canManage={canManage} />
      {vehicle.lifecycle_template === "showroom" ? (
        <HandoverPanel
          orgId={orgId}
          vehicle={vehicle}
          planItems={planItems}
          canManage={canManage}
        />
      ) : null}
      {orgId && role === "org_admin" && <VehicleDocuments key={`${orgId}:${vehicle.id}`} orgId={orgId} vehicleId={vehicle.id} />}

      <section className="rounded-lg border border-line-subtle bg-panel">
        <div className="grid grid-cols-1 lg:grid-cols-[3fr_2fr] lg:divide-x lg:divide-line">
          <div className="p-5">
            <h2 className="font-display text-base font-semibold text-ink">Service condition</h2>
            <ConditionStrip items={planItems} mileage={vehicle.mileage} />
          </div>
          <div className="border-t border-line-subtle p-5 lg:border-t-0">
            <h2 className="font-display text-base font-semibold text-ink">Cost analytics</h2>
            <CostPanel currency={vehicle?.base_currency ?? fleetCurrency.data?.currency ?? "MMK"} analytics={analytics} isLoading={analyticsLoading} />
          </div>
        </div>
      </section>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-5">
        <div className="lg:col-span-3">
          <ServiceHistorySection orgId={orgId} vehicleId={vehicle.id} />
        </div>
        <div className="lg:col-span-2">
          <ReminderSetup orgId={orgId} vehicleId={vehicle.id} items={planItems} canManage={canManage} />
        </div>
      </div>
    </div>
  );
}
