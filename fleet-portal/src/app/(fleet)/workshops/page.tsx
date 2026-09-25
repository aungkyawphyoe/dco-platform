"use client";

import { useState } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
  useApproveWorkshop,
  useRevokeWorkshop,
  useWorkshops,
} from "@/lib/api/hooks";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";

export default function WorkshopsPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const isAdmin = role === "org_admin";

  const { data, isLoading } = useWorkshops(orgId);
  const approve = useApproveWorkshop(orgId);
  const revoke = useRevokeWorkshop(orgId);

  const [showAdd, setShowAdd] = useState(false);
  const [partnerId, setPartnerId] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function onApprove() {
    setError(null);
    const id = partnerId.trim();
    if (!id) {
      setError("Partner ID is required");
      return;
    }
    try {
      await approve.mutateAsync(id);
      setShowAdd(false);
      setPartnerId("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Approval failed");
    }
  }

  const workshops = data?.items ?? [];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Workshops"
        description="Approved workshop partners for warranty coverage and service"
        actions={
          isAdmin ? (
            <Button onClick={() => setShowAdd(true)}>Approve workshop</Button>
          ) : null
        }
      />

      <Card>
        {isLoading ? (
          <div className="p-5">
            <SkeletonTable rows={3} cols={4} />
          </div>
        ) : workshops.length === 0 ? (
          <EmptyState
            title="No approved workshops"
            description="Approve verified workshop partners by their partner ID."
          />
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Name</TableHeadCell>
                <TableHeadCell>Contact</TableHeadCell>
                <TableHeadCell>Status</TableHeadCell>
                <TableHeadCell>Added</TableHeadCell>
                <TableHeadCell />
              </TableRow>
            </TableHead>
            <TableBody>
              {workshops.map((workshop) => (
                <TableRow key={workshop.id}>
                  <TableCell className="font-medium text-ink">
                    {workshop.name}
                  </TableCell>
                  <TableCell>
                    <p className="text-xs text-ink">{workshop.contact_email ?? "—"}</p>
                    <p className="text-xs text-ink-caption">
                      {workshop.contact_phone ?? ""}
                    </p>
                  </TableCell>
                  <TableCell>
                    <Badge tone={workshop.status === "verified" ? "success" : "warning"}>
                      {workshop.status}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-xs text-ink-caption">
                    {workshop.added_at
                      ? new Date(workshop.added_at).toLocaleDateString()
                      : "—"}
                  </TableCell>
                  <TableCell className="text-right">
                    {isAdmin ? (
                      <Button
                        size="sm"
                        variant="destructive"
                        onClick={() => void revoke.mutateAsync(workshop.id)}
                        disabled={revoke.isPending}
                      >
                        Revoke
                      </Button>
                    ) : null}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </Card>

      <Modal
        open={showAdd}
        onClose={() => setShowAdd(false)}
        title="Approve workshop"
        confirmLabel="Approve"
        loading={approve.isPending}
        onSubmit={() => void onApprove()}
      >
        <div className="flex flex-col gap-3">
          <Input
            label="Workshop partner ID (UUID)"
            value={partnerId}
            onChange={(e) => setPartnerId(e.target.value)}
            hint="Must be a verified workshop partner provisioned by DCO Admin."
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
