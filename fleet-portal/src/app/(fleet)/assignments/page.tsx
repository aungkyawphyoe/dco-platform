"use client";

import { useState } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { Modal } from "@/components/ui/modal";
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
import {
  useAssignments,
  useCreateAssignment,
  useMembers,
  useRemoveAssignment,
  useVehicles,
} from "@/lib/api/hooks";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";

export default function AssignmentsPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const canManage = role === "org_admin" || role === "org_manager";

  const { data: assignments, isLoading } = useAssignments(orgId);
  const { data: members } = useMembers(orgId);
  const { data: vehicles } = useVehicles(orgId);
  const createAssignment = useCreateAssignment(orgId);
  const removeAssignment = useRemoveAssignment(orgId);

  const [showAssign, setShowAssign] = useState(false);
  const [vehicleId, setVehicleId] = useState("");
  const [driverId, setDriverId] = useState("");
  const [error, setError] = useState<string | null>(null);

  const drivers =
    members?.items.filter((m) => m.role === "org_driver") ?? [];
  const vehicleList = vehicles?.items ?? [];
  const memberById = new Map(members?.items.map((m) => [m.user_id, m]) ?? []);
  const vehicleById = new Map(vehicleList.map((v) => [v.id, v]));

  const active = (assignments?.items ?? []).filter((a) => a.status === "active");
  const history = (assignments?.items ?? []).filter((a) => a.status !== "active");

  async function onAssign() {
    setError(null);
    if (!vehicleId || !driverId) {
      setError("Select a vehicle and a driver");
      return;
    }
    try {
      await createAssignment.mutateAsync({ vehicle_id: vehicleId, driver_id: driverId });
      setShowAssign(false);
      setVehicleId("");
      setDriverId("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Assignment failed");
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Driver Assignments"
        description="One active vehicle per driver; unassign releases the vehicle"
        actions={
          canManage ? (
            <Button onClick={() => setShowAssign(true)}>Assign driver</Button>
          ) : null
        }
      />

      <Card>
        <div className="border-b border-line-subtle px-5 py-4">
          <h2 className="font-display text-base font-semibold text-ink">
            Active assignments
          </h2>
        </div>
        {isLoading ? (
          <div className="p-5">
            <SkeletonTable rows={4} cols={5} />
          </div>
        ) : active.length === 0 ? (
          <EmptyState
            title="No active assignments"
            description="Assign drivers to vehicles to enable inspections and work orders."
          />
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Vehicle</TableHeadCell>
                <TableHeadCell>Driver</TableHeadCell>
                <TableHeadCell>Assigned</TableHeadCell>
                <TableHeadCell>Status</TableHeadCell>
                <TableHeadCell />
              </TableRow>
            </TableHead>
            <TableBody>
              {active.map((assignment) => {
                const driver = memberById.get(assignment.driver_id);
                const vehicle = vehicleById.get(assignment.vehicle_id);
                return (
                  <TableRow key={assignment.id}>
                    <TableCell>
                      {vehicle
                        ? `${vehicle.name} (${vehicle.license_plate})`
                        : assignment.vehicle_id.slice(0, 8)}
                    </TableCell>
                    <TableCell>
                      <p className="text-ink">{driver?.display_name || driver?.email || assignment.driver_id.slice(0, 8)}</p>
                      <p className="text-xs text-ink-caption">{driver?.email}</p>
                    </TableCell>
                    <TableCell className="text-xs text-ink-caption">
                      {assignment.assigned_at
                        ? new Date(assignment.assigned_at).toLocaleDateString()
                        : "—"}
                    </TableCell>
                    <TableCell>
                      <Badge tone="success">{assignment.status}</Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      {canManage ? (
                        <Button
                          size="sm"
                          variant="destructive"
                          onClick={() => void removeAssignment.mutateAsync(assignment.id)}
                          disabled={removeAssignment.isPending}
                        >
                          Unassign
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

      {history.length ? (
        <Card>
          <div className="border-b border-line-subtle px-5 py-4">
            <h2 className="font-display text-base font-semibold text-ink">
              History
            </h2>
          </div>
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Vehicle</TableHeadCell>
                <TableHeadCell>Driver</TableHeadCell>
                <TableHeadCell>Ended</TableHeadCell>
                <TableHeadCell>Status</TableHeadCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {history.map((assignment) => (
                <TableRow key={assignment.id}>
                  <TableCell>
                    {vehicleById.get(assignment.vehicle_id)?.name ??
                      assignment.vehicle_id.slice(0, 8)}
                  </TableCell>
                  <TableCell>
                    {memberById.get(assignment.driver_id)?.email ??
                      assignment.driver_id.slice(0, 8)}
                  </TableCell>
                  <TableCell className="text-xs text-ink-caption">
                    {assignment.unassigned_at
                      ? new Date(assignment.unassigned_at).toLocaleDateString()
                      : "—"}
                  </TableCell>
                  <TableCell>
                    <Badge tone="neutral">{assignment.status}</Badge>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </Card>
      ) : null}

      <Modal
        open={showAssign}
        onClose={() => setShowAssign(false)}
        title="Assign driver"
        confirmLabel="Assign"
        loading={createAssignment.isPending}
        onSubmit={() => void onAssign()}
      >
        <div className="flex flex-col gap-3">
          <Select
            label="Vehicle"
            options={vehicleList.map((v) => ({
              value: v.id,
              label: `${v.name} (${v.license_plate})`,
            }))}
            placeholder="Select vehicle…"
            value={vehicleId}
            onChange={setVehicleId}
          />
          <Select
            label="Driver"
            options={drivers.map((d) => ({
              value: d.user_id,
              label: d.display_name || d.email,
            }))}
            placeholder="Select driver…"
            value={driverId}
            onChange={setDriverId}
          />
          {error ? (
            <p className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">
              {error}
            </p>
          ) : null}
        </div>
      </Modal>
    </div>
  );
}
