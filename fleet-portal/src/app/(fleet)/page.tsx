"use client";

import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeadCell, TableRow } from "@/components/ui/table";
import {
  useFleetAnalytics,
  useLemons,
} from "@/lib/api/hooks";
import { useOrgId, useSession } from "@/lib/auth/session-context";

function KpiCard({
  label,
  value,
  format = "number",
}: {
  label: string;
  value?: number;
  format?: "number" | "currency" | "decimal";
}) {
  return (
    <Card className="p-5">
      <p className="text-sm text-ink-caption">{label}</p>
      {value === undefined ? (
        <Skeleton className="mt-2 h-8 w-20" />
      ) : (
        <p className="mt-1 font-display text-3xl font-semibold text-ink">
          {format === "currency"
            ? `€${value.toLocaleString(undefined, { maximumFractionDigits: 0 })}`
            : format === "decimal"
              ? value.toFixed(3)
              : value.toLocaleString()}
        </p>
      )}
    </Card>
  );
}

export default function DashboardPage() {
  const orgId = useOrgId();
  const { org } = useSession();
  const { data: analytics, isLoading, error } = useFleetAnalytics(orgId);
  const { data: lemons } = useLemons(orgId);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Dashboard"
        description={`${org?.organization?.name ?? "Fleet"} — cost analytics, work orders, and lemon flags`}
      />

      {error ? (
        <Card className="p-6">
          <p className="text-sm text-danger">
            Failed to load fleet analytics. Please try again.
          </p>
        </Card>
      ) : (
        <>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <KpiCard label="Vehicles" value={analytics?.vehicle_count} />
            <KpiCard
              label="Total fleet spend"
              value={analytics?.total_fleet_spend}
              format="currency"
            />
            <KpiCard
              label="Avg cost / km"
              value={analytics?.average_cost_per_km}
              format="decimal"
            />
            <KpiCard label="Lemon flags" value={analytics?.lemon_count} />
            <KpiCard label="Open work orders" value={analytics?.open_work_orders} />
            <KpiCard
              label="Active assignments"
              value={analytics?.active_assignments}
            />
            <KpiCard
              label="Upcoming maintenance (30d)"
              value={analytics?.upcoming_maintenance_count}
            />
          </div>

          <Card>
            <div className="border-b border-line-subtle px-5 py-4">
              <h2 className="font-display text-base font-semibold text-ink">
                Lemon flags
              </h2>
              <p className="mt-0.5 text-xs text-ink-caption">
                Vehicles above threshold{" "}
                {lemons
                  ? `(${lemons.threshold_cost_per_km.toFixed(3)} €/km)`
                  : ""}
              </p>
            </div>
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
                    <TableHeadCell>km driven</TableHeadCell>
                    <TableHeadCell>Cost / km</TableHeadCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {lemons.items.map((item, i) => (
                    <TableRow key={i}>
                      <TableCell>{item.name ?? "—"}</TableCell>
                      <TableCell className="font-mono text-xs">
                        {item.license_plate ?? "—"}
                      </TableCell>
                      <TableCell>
                        €{Number(item.tco ?? 0).toLocaleString()}
                      </TableCell>
                      <TableCell>{Number(item.total_km_driven ?? 0).toLocaleString()}</TableCell>
                      <TableCell>
                        <Badge tone="danger">
                          {Number(item.cost_per_km ?? 0).toFixed(3)}
                        </Badge>
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
