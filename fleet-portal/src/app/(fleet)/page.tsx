"use client";

import Link from "next/link";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Badge } from "@dco/ui/components/badge";
import { Button } from "@dco/ui/components/button";
import { Skeleton } from "@dco/ui/components/skeleton";
import { SectionHeading } from "@dco/ui/components/section-heading";
import { apiGet } from "@/lib/api/client";
import { ApiError } from "@/lib/api/errors";
import type { AnalyticsReport } from "@/lib/api/analytics";
import { useOrgId, useSession } from "@/lib/auth/session-context";

type Group = "urgent" | "overdue" | "stalled" | "review" | "upcoming";
type Action = { id: string; vehicle_id: string; vehicle: string; plate: string; group: Group; title: string; detail: string; href: string };
type Attention = { today: string; timezone: string; generated_at: string; vehicle_count: number; assigned_vehicles: number; open_work_orders: number; maintenance_vehicles: number; items: Action[]; limitations: string[] };
const groups: { id: Group; label: string; tone: "danger" | "warning" | "info" | "neutral" }[] = [
  { id: "urgent", label: "Top urgency", tone: "danger" },
  { id: "overdue", label: "Overdue maintenance", tone: "warning" },
  { id: "stalled", label: "Stalled work orders", tone: "warning" },
  { id: "review", label: "Needs review", tone: "info" },
  { id: "upcoming", label: "Upcoming maintenance", tone: "neutral" },
];
const linkStyle = "rounded text-link underline underline-offset-4 focus-visible:outline focus-visible:outline-2 focus-visible:outline-focus";

