"use client";

import { use, useState } from "react";
import { useRouter } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Modal } from "@/components/ui/modal";
import {
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableHeadCell,
  TableCell,
} from "@/components/ui/table";
import {
  UserStatusBadge,
  PlanBadge,
} from "@/components/ui/status-badge";
import {
  useAdminUser,
  useUpdateUserPlan,
  useDeactivateUser,
  useReactivateUser,
  useSendPasswordReset,
} from "@/lib/api/hooks";

export default function UserProfilePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const router = useRouter();
  const { data: user, isLoading, error } = useAdminUser(id);

  const updatePlan = useUpdateUserPlan();
  const deactivate = useDeactivateUser();
  const reactivate = useReactivateUser();
  const sendReset = useSendPasswordReset();

  const [showDeactivateModal, setShowDeactivateModal] = useState(false);
  const [showReactivateModal, setShowReactivateModal] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);

  if (isLoading) {
    return (
      <div className="flex flex-col gap-6">
        <Skeleton className="h-8 w-48" />
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <Skeleton className="h-48 rounded-lg" />
          <Skeleton className="h-48 rounded-lg" />
        </div>
      </div>
    );
  }

  if (error || !user) {
    return (
      <div className="flex flex-col gap-6">
        <PageHeader title="User profile" />
        <Card className="p-6">
          <p className="text-sm text-danger">
            Failed to load user profile.{" "}
            <button
              onClick={() => router.refresh()}
              className="text-gold hover:underline"
            >
              Try again
            </button>
          </p>
        </Card>
      </div>
    );
  }

  const isDeactivated = user.status === "deactivated";

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={user.display_name || user.email || "User"}
        description="Profile, vehicles, documents count, and support actions"
      />

      {feedback && (
        <div className="rounded-md bg-success-dim px-4 py-3 text-sm text-success">
          {feedback}
        </div>
      )}

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card className="p-5">
          <h2 className="font-display text-base font-semibold text-ink">
            Account
          </h2>
          <dl className="mt-4 space-y-3 text-sm">
            <div className="flex justify-between">
              <dt className="text-ink-caption">Email</dt>
              <dd className="text-ink">{user.email}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-caption">Verified</dt>
              <dd>
                <Badge tone={user.email_verified ? "success" : "warning"}>
                  {user.email_verified ? "Yes" : "No"}
                </Badge>
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-caption">Display name</dt>
              <dd className="text-ink">{user.display_name ?? "—"}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-caption">Plan</dt>
              <dd>
                <PlanBadge plan={user.plan} />
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-caption">Status</dt>
              <dd>
                <UserStatusBadge status={user.status} />
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-caption">Member since</dt>
              <dd className="text-ink">
                {user.created_at
                  ? new Intl.DateTimeFormat("en-US", {
                      month: "long",
                      day: "numeric",
                      year: "numeric",
                    }).format(new Date(user.created_at))
                  : "—"}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-caption">Documents</dt>
              <dd className="text-ink">{user.documents_count ?? 0}</dd>
            </div>
          </dl>
        </Card>

        <Card className="p-5">
          <h2 className="font-display text-base font-semibold text-ink">
            Vehicles
          </h2>
          {!user.vehicles?.length ? (
            <p className="mt-4 text-sm text-ink-caption">No vehicles.</p>
          ) : (
            <Table className="mt-4">
              <TableHead>
                <TableRow>
                  <TableHeadCell>Nickname</TableHeadCell>
                  <TableHeadCell>Plate</TableHeadCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {user.vehicles.map((v) => (
                  <TableRow key={v.id}>
                    <TableCell>{v.nickname ?? "—"}</TableCell>
                    <TableCell className="font-mono">
                      {v.license_plate ?? "—"}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </Card>
      </div>

      <Card className="p-5">
        <h2 className="font-display text-base font-semibold text-ink">
          Actions
        </h2>
        <div className="mt-4 flex flex-wrap gap-3">
          <Button
            variant="secondary"
            size="sm"
            disabled={updatePlan.isPending}
            onClick={() =>
              updatePlan.mutate(
                { id, plan: user.plan === "premium" ? "free" : "premium" },
                {
                  onSuccess: () =>
                    setFeedback(
                      `Plan changed to ${user.plan === "premium" ? "free" : "premium"}.`,
                    ),
                },
              )
            }
          >
            Switch to {user.plan === "premium" ? "Free" : "Premium"}
          </Button>

          <Button
            variant="secondary"
            size="sm"
            disabled={sendReset.isPending}
            onClick={() =>
              sendReset.mutate(id, {
                onSuccess: () => setFeedback("Password reset email sent."),
              })
            }
          >
            Send password reset
          </Button>

          {isDeactivated ? (
            <Button
              variant="primary"
              size="sm"
              disabled={reactivate.isPending}
              onClick={() => setShowReactivateModal(true)}
            >
              Reactivate account
            </Button>
          ) : (
            <Button
              variant="destructive"
              size="sm"
              disabled={deactivate.isPending}
              onClick={() => setShowDeactivateModal(true)}
            >
              Deactivate account
            </Button>
          )}
        </div>
      </Card>

      <Modal
        open={showDeactivateModal}
        onClose={() => setShowDeactivateModal(false)}
        title="Deactivate user"
        confirmLabel="Deactivate"
        destructive
        loading={deactivate.isPending}
        onConfirm={() =>
          deactivate.mutate(id, {
            onSuccess: () => {
              setShowDeactivateModal(false);
              setFeedback("User deactivated.");
            },
          })
        }
      >
        <p>
          This will revoke access to the app for{" "}
          <strong>{user.email}</strong>. They can be reactivated later.
        </p>
      </Modal>

      <Modal
        open={showReactivateModal}
        onClose={() => setShowReactivateModal(false)}
        title="Reactivate user"
        confirmLabel="Reactivate"
        loading={reactivate.isPending}
        onConfirm={() =>
          reactivate.mutate(id, {
            onSuccess: () => {
              setShowReactivateModal(false);
              setFeedback("User reactivated.");
            },
          })
        }
      >
        <p>
          This will restore access to the app for{" "}
          <strong>{user.email}</strong>.
        </p>
      </Modal>
    </div>
  );
}
