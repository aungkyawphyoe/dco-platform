"use client";

import { useParams } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { useVehicleAnalytics, useVehicles } from "@/lib/api/hooks";
import { useOrgId } from "@/lib/auth/session-context";

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
    </div>
  );
}
