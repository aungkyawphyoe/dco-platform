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
import { InstrumentBand } from "@/components/ui/instrument-band";
import { SectionHeading } from "@/components/ui/section-heading";
import { Stat } from "@/components/ui/stat";
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
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [inviteResult, setInviteResult] = useState<string | null>(null);
  const [provisioned, setProvisioned] = useState<{ email: string; password: string } | null>(null);

  async function onInvite() {
    setError(null);
    setInviteResult(null);
    setProvisioned(null);
    const trimmedPassword = password.trim();
    if (trimmedPassword && trimmedPassword.length < 8) {
      setError("Temporary password must be at least 8 characters.");
      return;
    }
    try {
      const created = await invite.mutateAsync({
        email: email.trim(),
        role: memberRole,
        ...(trimmedPassword ? { temporary_password: trimmedPassword } : {}),
      });
      setShowInvite(false);
      setEmail("");
      setPassword("");
      if (created.account_created && created.temporary_password) {
        setProvisioned({ email: created.email, password: created.temporary_password });
      } else {
        setInviteResult("Member added. Existing account linked to the organization.");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Add member failed");
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
  const countByRole = (target: string) => members.filter((m) => m.role === target).length;

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Members"
        meta={members.length ? `${members.length} people in this organization` : undefined}
        description="Add managers, mechanics, and drivers; manage roles"
        actions={isAdmin ? <Button onClick={() => setShowInvite(true)}>Add member</Button> : null}
      />

      {inviteResult ? (
        <Card className="p-4 text-sm text-success">{inviteResult}</Card>
      ) : null}

      <InstrumentBand>
        <div className="grid grid-cols-2 gap-4 p-5 sm:grid-cols-4">
          <Stat label="Admins" value={countByRole("org_admin").toLocaleString()} />
          <Stat label="Managers" value={countByRole("org_manager").toLocaleString()} />
          <Stat label="Mechanics" value={countByRole("org_mechanic").toLocaleString()} />
          <Stat label="Drivers" value={countByRole("org_driver").toLocaleString()} />
        </div>
      </InstrumentBand>

      <Card>
        <SectionHeading title="Team" count={members.length} />
        {isLoading ? (
          <div className="p-5">
            <SkeletonTable rows={4} cols={3} />
          </div>
        ) : members.length === 0 ? (
          <EmptyState title="No members" description="Invite your organization team." />
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Member</TableHeadCell>
                <TableHeadCell>Role</TableHeadCell>
                <TableHeadCell />
              </TableRow>
            </TableHead>
            <TableBody>
              {members.map((member) => (
                <TableRow key={member.user_id}>
                  <TableCell>
                    <p className="text-ink">
                      {member.display_name || "—"}
                      {member.user_id === user?.id ? (
                        <span className="ml-2 text-xs text-ink-caption">You</span>
                      ) : null}
                    </p>
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
                      <Badge tone={member.role === "org_admin" ? "info" : "neutral"}>
                        {orgRoleLabel[member.role] ?? member.role}
                      </Badge>
                    )}
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
        onClose={() => {
          setShowInvite(false);
          setError(null);
          setPassword("");
        }}
        title="Add member"
        confirmLabel="Add member"
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
          <Input
            label="Temporary password (optional)"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Leave blank to auto-generate"
            minLength={8}
            maxLength={128}
            hint="Used only when this email has no account yet. The password is shown once after adding, and no email is sent."
          />
          {error ? (
            <p className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">{error}</p>
          ) : null}
        </div>
      </Modal>

      <Modal
        open={provisioned !== null}
        onClose={() => setProvisioned(null)}
        title="Member added"
        confirmLabel="Done"
        onConfirm={() => setProvisioned(null)}
      >
        <div className="flex flex-col gap-3">
          <p>
            Account created for <strong>{provisioned?.email}</strong>.
          </p>
          <p>
            Share this temporary password with the member. No email is sent. They must change it on
            first sign-in.
          </p>
          <div className="break-all rounded-md bg-field p-3 font-mono text-sm text-ink">
            {provisioned?.password}
          </div>
          <p className="text-xs text-ink-caption">
            Copy this password now. It will not be shown again.
          </p>
        </div>
      </Modal>
    </div>
  );
}
