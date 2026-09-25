"use client";

import { useState } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";
import { Select } from "@/components/ui/select";
import { EmptyState } from "@/components/ui/empty-state";
import { SkeletonTable } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeadCell,
  TableRow,
} from "@/components/ui/table";
import { useMembers, useUpdateWorkOrder, useVehicles, useWorkOrders } from "@/lib/api/hooks";
import { workOrderStatusTone } from "@/lib/api/types";
import { useOrgId, useOrgRole, useSession } from "@/lib/auth/session-context";

export default function WorkOrdersPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const { user } = useSession();
  const canManage = role === "org_admin" || role === "org_manager";

  const { data, isLoading } = useWorkOrders(orgId);
  const { data: members } = useMembers(orgId);
  const updateOrder = useUpdateWorkOrder(orgId);

  const [advance, setAdvance] = useState<{
    id: string;
    next: string;
    assign?: boolean;
  } | null>(null);
  const [assignee, setAssignee] = useState("");
  const [notes, setNotes] = useState("");

  const orders = data?.items ?? [];
  const mechanics =
    members?.items.filter((m) =>
      ["org_manager", "org_mechanic"].includes(m.role),
    ) ?? [];

  const { data: vehiclesData } = useVehicles(orgId);
  const vehicles = vehiclesData?.items ?? [];

  function nextStatus(status: string): string | null {
    if (status === "reported") return "in_progress";
    if (status === "in_progress") return "completed";
    return null;
  }

  async function onAdvance() {
    if (!advance) return;
    await updateOrder.mutateAsync({
      id: advance.id,
      status: advance.next,
      ...(advance.assign && assignee ? { assigned_to: assignee } : {}),
      ...(advance.next === "completed" && notes
        ? { resolution_notes: notes }
        : {}),
    });
    setAdvance(null);
    setAssignee("");
    setNotes("");
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Work Orders"
        description="Reported → in progress → completed, with assignee controls"
      />

      <Card>
        {isLoading ? (
          <div className="p-5">
            <SkeletonTable rows={5} cols={6} />
          </div>
        ) : orders.length === 0 ? (
          <EmptyState
            title="No work orders"
            description="Drivers report issues from their assignment; orders appear here."
          />
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Vehicle</TableHeadCell>
                <TableHeadCell>Issue</TableHeadCell>
                <TableHeadCell>Urgency</TableHeadCell>
                <TableHeadCell>Status</TableHeadCell>
                <TableHeadCell>Odometer</TableHeadCell>
                <TableHeadCell>Reported</TableHeadCell>
                <TableHeadCell />
              </TableRow>
            </TableHead>
            <TableBody>
              {orders.map((order) => {
                const next = nextStatus(order.status);
                const vehicleName =
                  vehicles.find((v) => v.id === order.vehicle_id)?.name ??
                  order.vehicle_id.slice(0, 8);
                return (
                  <TableRow key={order.id}>
                    <TableCell>{vehicleName}</TableCell>
                    <TableCell>
                      <p className="font-medium capitalize text-ink">
                        {order.issue_type.replaceAll("_", " ")}
                      </p>
                      <p className="line-clamp-1 max-w-md text-xs text-ink-caption">
                        {order.description}
                      </p>
                    </TableCell>
                    <TableCell>
                      <Badge
                        tone={
                          order.urgency === "critical" || order.urgency === "high"
                            ? "danger"
                            : order.urgency === "medium"
                              ? "warning"
                              : "neutral"
                        }
                      >
                        {order.urgency}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <Badge tone={workOrderStatusTone[order.status] ?? "neutral"}>
                        {order.status}
                      </Badge>
                    </TableCell>
                    <TableCell>{order.odometer_km.toLocaleString()} km</TableCell>
                    <TableCell className="text-xs text-ink-caption">
                      {order.reported_at
                        ? new Date(order.reported_at).toLocaleString()
                        : "—"}
                    </TableCell>
                    <TableCell>
                      {canManage && next ? (
                        <Button
                          size="sm"
                          variant="secondary"
                          onClick={() => {
                            setAdvance({
                              id: order.id,
                              next,
                              assign: next === "in_progress",
                            });
                          }}
                        >
                          {next === "in_progress" ? "Start" : "Complete"}
                        </Button>
                      ) : null}
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        )}
      </Card>

      <Modal
        open={Boolean(advance)}
        onClose={() => setAdvance(null)}
        title={advance?.next === "completed" ? "Complete work order" : "Start work order"}
        confirmLabel={advance?.next === "completed" ? "Complete" : "Start"}
        loading={updateOrder.isPending}
        onSubmit={() => void onAdvance()}
      >
        <div className="flex flex-col gap-3">
          {advance?.assign ? (
            <Select
              label="Assign to"
              options={[
                { value: "", label: "Unassigned" },
                ...mechanics.map((m) => ({
                  value: m.user_id,
                  label: m.display_name || m.email,
                })),
              ]}
              value={assignee}
              onChange={setAssignee}
            />
          ) : null}
          {advance?.next === "completed" ? (
            <textarea
              className="min-h-20 rounded-md border border-line-strong bg-field p-3 text-sm text-ink"
              placeholder="Resolution notes (optional)"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          ) : null}
          <p className="text-xs text-ink-caption">
            Signed in as {user?.email} ({role ?? "—"})
          </p>
        </div>
      </Modal>
    </div>
  );
}