export default function DashboardPage() {
  const orgId = useOrgId();
  const { org } = useSession();
  const [filter, setFilter] = useState<Group | "all">("all");
  const attention = useQuery({ queryKey: ["fleet", "attention", orgId], queryFn: () => apiGet<Attention>(`/organizations/${orgId}/analytics/attention`), enabled: !!orgId, refetchInterval: 60000 });
  const today = attention.data?.today;
  const report = useQuery({ queryKey: ["fleet", "dashboard-cost", orgId, today], queryFn: () => apiGet<AnalyticsReport>(`/organizations/${orgId}/analytics/report?from=${today!.slice(0, 7)}-01&to=${today}&calendar=true&active=true`), enabled: !!orgId && !!today });
  const data = attention.data;
  const costs = report.data;
  const format = (value: number | null, digits = 0) => value === null ? "Unavailable" : new Intl.NumberFormat(undefined, { maximumFractionDigits: digits }).format(value);
  const urgentVehicles = new Set(data?.items.filter(item => item.group === "urgent").map(item => item.vehicle_id)).size;
  return <div className="flex flex-col gap-6">

    <PageHeader title="Fleet overview" description="Resolve today’s priorities, then review operating costs." meta={org?.organization?.name ?? "Your fleet"} />

    {attention.isPending && <div aria-label="Loading fleet overview" className="space-y-3">
      <Skeleton className="h-28 w-full" />
      <Skeleton className="h-64 w-full" />
    </div>}

    {attention.error && <Card className="p-5">
      <p role="alert" className="text-danger">
        {attention.error instanceof ApiError && attention.error.status === 403 ? "Fleet overview is available to organization admins and managers." : "Fleet priorities could not be loaded. Try again to check the latest status."}
      </p>
      <Button className="mt-3" variant="secondary" onClick={() => void attention.refetch()}>Try again</Button>
    </Card>}

    {data && !attention.error && <>

      <div className="flex flex-wrap items-center justify-between gap-3 text-sm text-ink-caption">
        <p>As of {new Date(data.generated_at).toLocaleString(undefined, { timeZone: data.timezone })} ({data.timezone})</p>
        <Button size="sm" variant="secondary" disabled={attention.isFetching} onClick={() => { void attention.refetch(); void report.refetch(); }}>
          {attention.isFetching ? "Refreshing…" : "Refresh"}
        </Button>
      </div>

      <div className="grid items-start gap-6 xl:grid-cols-[minmax(0,3fr)_minmax(16rem,1fr)]">

        <Card>

          <div className="border-b border-line p-5">
            <h2 className="font-display text-2xl font-semibold">Needs attention</h2>
            <p className="mt-1 text-sm text-ink-muted">{data.items.length ? `${data.items.length} actions across ${new Set(data.items.map(item => item.vehicle_id)).size} vehicles.` : data.vehicle_count ? "No actions found in the recorded data." : "Add your first vehicle to start monitoring fleet priorities."} Operating decisions remain with your fleet manager.</p>
          </div>

          <div className="flex flex-wrap gap-2 border-b border-line p-4" aria-label="Filter priorities">
            <Button size="sm" variant={filter === "all" ? "primary" : "secondary"} aria-pressed={filter === "all"} onClick={() => setFilter("all")}>All ({data.items.length})</Button>
            {groups.map(group => <Button key={group.id} size="sm" variant={filter === group.id ? "primary" : "secondary"} aria-pressed={filter === group.id} onClick={() => setFilter(group.id)}>{group.label} ({data.items.filter(item => item.group === group.id).length})</Button>)}
          </div>

          {groups.filter(group => filter === "all" || filter === group.id).map(group => {
            const items = data.items.filter(item => item.group === group.id);
            if (!items.length && filter === "all") return null;
            return <section key={group.id} aria-label={group.label} className="p-5">
              <div className="mb-3 flex items-center gap-2">
                <Badge tone={group.tone}>
                  {items.length}
                </Badge>
                <h3 className="font-display text-lg font-semibold">
                  {group.label}
                </h3>
              </div>
              {group.id === "upcoming" && <p className="mb-3 text-sm text-ink-caption">Due within 30 days or 500 km. Vehicles with overdue maintenance appear above.</p>}
              {!items.length && <p className="text-sm text-ink-caption">No recorded actions in this group.</p>}
              <ul className="divide-y divide-line">
                {items.map(item => <li key={`${item.group}-${item.id}`} className="grid gap-2 py-4 first:pt-0 sm:grid-cols-[minmax(0,1fr)_auto]">
                  <div>
                    <p className="font-medium">
                      {item.title}
                    </p>
                    <p className="mt-1 text-sm">
                      <Link className={linkStyle} href={`/vehicles/${item.vehicle_id}`}>
                        {item.vehicle}
                        {item.plate ? ` (${item.plate})` : ""}
                      </Link>
                    </p>
                    <p className="mt-1 max-w-prose break-words text-sm text-ink-caption">
                      {item.detail}
                    </p>
                  </div>
                  <Link className={`${linkStyle} self-center text-sm`} href={item.href}>Review record</Link>
                </li>)}
              </ul>
            </section>;
          })}

          {!data.items.length && <p className="p-5 text-sm">
            <Link className={linkStyle} href="/vehicles">View vehicles</Link>
          </p>}

        </Card>

        <div className="space-y-6">
          <Card>
            <SectionHeading title="Fleet status" />
            <dl className="divide-y divide-line px-5">
              {[["Vehicles", data.vehicle_count], ["Vehicles with urgent alerts", urgentVehicles], ["Assigned vehicles", data.assigned_vehicles], ["In maintenance", data.maintenance_vehicles], ["Open work orders", data.open_work_orders]].map(([label, value]) => <div key={label} className="flex items-center justify-between gap-3 py-4">
                <dt className="text-sm text-ink-muted">
                  {label}
                </dt>
                <dd className="text-xl font-semibold tabular-nums">
                  {value}
                </dd>
              </div>)}
            </dl>
          </Card>
          <Card className="p-5">
            <h2 className="font-display text-lg font-semibold">Alert coverage</h2>
            <ul className="mt-3 space-y-3 text-sm text-ink-caption">
              {data.limitations.map(note => <li key={note}>
                {note}
              </li>)}
            </ul>
          </Card>
        </div>

      </div>

      <Card>
        <SectionHeading title="Operating costs this month">
          <Link className={`${linkStyle} text-sm`} href="/analytics">Explore analytics</Link>
        </SectionHeading>
        <div className="p-5">

          {report.isPending && <Skeleton className="h-24 w-full" />}

          {report.error && <div role="alert">
            <p className="text-sm text-danger">Costs could not be loaded. Check your reporting currency in Organization settings or try again.</p>
            <Button className="mt-3" size="sm" variant="secondary" onClick={() => void report.refetch()}>Retry costs</Button>
          </div>}

          {costs && !report.error && <>
            <p className="mb-4 text-sm text-ink-caption">{costs.period.from} to {costs.period.to}. Current fleet, {costs.currency}.</p>
            <div className="grid gap-6 sm:grid-cols-3">
              <div>
                <p className="text-sm text-ink-muted">Recorded spend</p>
                <p className="mt-1 text-2xl font-semibold tabular-nums">
                  {format(costs.total_cost)}
                  {costs.currency}
                </p>
                <p className="mt-1 text-sm text-ink-caption">
                  {costs.changes.total_cost === null ? "No comparable previous-period baseline" : `${costs.changes.total_cost > 0 ? "+" : ""}${format(costs.changes.total_cost, 1)}% vs previous period`}
                </p>
              </div>
              <div>
                <p className="text-sm text-ink-muted">Matched cost / km</p>
                <p className="mt-1 text-2xl font-semibold tabular-nums">
                  {format(costs.cost_per_km, 2)}
                  {costs.cost_per_km !== null ? ` ${costs.currency}` : ""}
                </p>
              </div>
              <div>
                <p className="text-sm text-ink-muted">Recorded distance</p>
                <p className="mt-1 text-2xl font-semibold tabular-nums">
                  {format(costs.distance_km, 1)}
                  {costs.distance_km !== null ? " km" : ""}
                </p>
                <p className="mt-1 text-sm text-ink-caption">
                  {costs.coverage_complete ? "Complete mileage coverage" : "Incomplete mileage coverage; comparisons may be limited"}
                </p>
              </div>
            </div>
            <div className="mt-6 space-y-3" aria-label="Spending by category">
              {Object.entries(costs.categories).sort((a, b) => b[1] - a[1]).map(([category, amount]) => <div key={category} className="grid grid-cols-[7rem_minmax(0,1fr)_auto] items-center gap-3 text-sm">
                <span className="capitalize">
                  {category.replaceAll("_", " ")}
                </span>
                <div className="h-2 rounded bg-panel">
                  <div className="h-2 rounded bg-info" style={{ width: `${Math.min(100, Math.max(0, costs.total_cost > 0 ? amount / costs.total_cost * 100 : 0))}%` }} />
                </div>
                <span className="tabular-nums">
                  {format(amount)}
                </span>
              </div>)}
            </div>
            {costs.warnings.map(warning => <p key={warning} className="mt-3 text-xs text-ink-caption">
              {warning}
            </p>)}
          </>}

        </div>
      </Card>

    </>}

  </div>;
}
