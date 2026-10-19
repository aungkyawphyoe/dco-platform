"use client";

import Link from "next/link";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Badge } from "@dco/ui/components/badge";
import { Skeleton } from "@dco/ui/components/skeleton";
import { InstrumentBand } from "@dco/ui/components/instrument-band";
import { DataPlate } from "@dco/ui/components/data-plate";
import { SectionHeading } from "@dco/ui/components/section-heading";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeadCell,
  TableRow,
} from "@dco/ui/components/table";
import { useFleetAnalytics, useLemons } from "@/lib/api/hooks";
import { useOrgId, useSession } from "@/lib/auth/session-context";
import { money } from "@dco/ui/lib/format";

function AttentionTile({
  href,
  count,
  label,
  tone,
}: {
  href: string;
  count?: number;
  label: string;
  tone: "danger" | "warning" | "info";
}) {
  const numberTone =
    count && count > 0
      ? tone === "danger"
        ? "text-danger"
        : tone === "warning"
          ? "text-warning"
          : "text-info"
      : "text-ink";
  return (
    <Link
      href={href}
      className="group rounded-md border border-line-subtle bg-card p-4 transition-colors hover:border-line-strong"
    >
      {count === undefined ? (
        <Skeleton className="h-9 w-12" />
      ) : (
        <p className={`font-mono text-3xl font-medium tracking-tight ${numberTone}`}>
          {count}
        </p>
      )}
      <p className="mt-1 text-sm text-ink-muted transition-colors group-hover:text-ink">
        {label}
      </p>
    </Link>
  );
}

export default function DashboardPage() {
  const orgId = useOrgId();
  const { org } = useSession();
  const { data: analytics, isLoading, error } = useFleetAnalytics(orgId);
  const { data: lemons } = useLemons(orgId);

  const orgName = org?.organization?.name ?? "Your fleet";
  const meta = analytics ? `${orgName}, ${analytics.vehicle_count} vehicles` : orgName;

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Dashboard" meta={meta} />

      {error ? (
        <Card className="p-5">
          <p className="max-w-xl text-sm text-ink-caption">
            Fleet analytics are visible to Org Admins and Managers. Ask an admin to review fleet
            costs and upcoming maintenance.
          </p>
        </Card>
      ) : (
        <>
          <InstrumentBand>
            <div className="grid grid-cols-1 lg:grid-cols-[3fr_2fr] lg:divide-x lg:divide-line">
              <div className="p-5">
                <h2 className="font-display text-base font-semibold text-ink">Needs attention</h2>
                <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3">
                  <AttentionTile
                    href="/vehicles"
                    count={analytics?.upcoming_maintenance_count}
                    label="vehicles due for maintenance in 30 days"
                    tone="warning"
                  />
                  <AttentionTile
                    href="/work-orders"
                    count={analytics?.open_work_orders}
                    label="work orders still open"
                    tone="info"
                  />
                  <AttentionTile
                    href="#lemons"
                    count={analytics?.lemon_count}
                    label="vehicles above the lemon threshold"
                    tone="danger"
                  />
                </div>
              </div>

              <div className="border-t border-line-subtle p-5 lg:border-t-0">
                <h2 className="font-display text-base font-semibold text-ink">Fleet at a glance</h2>
                <DataPlate
                  className="mt-4"
                  fields={[
                    {
                      label: "Vehicles",
                      value: analytics ? analytics.vehicle_count.toLocaleString() : "—",
                      mono: true,
                    },
                    {
                      label: "Total spend",
                      value: analytics ? money(analytics.total_fleet_spend, 0) : "—",
                      mono: true,
                    },
                    {
                      label: "Average cost",
                      value: analytics ? `${money(analytics.average_cost_per_km, 3)} / km` : "—",
                      mono: true,
                    },
                    {
                      label: "Active assignments",
                      value: analytics ? analytics.active_assignments.toLocaleString() : "—",
                      mono: true,
                    },
                  ]}
                />
              </div>
            </div>
          </InstrumentBand>

          <Card id="lemons">
            <SectionHeading title="Lemon flags" count={lemons?.items.length ?? 0}>
              {lemons ? (
                <span className="text-xs text-ink-caption">
                  Above {money(lemons.threshold_cost_per_km, 3)} per km
                </span>
              ) : null}
            </SectionHeading>
            {isLoading ? (
              <div className="space-y-3 p-5">
                <Skeleton className="h-5 w-full" />
                <Skeleton className="h-5 w-3/4" />
              </div>
            ) : !lemons?.items.length ? (
              <p className="p-5 text-sm text-ink-caption">
                No vehicles currently exceed the lemon threshold.
              </p>
            ) : (
              <Table>
                <TableHead>
                  <TableRow>
                    <TableHeadCell>Vehicle</TableHeadCell>
                    <TableHeadCell>Plate</TableHeadCell>
                    <TableHeadCell>TCO</TableHeadCell>
                    <TableHeadCell>Distance</TableHeadCell>
                    <TableHeadCell>Cost / km</TableHeadCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {lemons.items.map((item, i) => (
                    <TableRow key={i}>
                      <TableCell className="font-medium">{item.name ?? "—"}</TableCell>
                      <TableCell className="font-mono text-xs">
                        {item.license_plate ?? "—"}
                      </TableCell>
                      <TableCell className="font-mono">
                        {money(Number(item.tco ?? 0), 0)}
                      </TableCell>
                      <TableCell className="font-mono">
                        {Number(item.total_km_driven ?? 0).toLocaleString()} km
                      </TableCell>
                      <TableCell>
                        <Badge tone="danger">{Number(item.cost_per_km ?? 0).toFixed(3)}</Badge>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </Card>
        </>
      )}
    </div>
  );
}
