"use client";

import { useCallback, useState } from "react";
import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { SearchInput } from "@/components/ui/search-input";
import { Select } from "@/components/ui/select";
import {
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableHeadCell,
  TableCell,
} from "@/components/ui/table";
import { SkeletonTable } from "@/components/ui/skeleton";
import { UserStatusBadge, PlanBadge } from "@/components/ui/status-badge";
import { useAdminUsers } from "@/lib/api/hooks";

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

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Users"
        description="Search, view, and support owner accounts"
      />

      <div className="flex flex-wrap items-end gap-3">
        <SearchInput
          value={q}
          onChange={(val) => {
            setQ(val);
            handleSearch(val);
          }}
          placeholder="Search by email or name..."
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
              debouncedQ || status
                ? "Try adjusting your search or filter."
                : "No user accounts yet."
            }
          />
        </Card>
      ) : (
        <Card>
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Email</TableHeadCell>
                <TableHeadCell>Name</TableHeadCell>
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
                      className="text-gold hover:underline"
                    >
                      {user.email}
                    </Link>
                  </TableCell>
                  <TableCell className="text-ink-muted">
                    {user.display_name ?? "—"}
                  </TableCell>
                  <TableCell>
                    <PlanBadge plan={user.plan} />
                  </TableCell>
                  <TableCell>
                    <UserStatusBadge status={user.status} />
                  </TableCell>
                  <TableCell>{user.vehicle_count ?? 0}</TableCell>
                  <TableCell className="text-ink-caption">
                    {user.created_at
                      ? new Intl.DateTimeFormat("en-US", {
                          month: "short",
                          day: "numeric",
                          year: "numeric",
                        }).format(new Date(user.created_at))
                      : "—"}
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
