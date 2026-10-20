"use client";

import { useCallback, useState } from "react";
import Link from "next/link";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Button } from "@dco/ui/components/button";
import { EmptyState } from "@dco/ui/components/empty-state";
import { SearchInput } from "@dco/ui/components/search-input";
import { Select } from "@dco/ui/components/select";
import { SectionHeading } from "@dco/ui/components/section-heading";
import {
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableHeadCell,
  TableCell,
} from "@dco/ui/components/table";
import { SkeletonTable } from "@dco/ui/components/skeleton";
import { UserStatusBadge, PlanBadge } from "@/components/ui/status-badge";
import { useAdminUsers } from "@/lib/api/hooks";
import { formatDate } from "@dco/ui/lib/format";

export default function UsersPage() {
  const [q, setQ] = useState("");
  const [status, setStatus] = useState("");
  const [debouncedQ, setDebouncedQ] = useState("");

  const handleSearch = useCallback((val: string) => setDebouncedQ(val), []);

  const { data, isLoading, error } = useAdminUsers({
    q: debouncedQ || undefined,
    status: status || undefined,
  });

  const users = data?.items ?? [];
  const filtered = Boolean(debouncedQ || status);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Users"
        meta={
          users.length
            ? filtered
              ? `${users.length} matching accounts`
              : `${users.length} accounts`
            : undefined
        }
        description="Search, view, and support owner accounts"
        actions={
          <Link href="/users/new">
            <Button size="sm">Create user</Button>
          </Link>
        }
      />

      <div className="flex flex-wrap items-end gap-3">
        <SearchInput
          value={q}
          onChange={(val) => {
            setQ(val);
            handleSearch(val);
          }}
          placeholder="Search by email, name, or phone..."
          className="w-72"
        />
        <Select
          label="Status"
          placeholder="All statuses"
          options={[
            { value: "active", label: "Active" },
            { value: "deactivated", label: "Deactivated" },
          ]}
          value={status}
          onChange={setStatus}
          className="w-44"
        />
      </div>

      {error ? (
        <Card className="p-6">
          <p className="text-sm text-danger">
            Failed to load users. Please try again.
          </p>
        </Card>
      ) : isLoading ? (
        <Card className="p-5">
          <SkeletonTable rows={5} cols={6} />
        </Card>
      ) : users.length === 0 ? (
        <Card>
          <EmptyState
            title="No users found"
            description={
              filtered
                ? "Try adjusting your search or filter."
                : "No user accounts yet."
            }
            action={
              !filtered ? (
                <Link href="/users/new">
                  <Button size="sm">Create user</Button>
                </Link>
              ) : null
            }
          />
        </Card>
      ) : (
        <Card>
          <SectionHeading title="Accounts" count={users.length} />
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Email</TableHeadCell>
                <TableHeadCell>Name</TableHeadCell>
                <TableHeadCell>Phone</TableHeadCell>
                <TableHeadCell>Plan</TableHeadCell>
                <TableHeadCell>Status</TableHeadCell>
                <TableHeadCell>Vehicles</TableHeadCell>
                <TableHeadCell>Joined</TableHeadCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {users.map((user) => (
                <TableRow key={user.id}>
                  <TableCell>
                    <Link
                      href={`/users/${user.id}`}
                      className="font-medium text-ink transition-colors hover:text-gold"
                    >
                      {user.email}
                    </Link>
                  </TableCell>
                  <TableCell className="text-ink-muted">
                    {user.display_name ?? "—"}
                  </TableCell>
                  <TableCell className="font-mono text-xs text-ink-muted">
                    {user.contact_phone ?? "—"}
                  </TableCell>
                  <TableCell>
                    <PlanBadge plan={user.plan} />
                  </TableCell>
                  <TableCell>
                    <UserStatusBadge status={user.status} />
                  </TableCell>
                  <TableCell className="font-mono text-xs">
                    {user.vehicle_count ?? 0}
                  </TableCell>
                  <TableCell className="font-mono text-xs text-ink-caption">
                    {user.created_at ? formatDate(user.created_at) : "—"}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </Card>
      )}
    </div>
  );
}
