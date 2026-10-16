"use client";

import { use, useEffect, useState } from "react";
import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";
import { Skeleton } from "@/components/ui/skeleton";
import { OrganizationStatusBadge, OrganizationTypeBadge } from "@/components/ui/status-badge";
import {
  useAdminOrganization,
  useResendOrganizationInvite,
  useUpdateOrganization,
  useUpdateOrganizationStatus,
} from "@/lib/api/hooks";

const ORGANIZATION_TYPES = [
  { value: "showroom", label: "Showroom" },
  { value: "dealership", label: "Dealership" },
  { value: "taxi_fleet", label: "Taxi fleet" },
  { value: "rental", label: "Rental" },
  { value: "commercial", label: "Commercial" },
  { value: "logistics", label: "Logistics" },
] as const;

type OrganizationType = (typeof ORGANIZATION_TYPES)[number]["value"];
type PendingAction = "activate" | "suspend" | "archive" | "invite";

const dateFormat = new Intl.DateTimeFormat("en-US", {
  month: "short",
  day: "numeric",
  year: "numeric",
});

export default function OrganizationDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const { data: organization, isLoading, error, refetch } = useAdminOrganization(id);
  const update = useUpdateOrganization();
  const changeStatus = useUpdateOrganizationStatus();
  const resendInvite = useResendOrganizationInvite();

  const [name, setName] = useState("");
  const [type, setType] = useState<OrganizationType | "">("");
  const [contactEmail, setContactEmail] = useState("");
  const [contactPhone, setContactPhone] = useState("");
  const [nameError, setNameError] = useState<string | undefined>(undefined);
  const [saved, setSaved] = useState(false);
  const [banner, setBanner] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [pendingAction, setPendingAction] = useState<PendingAction | null>(null);

  useEffect(() => {
    if (organization) {
      setName(organization.name ?? "");
      setType((organization.type ?? "") as OrganizationType);
      setContactEmail(organization.contact_email ?? "");
      setContactPhone(organization.contact_phone ?? "");
    }
  }, [organization]);

  if (isLoading) {
    return (
      <div className="flex flex-col gap-6">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-96 max-w-xl rounded-lg" />
      </div>
    );
  }

  if (error || !organization) {
    return (
      <div className="flex flex-col gap-6">
        <PageHeader title="Organization" />
        <Card className="p-6">
          <p className="text-sm text-danger">
            Failed to load organization.{" "}
            <button onClick={() => refetch()} className="text-gold hover:underline">
              Try again
            </button>
          </p>
        </Card>
      </div>
    );
  }

  const status = organization.status;
  const isArchived = status === "archived";

  function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) {
      setNameError("Name is required.");
      return;
    }
    setNameError(undefined);
    setSaved(false);

    update.mutate(
      {
        id,
        name: name.trim(),
        type: (type || undefined) as OrganizationType | undefined,
        contact_email: contactEmail.trim() || null,
        contact_phone: contactPhone.trim() || null,
      },
      { onSuccess: () => setSaved(true) },
    );
  }

  function confirmAction() {
    if (!pendingAction) return;
    setActionError(null);

    if (pendingAction === "invite") {
      resendInvite.mutate(id, {
        onSuccess: () => {
          setBanner("Organization invitation resent to the Org Admin.");
          setPendingAction(null);
        },
        onError: (err) => setActionError((err as Error)?.message ?? "Failed to resend invitation."),
      });
      return;
    }

    const nextStatus =
      pendingAction === "activate"
        ? "active"
        : pendingAction === "suspend"
          ? "suspended"
          : "archived";

    changeStatus.mutate(
      { id, status: nextStatus },
      {
        onSuccess: (data) => {
          if (data.activation_email_sent) {
            setBanner("Organization activated. Activation email sent to the Org Admin.");
          } else if (nextStatus === "archived") {
            setBanner("Organization archived. Members and organization vehicles were removed.");
          } else {
            setBanner(`Organization is now ${nextStatus}.`);
          }
          setPendingAction(null);
        },
        onError: (err) =>
          setActionError((err as Error)?.message ?? "Failed to update status."),
      },
    );
  }

  const actionBusy = changeStatus.isPending || resendInvite.isPending;

  const actionModal: Record<
    PendingAction,
    { title: string; confirmLabel: string; body: string; destructive?: boolean }
  > = {
    activate: {
      title: "Activate organization",
      confirmLabel: "Activate",
      body: `Fleet access is granted to all members of “${organization.name}”, and the Org Admin receives an activation email.`,
    },
    suspend: {
      title: "Suspend organization",
      confirmLabel: "Suspend",
      body: `Fleet access is removed for all members of “${organization.name}”. Personal app access is unaffected.`,
    },
    archive: {
      title: "Archive organization",
      confirmLabel: "Archive",
      destructive: true,
      body: `Archiving “${organization.name}” permanently removes its members and organization vehicles. This cannot be undone.`,
    },
    invite: {
      title: "Resend Org Admin invitation",
      confirmLabel: "Resend",
      body: `Sends the organization invitation email to ${organization.admin_email ?? "the Org Admin"} again.`,
    },
  };

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={organization.name}
        description="Enterprise organization — provisioning and lifecycle"
        actions={
          <Link href="/organizations">
            <Button variant="secondary" size="sm">
              Back to organizations
            </Button>
          </Link>
        }
      />

      {saved && (
        <div className="rounded-md bg-success-dim px-4 py-3 text-sm text-success">
          Organization details updated.
        </div>
      )}
      {banner && (
        <div className="rounded-md bg-success-dim px-4 py-3 text-sm text-success">
          {banner}
        </div>
      )}
      {actionError && (
        <div className="rounded-md bg-danger-dim px-4 py-3 text-sm text-danger">
          {actionError}
        </div>
      )}

      <div className="grid max-w-4xl gap-6 lg:grid-cols-2">
        <Card className="p-6">
          <h2 className="font-display text-base font-semibold text-ink">
            Details
          </h2>
          <form onSubmit={handleSave} className="mt-5 flex flex-col gap-5">
            <Input
              label="Name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              error={nameError}
              maxLength={200}
              disabled={isArchived}
              required
            />
            <Select
              label="Type"
              placeholder="Select type..."
              options={ORGANIZATION_TYPES.map((option) => ({ ...option }))}
              value={type}
              onChange={(v) => setType(v as OrganizationType)}
              disabled={isArchived}
            />
            <Input
              label="Contact email"
              type="email"
              value={contactEmail}
              onChange={(e) => setContactEmail(e.target.value)}
              disabled={isArchived}
            />
            <Input
              label="Contact phone"
              type="tel"
              value={contactPhone}
              onChange={(e) => setContactPhone(e.target.value)}
              maxLength={20}
              disabled={isArchived}
            />
            {update.isError && (
              <p className="text-sm text-danger">
                {(update.error as Error)?.message ?? "Failed to update organization."}
              </p>
            )}
            {!isArchived && (
              <div className="pt-1">
                <Button type="submit" size="sm" disabled={update.isPending}>
                  {update.isPending ? "Saving..." : "Save changes"}
                </Button>
              </div>
            )}
          </form>
        </Card>

        <div className="flex flex-col gap-6">
          <Card className="p-6">
            <h2 className="font-display text-base font-semibold text-ink">
              Status &amp; access
            </h2>
            <dl className="mt-4 flex flex-col gap-3 text-sm">
              <div className="flex items-center justify-between gap-4">
                <dt className="text-ink-caption">Status</dt>
                <dd>
                  <OrganizationStatusBadge status={status} />
                </dd>
              </div>
              <div className="flex items-center justify-between gap-4">
                <dt className="text-ink-caption">Type</dt>
                <dd>
                  <OrganizationTypeBadge type={organization.type} />
                </dd>
              </div>
              <div className="flex items-center justify-between gap-4">
                <dt className="text-ink-caption">Plan</dt>
                <dd className="text-ink">{organization.plan}</dd>
              </div>
              <div className="flex items-center justify-between gap-4">
                <dt className="text-ink-caption">Org Admin</dt>
                <dd className="truncate text-ink">{organization.admin_email ?? "—"}</dd>
              </div>
              <div className="flex items-center justify-between gap-4">
                <dt className="text-ink-caption">Members</dt>
                <dd className="text-ink">{organization.member_count}</dd>
              </div>
              <div className="flex items-center justify-between gap-4">
                <dt className="text-ink-caption">Created</dt>
                <dd className="text-ink">
                  {dateFormat.format(new Date(organization.created_at))}
                </dd>
              </div>
              <div className="flex items-center justify-between gap-4">
                <dt className="text-ink-caption">Activated</dt>
                <dd className="text-ink">
                  {organization.activated_at
                    ? dateFormat.format(new Date(organization.activated_at))
                    : "—"}
                </dd>
              </div>
            </dl>
          </Card>

          <Card className="p-6">
            <h2 className="font-display text-base font-semibold text-ink">
              Actions
            </h2>
            {isArchived ? (
              <p className="mt-3 text-sm text-ink-caption">
                This organization is archived. No actions are available.
              </p>
            ) : (
              <div className="mt-4 flex flex-wrap gap-3">
                {(status === "pending" || status === "suspended") && (
                  <Button size="sm" onClick={() => setPendingAction("activate")}>
                    Activate
                  </Button>
                )}
                {status === "active" && (
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => setPendingAction("suspend")}
                  >
                    Suspend
                  </Button>
                )}
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={() => setPendingAction("invite")}
                >
                  Resend invite
                </Button>
                <Button
                  variant="destructive"
                  size="sm"
                  onClick={() => setPendingAction("archive")}
                >
                  Archive
                </Button>
              </div>
            )}
          </Card>
        </div>
      </div>

      {pendingAction && (
        <Modal
          open
          onClose={() => {
            setPendingAction(null);
            setActionError(null);
          }}
          title={actionModal[pendingAction].title}
          confirmLabel={actionModal[pendingAction].confirmLabel}
          destructive={actionModal[pendingAction].destructive}
          loading={actionBusy}
          onSubmit={confirmAction}
        >
          <div className="flex flex-col gap-2">
            <p>{actionModal[pendingAction].body}</p>
            {actionError && (
              <p className="text-sm text-danger">{actionError}</p>
            )}
          </div>
        </Modal>
      )}
    </div>
  );
}
