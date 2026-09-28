"use client";

import { useCallback, useState } from "react";
import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { EmptyState } from "@/components/ui/empty-state";
import { SearchInput } from "@/components/ui/search-input";
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
  OrganizationStatusBadge,
  OrganizationTypeBadge,
} from "@/components/ui/status-badge";
import { useAdminOrganizations } from "@/lib/api/hooks";

export default function OrganizationsPage() {
  const [q, setQ] = useState("");
  const [status, setStatus] = useState("");
  const [debouncedQ, setDebouncedQ] = useState("");

  const handleSearch = useCallback((val: string) => setDebouncedQ(val), []);

  const { data, isLoading, error } = useAdminOrganizations({
    q: debouncedQ || undefined,
    status: status || undefined,
  });

  const organizations = data?.items ?? [];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Organizations"
        description="Enterprise fleet organizations and their Org Admin accounts"
        actions={
          <Link href="/organizations/new">
            <Button size="sm">New organization</Button>
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
          placeholder="Search by name or contact email..."
          className="w-72"
        />
        <Select
          label="Status"
          placeholder="All statuses"
          options={[
            { value: "pending", label: "Pending" },
            { value: "active", label: "Active" },
            { value: "suspended", label: "Suspended" },
            { value: "archived", label: "Archived" },
          ]}
          value={status}
          onChange={setStatus}
          className="w-44"
        />
      </div>

      {error ? (
        <Card className="p-6">
          <p className="text-sm text-danger">
            Failed to load organizations. Please try again.
          </p>
        </Card>
      ) : isLoading ? (
        <Card className="p-5">
          <SkeletonTable rows={5} cols={6} />
        </Card>
      ) : organizations.length === 0 ? (
        <Card>
          <EmptyState
            title="No organizations found"
            description={
              debouncedQ || status
                ? "Try adjusting your search or filter."
                : "No Enterprise organizations provisioned yet."
            }
            action={
              <Link href="/organizations/new">
                <Button size="sm">New organization</Button>
              </Link>
            }
          />
        </Card>
      ) : (
        <Card>
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Name</TableHeadCell>
                <TableHeadCell>Type</TableHeadCell>
                <TableHeadCell>Status</TableHeadCell>
                <TableHeadCell>Org Admin</TableHeadCell>
                <TableHeadCell>Contact</TableHeadCell>
                <TableHeadCell>Created</TableHeadCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {organizations.map((organization) => (
                <TableRow key={organization.id}>
                  <TableCell>
                    <Link
                      href={`/organizations/${organization.id}`}
                      className="text-gold hover:underline"
                    >
                      {organization.name}
                    </Link>
                  </TableCell>
                  <TableCell>
                    <OrganizationTypeBadge type={organization.type} />
                  </TableCell>
                  <TableCell>
                    <OrganizationStatusBadge status={organization.status} />
                  </TableCell>
                  <TableCell className="text-ink-muted">
                    {organization.admin_email ?? "—"}
                  </TableCell>
                  <TableCell className="text-ink-muted">
                    {organization.contact_email ?? "—"}
                  </TableCell>
                  <TableCell className="text-ink-caption">
                    {new Intl.DateTimeFormat("en-US", {
                      month: "short",
                      day: "numeric",
                      year: "numeric",
                    }).format(new Date(organization.created_at))}
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
