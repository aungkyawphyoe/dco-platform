"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useState } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { EmptyState } from "@/components/ui/empty-state";
import { Modal } from "@/components/ui/modal";
import { QrCodeModal } from "@/components/ui/qr-code-modal";
import {
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableHeadCell,
  TableCell,
} from "@/components/ui/table";
import { SkeletonTable } from "@/components/ui/skeleton";
import {
  useCancelShareInvite,
  useCreateVehicleShare,
  useResendShareInvite,
  useRevokeVehicleShare,
  useUpdateVehicleShare,
  useVehicleShares,
  type ShareAccessLevel,
} from "@/lib/api/hooks";

const accessLabel = (level: ShareAccessLevel) =>
  level === "add_edit_own" ? "Add & edit own" : "View only";

function formatDate(value: string | null): string {
  if (!value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "—" : date.toLocaleDateString();
}

function errorMessage(error: unknown): string {
  if (error && typeof error === "object" && "message" in error) {
    return String((error as { message: unknown }).message);
  }
  return error instanceof Error ? error.message : "Something went wrong";
}

export default function VehicleSharesPage() {
  const params = useParams<{ id: string }>();
  const vehicleId = params.id;

  const detail = useVehicleShares(vehicleId);
  const createShare = useCreateVehicleShare(vehicleId);
  const updateShare = useUpdateVehicleShare(vehicleId);
  const revokeShare = useRevokeVehicleShare(vehicleId);
  const resendInvite = useResendShareInvite(vehicleId);
  const cancelInvite = useCancelShareInvite(vehicleId);

  const [email, setEmail] = useState("");
  const [access, setAccess] = useState<ShareAccessLevel>("view");
  const [formError, setFormError] = useState<string | null>(null);
  const [inviteError, setInviteError] = useState<string | null>(null);
  const [showQr, setShowQr] = useState(false);
  const [regenerateOpen, setRegenerateOpen] = useState(false);
  const [revokeTarget, setRevokeTarget] = useState<{
    id: string;
    label: string;
  } | null>(null);

  const data = detail.data;
  const vehicleName = data
    ? (data.vehicle.nickname?.trim() || data.vehicle.name)
    : "Vehicle";

  async function onInvite(e: React.FormEvent) {
    e.preventDefault();
    setFormError(null);
    const trimmed = email.trim();
    if (!trimmed) {
      setFormError("Email is required");
      return;
    }
    try {
      await createShare.mutateAsync({
        method: "email",
        email: trimmed,
        access_level: access,
      });
      setEmail("");
      setAccess("view");
    } catch (error) {
      setFormError(errorMessage(error));
    }
  }

  async function onChangeAccess(shareId: string, next: ShareAccessLevel) {
    setInviteError(null);
    try {
      await updateShare.mutateAsync({ shareId, access_level: next });
    } catch (error) {
      setInviteError(errorMessage(error));
    }
  }

  async function onRegenerate() {
    setInviteError(null);
    try {
      await createShare.mutateAsync({ method: "code_qr", access_level: access });
      setRegenerateOpen(false);
    } catch (error) {
      setInviteError(errorMessage(error));
    }
  }

  const activeShares = (data?.shares ?? []).filter((s) => s.status === "active");
  const pendingShares = (data?.shares ?? []).filter((s) => s.status === "pending");
  // Code/QR invitations have no addressee — they live in the share-code card.
  const emailInvites = (data?.pending_invites ?? []).filter(
    (invite) => invite.invited_email,
  );
  const shareCode = data?.share_code ?? null;
  const qrPayload = shareCode
    ? `dco://vehicle/share/join?code=${shareCode}`
    : "";

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={`Share — ${vehicleName}`}
        description={
          data ? `License plate ${data.vehicle.license_plate}` : "Loading vehicle…"
        }
        actions={
          <Link href="/vehicles">
            <Button variant="secondary" size="sm">
              Back to vehicles
            </Button>
          </Link>
        }
      />

      {detail.error ? (
        <Card className="p-6">
          <p className="text-sm text-danger">
            {errorMessage(detail.error)}
          </p>
          <div className="mt-3">
            <Button size="sm" variant="secondary" onClick={() => detail.refetch()}>
              Retry
            </Button>
          </div>
        </Card>
      ) : detail.isLoading || !data ? (
        <Card className="p-5">
          <SkeletonTable rows={4} cols={5} />
        </Card>
      ) : (
        <>
          <p className="text-sm text-ink-caption">
            {data.limits.active_on_vehicle} of {data.limits.per_vehicle} active
            shares on this vehicle (plan limit {data.limits.total} total).
          </p>

          {inviteError ? (
            <Card className="p-4">
              <p className="text-sm text-danger">{inviteError}</p>
            </Card>
          ) : null}

          <section className="flex flex-col gap-3">
            <h2 className="font-display text-lg font-semibold text-ink">
              Invite by email
            </h2>
            <Card className="p-5">
              <form
                onSubmit={onInvite}
                className="flex flex-wrap items-end gap-3"
              >
                <Input
                  label="Email address"
                  type="email"
                  name="email"
                  autoComplete="email"
                  placeholder="name@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-72"
                />
                <Select
                  label="Access level"
                  value={access}
                  onChange={(value) => setAccess(value as ShareAccessLevel)}
                  options={[
                    { value: "view", label: "View only" },
                    { value: "add_edit_own", label: "Add & edit own" },
                  ]}
                  className="w-52"
                />
                <Button
                  type="submit"
                  size="md"
                  disabled={createShare.isPending}
                >
                  {createShare.isPending ? "Sending…" : "Send invitation"}
                </Button>
              </form>
              {formError ? (
                <p className="mt-3 text-sm text-danger">{formError}</p>
              ) : null}
            </Card>
          </section>

          <section className="flex flex-col gap-3">
            <h2 className="font-display text-lg font-semibold text-ink">
              Active shares
            </h2>
            {activeShares.length === 0 ? (
              <Card>
                <EmptyState
                  title="No one has access yet"
                  description="Invite by email or share the code to give someone access."
                />
              </Card>
            ) : (
              <Card>
                <Table>
                  <TableHead>
                    <TableRow>
                      <TableHeadCell>Person</TableHeadCell>
                      <TableHeadCell>Email</TableHeadCell>
                      <TableHeadCell>Access</TableHeadCell>
                      <TableHeadCell>Joined</TableHeadCell>
                      <TableHeadCell className="text-right">
                        Actions
                      </TableHeadCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {activeShares.map((share) => (
                      <TableRow key={share.id}>
                        <TableCell className="font-medium text-ink">
                          {share.display_name ??
                            share.email ??
                            share.invited_email ??
                            share.user_id.slice(0, 8)}
                        </TableCell>
                        <TableCell className="text-ink-muted">
                          {share.email ?? share.invited_email ?? "—"}
                        </TableCell>
                        <TableCell>
                          <Select
                            label=""
                            value={share.access_level}
                            onChange={(value) =>
                              onChangeAccess(share.id, value as ShareAccessLevel)
                            }
                            options={[
                              { value: "view", label: "View only" },
                              {
                                value: "add_edit_own",
                                label: "Add & edit own",
                              },
                            ]}
                            disabled={updateShare.isPending}
                            className="w-44"
                          />
                        </TableCell>
                        <TableCell className="text-ink-muted">
                          {formatDate(share.accepted_at ?? share.created_at)}
                        </TableCell>
                        <TableCell className="text-right">
                          <Button
                            variant="destructive"
                            size="sm"
                            onClick={() =>
                              setRevokeTarget({
                                id: share.id,
                                label:
                                  share.display_name ??
                                  share.email ??
                                  share.invited_email ??
                                  "this person",
                              })
                            }
                          >
                            Revoke
                          </Button>
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
              Pending invitations
            </h2>
            {pendingShares.length === 0 && emailInvites.length === 0 ? (
              <Card>
                <EmptyState
                  title="No pending invitations"
                  description="Invitations you send show up here until they are accepted."
                />
              </Card>
            ) : (
              <Card>
                <Table>
                  <TableHead>
                    <TableRow>
                      <TableHeadCell>Email</TableHeadCell>
                      <TableHeadCell>Access</TableHeadCell>
                      <TableHeadCell>Expires</TableHeadCell>
                      <TableHeadCell className="text-right">
                        Actions
                      </TableHeadCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {emailInvites.map((invite) => (
                      <TableRow key={invite.id}>
                        <TableCell className="font-medium text-ink">
                          {invite.invited_email}
                        </TableCell>
                        <TableCell>
                          <Badge tone={invite.access_level === "add_edit_own" ? "info" : "neutral"}>
                            {accessLabel(invite.access_level)}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-ink-muted">
                          {formatDate(invite.expires_at)}
                        </TableCell>
                        <TableCell className="text-right">
                          <div className="flex justify-end gap-2">
                            <Button
                              variant="secondary"
                              size="sm"
                              disabled={resendInvite.isPending}
                              onClick={() => resendInvite.mutate(invite.id)}
                            >
                              Resend
                            </Button>
                            <Button
                              variant="destructive"
                              size="sm"
                              disabled={cancelInvite.isPending}
                              onClick={() => cancelInvite.mutate(invite.id)}
                            >
                              Cancel
                            </Button>
                          </div>
                        </TableCell>
                      </TableRow>
                    ))}
                    {pendingShares.map((share) => (
                      <TableRow key={share.id}>
                        <TableCell className="font-medium text-ink">
                          {share.invited_email ?? share.email ?? "—"}
                        </TableCell>
                        <TableCell>
                          <Badge tone={share.access_level === "add_edit_own" ? "info" : "neutral"}>
                            {accessLabel(share.access_level)}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-ink-muted">—</TableCell>
                        <TableCell className="text-right">
                          <Button
                            variant="destructive"
                            size="sm"
                            disabled={revokeShare.isPending}
                            onClick={() => revokeShare.mutate(share.id)}
                          >
                            Cancel
                          </Button>
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
              Share code &amp; QR
            </h2>
            <Card className="p-5">
              {shareCode ? (
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <p className="text-label uppercase tracking-wide text-ink-caption">
                      Share code
                    </p>
                    <p className="font-mono text-2xl tracking-[0.3em] text-gold">
                      {shareCode}
                    </p>
                    <p className="mt-1 text-xs text-ink-caption">
                      Codes expire in 7 days. Regenerating invalidates the old
                      one.
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => {
                        void navigator.clipboard?.writeText(shareCode);
                      }}
                    >
                      Copy code
                    </Button>
                    <Button size="sm" onClick={() => setShowQr(true)}>
                      Show QR
                    </Button>
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => setRegenerateOpen(true)}
                    >
                      Regenerate
                    </Button>
                  </div>
                </div>
              ) : (
                <div className="flex flex-col items-start gap-3">
                  <p className="text-sm text-ink-caption">
                    No share code yet. Generate one and share the code, or let
                    someone scan the QR, to give access without an email.
                  </p>
                  <Button
                    size="sm"
                    disabled={createShare.isPending}
                    onClick={() => onRegenerate()}
                  >
                    Generate code
                  </Button>
                </div>
              )}
            </Card>
          </section>
        </>
      )}

      <QrCodeModal
        open={showQr}
        onClose={() => setShowQr(false)}
        data={qrPayload}
        label={vehicleName}
        code={shareCode ?? ""}
      />

      <Modal
        open={regenerateOpen}
        onClose={() => setRegenerateOpen(false)}
        title="Regenerate share code?"
        confirmLabel="Regenerate"
        loading={createShare.isPending}
        onSubmit={() => void onRegenerate()}
      >
        The current code stops working immediately.
      </Modal>

      <Modal
        open={Boolean(revokeTarget)}
        onClose={() => setRevokeTarget(null)}
        title="Revoke access?"
        confirmLabel="Revoke"
        destructive
        loading={revokeShare.isPending}
        onSubmit={() => {
          if (!revokeTarget) return;
          revokeShare.mutate(revokeTarget.id, {
            onSettled: () => setRevokeTarget(null),
          });
        }}
      >
        {revokeTarget?.label} will lose access to this vehicle.
      </Modal>
    </div>
  );
}
