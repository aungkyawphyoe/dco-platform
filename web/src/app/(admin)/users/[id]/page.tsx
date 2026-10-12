"use client";

import { use, useState } from "react";
import { useRouter } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Modal } from "@/components/ui/modal";
import { Select } from "@/components/ui/select";
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
import { Input } from "@/components/ui/input";
import {
  useAdminUser,
  useUpdateUserPlan,
  useUpdateUserRole,
  useUpdateUserAccess,
  useUpdateUserProfile,
  useDeactivateUser,
  useReactivateUser,
  useSendPasswordReset,
  useDeleteUser,
} from "@/lib/api/hooks";
import { PLAN_OPTIONS, type Plan } from "@/lib/plans";

export default function UserProfilePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const router = useRouter();
  const { data: user, isLoading, error } = useAdminUser(id);

  const updatePlan = useUpdateUserPlan();
  const updateRole = useUpdateUserRole();
  const updateAccess = useUpdateUserAccess();
  const updateProfile = useUpdateUserProfile();
  const deactivate = useDeactivateUser();
  const reactivate = useReactivateUser();
  const sendReset = useSendPasswordReset();
  const deleteUser = useDeleteUser();

  const [showDeactivateModal, setShowDeactivateModal] = useState(false);
  const [showReactivateModal, setShowReactivateModal] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [showSetPasswordModal, setShowSetPasswordModal] = useState(false);
  const [newPassword, setNewPassword] = useState("");
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [showProfileModal, setShowProfileModal] = useState(false);
  const [profileDraft, setProfileDraft] = useState({ display_name: "", contact_phone: "", address: "" });
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
              <dt className="text-ink-caption">Username</dt>
              <dd className="font-mono text-ink">{user.username ?? "—"}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-caption">Display name</dt>
              <dd className="text-ink">{user.display_name ?? "—"}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-caption">Contact phone</dt>
              <dd className="text-ink">{user.contact_phone ?? "—"}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-caption">Address</dt>
              <dd className="text-ink max-w-xs truncate">{user.address ?? "—"}</dd>
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
          Account access <span className="ml-2 text-xs font-normal text-gold">demo controls</span>
        </h2>
        <div className="mt-4 flex flex-wrap items-end gap-3">
          <div>
            <p className="text-label uppercase tracking-wide text-ink-caption">Email verified</p>
            <div className="mt-1.5">
              <Badge tone={user.email_verified ? "success" : "warning"}>
                {user.email_verified ? "Yes" : "No"}
              </Badge>
            </div>
          </div>
          {!user.email_verified && (
            <Button
              variant="secondary"
              size="sm"
              disabled={updateAccess.isPending}
              onClick={() =>
                updateAccess.mutate(
                  { id, email_verified: true },
                  { onSuccess: () => setFeedback("Email marked as verified.") },
                )
              }
            >
              Mark email verified
            </Button>
          )}

          <div>
            <p className="text-label uppercase tracking-wide text-ink-caption">Must change password</p>
            <div className="mt-1.5">
              <Badge tone={user.must_change_password ? "warning" : "success"}>
                {user.must_change_password ? "Yes" : "No"}
              </Badge>
            </div>
          </div>
          {user.must_change_password && (
            <Button
              variant="secondary"
              size="sm"
              disabled={updateAccess.isPending}
              onClick={() =>
                updateAccess.mutate(
                  { id, must_change_password: false },
                  { onSuccess: () => setFeedback("Password-change requirement cleared.") },
                )
              }
            >
              Clear requirement
            </Button>
          )}

          <Button
            variant="secondary"
            size="sm"
            onClick={() => {
              setNewPassword("");
              setPasswordError(null);
              setShowSetPasswordModal(true);
            }}
          >
            Set password
          </Button>
        </div>
      </Card>

      <Card className="p-5">
        <h2 className="font-display text-base font-semibold text-ink">
          Actions
        </h2>
        <div className="mt-4 flex flex-wrap gap-3">
          <Select
            label="Plan"
            options={[...PLAN_OPTIONS]}
            value={user.plan ?? "free"}
            disabled={updatePlan.isPending}
            onChange={(v) =>
              updatePlan.mutate(
                { id, plan: v as Plan },
                {
                  onSuccess: () => setFeedback(`Plan changed to ${v}.`),
                },
              )
            }
          />

          <Select
            label="Account role"
            options={[
              { value: "owner", label: "Owner" },
              { value: "admin", label: "Admin" },
            ]}
            value={user.role ?? "owner"}
            disabled={updateRole.isPending}
            onChange={(v) =>
              updateRole.mutate(
                { id, role: v as "owner" | "admin" },
                {
                  onSuccess: () => setFeedback(`Account role changed to ${v}.`),
                  onError: (err) =>
                    setFeedback(err instanceof Error ? err.message : "Role change failed."),
                },
              )
            }
          />

          <div className="self-end">
            <Button
              variant="secondary"
              size="sm"
              onClick={() => {
                setProfileDraft({
                  display_name: user.display_name ?? "",
                  contact_phone: user.contact_phone ?? "",
                  address: user.address ?? "",
                });
                setShowProfileModal(true);
              }}
            >
              Edit profile
            </Button>
          </div>

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
            <>
              <Button
                variant="destructive"
                size="sm"
                disabled={deactivate.isPending}
                onClick={() => setShowDeactivateModal(true)}
              >
                Deactivate account
              </Button>
              <Button
                variant="destructive"
                size="sm"
                disabled={deleteUser.isPending}
                onClick={() => setShowDeleteModal(true)}
              >
                Delete user
              </Button>
            </>
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

      <Modal
        open={showDeleteModal}
        onClose={() => setShowDeleteModal(false)}
        title="Delete user"
        confirmLabel="Delete"
        destructive
        loading={deleteUser.isPending}
        onConfirm={() =>
          deleteUser.mutate(id, {
            onSuccess: () => {
              setShowDeleteModal(false);
              router.push("/users");
            },
          })
        }
      >
        <p>
          This will permanently deactivate <strong>{user.email}</strong>,
          archive all their vehicles, and revoke any vehicle shares they have
          granted or received. This action can be reversed by reactivating the
          account.
        </p>
      </Modal>

      <Modal
        open={showSetPasswordModal}
        onClose={() => setShowSetPasswordModal(false)}
        title="Set password"
        confirmLabel="Set password"
        loading={updateAccess.isPending}
        onSubmit={() => {
          if (newPassword.length < 8) {
            setPasswordError("Password must be at least 8 characters");
            return;
          }
          setPasswordError(null);
          updateAccess.mutate(
            { id, password: newPassword },
            {
              onSuccess: () => {
                setShowSetPasswordModal(false);
                setFeedback(
                  "Password updated. All existing sessions for this user have been signed out.",
                );
              },
            },
          );
        }}
      >
        <p className="mb-4">
          Directly set a new password for <strong>{user.email}</strong>. No
          email is sent; share the password out-of-band. All active sessions
          will be revoked.
        </p>
        <Input
          label="New password"
          type="text"
          autoComplete="new-password"
          value={newPassword}
          onChange={(e) => setNewPassword(e.target.value)}
          error={passwordError}
          hint="At least 8 characters"
        />
      </Modal>

      <Modal
        open={showProfileModal}
        onClose={() => setShowProfileModal(false)}
        title="Edit profile"
        confirmLabel="Save"
        loading={updateProfile.isPending}
        onSubmit={() =>
          updateProfile.mutate(
            {
              id,
              display_name: profileDraft.display_name || null,
              contact_phone: profileDraft.contact_phone || null,
              address: profileDraft.address || null,
            },
            {
              onSuccess: () => {
                setShowProfileModal(false);
                setFeedback("Profile updated.");
              },
            },
          )
        }
      >
        <div className="flex flex-col gap-4">
          <Input
            label="Display name"
            value={profileDraft.display_name}
            onChange={(e) =>
              setProfileDraft((d) => ({ ...d, display_name: e.target.value }))
            }
          />
          <Input
            label="Contact phone"
            value={profileDraft.contact_phone}
            onChange={(e) =>
              setProfileDraft((d) => ({ ...d, contact_phone: e.target.value }))
            }
          />
          <Input
            label="Address"
            value={profileDraft.address}
            onChange={(e) =>
              setProfileDraft((d) => ({ ...d, address: e.target.value }))
            }
          />
        </div>
      </Modal>
    </div>
  );
}
