"use client";

import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableHeadCell,
  TableCell,
} from "@/components/ui/table";
import { SkeletonTable } from "@/components/ui/skeleton";
import { useOwnedVehicles, useSharedVehicles } from "@/lib/api/hooks";

function displayName(vehicle: {
  name: string;
  nickname: string | null;
}): string {
  return vehicle.nickname?.trim() || vehicle.name;
}

export default function VehiclesPage() {
  const owned = useOwnedVehicles();
  const shared = useSharedVehicles();

  const ownedItems = owned.data?.items ?? [];
  const sharedItems = shared.data?.items ?? [];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Vehicles"
        description="Share your vehicles and see what others have shared with you"
      />

      <section className="flex flex-col gap-3">
        <h2 className="font-display text-lg font-semibold text-ink">
          My vehicles
        </h2>

        {owned.error ? (
          <Card className="p-6">
            <p className="text-sm text-danger">
              Failed to load your vehicles. Please try again.
            </p>
          </Card>
        ) : owned.isLoading ? (
          <Card className="p-5">
            <SkeletonTable rows={3} cols={4} />
          </Card>
        ) : ownedItems.length === 0 ? (
          <Card>
            <EmptyState
              title="No vehicles yet"
              description="Vehicles are added from the AutoHub mobile app. Once one is synced it appears here."
            />
          </Card>
        ) : (
          <Card>
            <Table>
              <TableHead>
                <TableRow>
                  <TableHeadCell>Vehicle</TableHeadCell>
                  <TableHeadCell>Plate</TableHeadCell>
                  <TableHeadCell>Year</TableHeadCell>
                  <TableHeadCell className="text-right">Sharing</TableHeadCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {ownedItems.map((vehicle) => (
                  <TableRow key={vehicle.id}>
                    <TableCell className="font-medium text-ink">
                      {displayName(vehicle)}
                    </TableCell>
                    <TableCell className="font-mono text-ink-muted">
                      {vehicle.license_plate}
                    </TableCell>
                    <TableCell className="text-ink-muted">
                      {vehicle.year}
                    </TableCell>
                    <TableCell className="text-right">
                      <Link href={`/vehicles/${vehicle.id}/shares`}>
                        <Button variant="ghost" size="sm">
                          Manage shares
                        </Button>
                      </Link>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </Card>
        )}
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="font-display text-lg font-semibold text-ink">
          Shared with me
        </h2>

        {shared.error ? (
          <Card className="p-6">
            <p className="text-sm text-danger">
              Failed to load shared vehicles. Please try again.
            </p>
          </Card>
        ) : shared.isLoading ? (
          <Card className="p-5">
            <SkeletonTable rows={2} cols={4} />
          </Card>
        ) : sharedItems.length === 0 ? (
          <Card>
            <EmptyState
              title="Nothing shared with you"
              description="When another owner shares a vehicle with you it shows up here."
            />
          </Card>
        ) : (
          <Card>
            <Table>
              <TableHead>
                <TableRow>
                  <TableHeadCell>Vehicle</TableHeadCell>
                  <TableHeadCell>Plate</TableHeadCell>
                  <TableHeadCell>Owner</TableHeadCell>
                  <TableHeadCell>Access</TableHeadCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {sharedItems.map((vehicle) => (
                  <TableRow key={vehicle.id}>
                    <TableCell className="font-medium text-ink">
                      {displayName(vehicle)}
                    </TableCell>
                    <TableCell className="font-mono text-ink-muted">
                      {vehicle.license_plate}
                    </TableCell>
                    <TableCell className="text-ink-muted">
                      {vehicle.owner?.display_name ??
                        vehicle.owner?.email ??
                        "—"}
                    </TableCell>
                    <TableCell>
                      <Badge tone={vehicle.access_level === "add_edit_own" ? "info" : "neutral"}>
                        {vehicle.access_level === "add_edit_own"
                          ? "Add & edit"
                          : "View only"}
                      </Badge>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </Card>
        )}
      </section>
    </div>
  );
}
