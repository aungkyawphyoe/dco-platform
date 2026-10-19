"use client";

import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { SkeletonTable } from "@/components/ui/skeleton";
import { SectionHeading } from "@/components/ui/section-heading";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeadCell,
  TableRow,
} from "@/components/ui/table";
import { useTransferred } from "@/lib/api/hooks";
import { useOrgId } from "@/lib/auth/session-context";
import { formatDateTime } from "@/lib/format";

export default function TransferredPage() {
  const orgId = useOrgId();
  const { data, isLoading } = useTransferred(orgId);
  const items = data?.items ?? [];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Transferred"
        meta={items.length ? `${items.length} vehicles` : undefined}
        description="Read-only audit of vehicles transferred out of the organization"
      />

      <Card>
        <SectionHeading title="Transfer log" count={items.length} />
        {isLoading ? (
          <div className="p-5">
            <SkeletonTable rows={4} cols={5} />
          </div>
        ) : items.length === 0 ? (
          <EmptyState
            title="No transfers"
            description="Showroom transfers to buyers appear here with warranty linkage."
          />
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Vehicle</TableHeadCell>
                <TableHeadCell>Plate</TableHeadCell>
                <TableHeadCell>Transferred</TableHeadCell>
                <TableHeadCell>Warranty</TableHeadCell>
                <TableHeadCell>Transferred by</TableHeadCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {items.map((item) => (
                <TableRow key={item.id}>
                  <TableCell>
                    <p className="text-ink">{item.vehicle.name}</p>
                    <p className="text-xs text-ink-caption">
                      {item.vehicle.year} {item.vehicle.make} {item.vehicle.model}
                    </p>
                  </TableCell>
                  <TableCell className="font-mono text-xs">{item.vehicle.plate}</TableCell>
                  <TableCell className="font-mono text-xs text-ink-caption">
                    {item.transferred_at ? formatDateTime(item.transferred_at) : "—"}
                  </TableCell>
                  <TableCell className="font-mono text-xs text-ink-caption">
                    {item.warranty_instance_id ? item.warranty_instance_id.slice(0, 8) : "—"}
                  </TableCell>
                  <TableCell className="font-mono text-xs text-ink-caption">
                    {item.transferred_by.slice(0, 8)}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </Card>
    </div>
  );
}
