"use client";

import { useState } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
import { useInviteMember, useMembers, useUpdateMember } from "@/lib/api/hooks";
import { orgRoleLabel } from "@/lib/api/types";
import { useOrgId, useOrgRole, useSession } from "@/lib/auth/session-context";

const assignableRoles = [
  { value: "org_manager", label: "Manager" },
  { value: "org_mechanic", label: "Mechanic" },
  { value: "org_driver", label: "Driver" },
];

export default function MembersPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const { user } = useSession();
  const isAdmin = role === "org_admin";

  const { data, isLoading } = useMembers(orgId);
  const invite = useInviteMember(orgId);
  const updateMember = useUpdateMember(orgId);

  const [showInvite, setShowInvite] = useState(false);
  const [email, setEmail] = useState("");
  const [memberRole, setMemberRole] = useState("org_driver");
  const [error, setError] = useState<string | null>(null);
  const [inviteResult, setInviteResult] = useState<string | null>(null);

  async function onInvite() {
    setError(null);
    setInviteResult(null);
    try {
      const created = await invite.mutateAsync({ email: email.trim(), role: memberRole });
      const accountSent =
        (created as unknown as { account_invitation_sent?: boolean })
          .account_invitation_sent;
      setInviteResult(
        accountSent
          ? "Member added. Account setup email sent."
          : "Member added. Organization invitation sent.",
      );
      setShowInvite(false);
      setEmail("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Invite failed");
    }
  }

  async function onRoleChange(userId: string, nextRole: string) {
    try {
      await updateMember.mutateAsync({ userId, role: nextRole });
    } catch {
      // ignore — list refetches on success
    }
  }

  async function onRemove(userId: string) {
    try {
      await updateMember.mutateAsync({ userId, remove: true });
    } catch {
      // ignore
    }
  }

  const members = data?.items ?? [];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Members"
        description="Invite managers, mechanics, and drivers; manage roles"
        actions={
          isAdmin ? <Button onClick={() => setShowInvite(true)}>Invite member</Button> : null
        }
      />

      {inviteResult ? (
        <Card className="p-4 text-sm text-success">{inviteResult}</Card>
      ) : null}

      <Card>
        {isLoading ? (
          <div className="p-5">
            <SkeletonTable rows={4} cols={4} />
          </div>
        ) : members.length === 0 ? (
          <EmptyState title="No members" description="Invite your organization team." />
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Member</TableHeadCell>
                <TableHeadCell>Role</TableHeadCell>
                <TableHeadCell>Badge</TableHeadCell>
                <TableHeadCell />
              </TableRow>
            </TableHead>
            <TableBody>
              {members.map((member) => (
                <TableRow key={member.user_id}>
                  <TableCell>
                    <p className="text-ink">{member.display_name || "—"}</p>
                    <p className="text-xs text-ink-caption">{member.email}</p>
                  </TableCell>
                  <TableCell>
                    {isAdmin && member.role !== "org_admin" ? (
                      <select
                        aria-label={`Role for ${member.email}`}
                        className="h-8 rounded-sm border border-line-strong bg-field px-2 text-xs text-ink"
                        value={member.role}
                        onChange={(e) => void onRoleChange(member.user_id, e.target.value)}
                      >
                        {assignableRoles.map((r) => (
                          <option key={r.value} value={r.value}>
                            {r.label}
                          </option>
                        ))}
                      </select>
                    ) : (
                      orgRoleLabel[member.role] ?? member.role
                    )}
                  </TableCell>
                  <TableCell>
                    <Badge tone={member.role === "org_admin" ? "info" : "neutral"}>
                      {orgRoleLabel[member.role] ?? member.role}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-right">
                    {isAdmin && member.role !== "org_admin" && member.user_id !== user?.id ? (
                      <Button
                        size="sm"
                        variant="destructive"
                        onClick={() => void onRemove(member.user_id)}
                        disabled={updateMember.isPending}
                      >
                        Remove
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
        open={showInvite}
        onClose={() => setShowInvite(false)}
        title="Invite member"
        confirmLabel="Send invite"
        loading={invite.isPending}
        onSubmit={() => void onInvite()}
      >
        <div className="flex flex-col gap-3">
          <Input
            label="Email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
          <Select
            label="Role"
            options={assignableRoles}
            value={memberRole}
            onChange={setMemberRole}
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
