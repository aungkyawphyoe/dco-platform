"use client";
import { Subscriptions } from "@/components/billing/subscriptions";

import { use, useState } from "react";
import { useRouter } from "next/navigation";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Button } from "@dco/ui/components/button";
import { Badge } from "@dco/ui/components/badge";
import { Skeleton } from "@dco/ui/components/skeleton";
import { Modal } from "@dco/ui/components/modal";
import { Select } from "@dco/ui/components/select";
import { DataPlate } from "@dco/ui/components/data-plate";
import { SectionHeading } from "@dco/ui/components/section-heading";
import { Stat } from "@dco/ui/components/stat";
import { formatDate } from "@dco/ui/lib/format";
import {
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableHeadCell,
  TableCell,
} from "@dco/ui/components/table";
import {
  UserStatusBadge,
  PlanBadge,
} from "@/components/ui/status-badge";
import { Input } from "@dco/ui/components/input";
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
        backHref="/users"
        backLabel="Back to users"
        title={user.display_name || user.email || "User"}
        status={<UserStatusBadge status={user.status} />}
        meta={user.email}
      />

      {feedback && (
        <div className="rounded-md bg-success-dim px-4 py-3 text-sm text-success">
          {feedback}
        </div>
      )}

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card className="flex flex-col">
          <SectionHeading title="Account">
            <UserStatusBadge status={user.status} />
          </SectionHeading>
          <div className="p-5">
            <DataPlate
              className=""
              fields={[
                { label: "Email", value: user.email },
                { label: "Username", value: user.username ?? "—", mono: true },
                { label: "Display name", value: user.display_name ?? "—" },
                { label: "Contact phone", value: user.contact_phone ?? "—" },
                { label: "Address", value: user.address ?? "—" },
                { label: "Plan", value: <PlanBadge plan={user.plan} /> },
                {
                  label: "Member since",
                  value: user.created_at ? formatDate(user.created_at) : "—",
                  mono: true,
                },
                {
                  label: "Documents",
                  value: (user.documents_count ?? 0).toLocaleString(),
                  mono: true,
                },
              ]}
            />
          </div>
        </Card>

        <Card className="flex flex-col">
          <SectionHeading title="Vehicles" count={user.vehicles?.length ?? 0} />
          <div className="p-5">
            {!user.vehicles?.length ? (
              <p className="text-sm text-ink-caption">No vehicles.</p>
            ) : (
              <Table>
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
                      <TableCell className="font-mono text-xs">
                        {v.license_plate ?? "—"}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </div>
        </Card>
      </div>

      <Card className="flex flex-col">
        <SectionHeading title="Account access">
          <span className="text-xs text-gold">demo controls</span>
        </SectionHeading>
        <div className="flex flex-wrap items-end gap-3 p-5">
          <Stat
            label="Email verified"
            mono={false}
            value={
              <Badge tone={user.email_verified ? "success" : "warning"}>
                {user.email_verified ? "Yes" : "No"}
              </Badge>
            }
          />
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

          <Stat
            label="Must change password"
            mono={false}
            value={
              <Badge tone={user.must_change_password ? "warning" : "success"}>
                {user.must_change_password ? "Yes" : "No"}
              </Badge>
            }
          />
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

      <Card className="flex flex-col">
        <SectionHeading title="Actions" />
        <div className="flex flex-wrap gap-3 p-5">
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
      <Subscriptions kind="user" id={id} />
    </div>
  );
}
