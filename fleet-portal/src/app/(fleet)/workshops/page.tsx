"use client";

import { useState } from "react";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Badge } from "@dco/ui/components/badge";
import { Button } from "@dco/ui/components/button";
import { Input } from "@dco/ui/components/input";
import { Modal } from "@dco/ui/components/modal";
import { EmptyState } from "@dco/ui/components/empty-state";
import { SkeletonTable } from "@dco/ui/components/skeleton";
import { SectionHeading } from "@dco/ui/components/section-heading";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeadCell,
  TableRow,
} from "@dco/ui/components/table";
import {
  useApproveWorkshop,
  useRevokeWorkshop,
  useWorkshops,
} from "@/lib/api/hooks";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";
import { formatDate } from "@dco/ui/lib/format";

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
  const verified = workshops.filter((w) => w.status === "verified").length;

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Workshops"
        meta={workshops.length ? `${workshops.length} approved, ${verified} verified` : undefined}
        description="Approved workshop partners for warranty coverage and service"
        actions={
          isAdmin ? <Button onClick={() => setShowAdd(true)}>Approve workshop</Button> : null
        }
      />

      <Card>
        <SectionHeading title="Approved workshops" count={workshops.length} />
        {isLoading ? (
          <div className="p-5">
            <SkeletonTable rows={3} cols={5} />
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
                  <TableCell className="font-medium text-ink">{workshop.name}</TableCell>
                  <TableCell>
                    <p className="text-xs text-ink">{workshop.contact_email ?? "—"}</p>
                    <p className="text-xs text-ink-caption">{workshop.contact_phone ?? ""}</p>
                  </TableCell>
                  <TableCell>
                    <Badge tone={workshop.status === "verified" ? "success" : "warning"}>
                      {workshop.status}
                    </Badge>
                  </TableCell>
                  <TableCell className="font-mono text-xs text-ink-caption">
                    {workshop.added_at ? formatDate(workshop.added_at) : "—"}
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
            hint="Must be a verified workshop partner provisioned by AutoX Admin."
          />
          {error ? (
            <p className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">{error}</p>
          ) : null}
        </div>
      </Modal>
    </div>
  );
}
