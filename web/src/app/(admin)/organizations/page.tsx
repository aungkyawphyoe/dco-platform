"use client";

import { useCallback, useState } from "react";
import Link from "next/link";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Button } from "@dco/ui/components/button";
import { Select } from "@dco/ui/components/select";
import { EmptyState } from "@dco/ui/components/empty-state";
import { SearchInput } from "@dco/ui/components/search-input";
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
import {
  OrganizationStatusBadge,
  OrganizationTypeBadge,
} from "@/components/ui/status-badge";
import { useAdminOrganizations } from "@/lib/api/hooks";
import { formatDate } from "@dco/ui/lib/format";

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
  const filtered = Boolean(debouncedQ || status);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Organizations"
        meta={
          organizations.length
            ? filtered
              ? `${organizations.length} matching organizations`
              : `${organizations.length} organizations`
            : undefined
        }
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
              filtered
                ? "Try adjusting your search or filter."
                : "No Enterprise organizations provisioned yet."
            }
            action={
              !filtered ? (
                <Link href="/organizations/new">
                  <Button size="sm">New organization</Button>
                </Link>
              ) : null
            }
          />
        </Card>
      ) : (
        <Card>
          <SectionHeading title="Organizations" count={organizations.length} />
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
                      className="font-medium text-ink transition-colors hover:text-gold"
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
                  <TableCell className="font-mono text-xs text-ink-caption">
                    {formatDate(organization.created_at)}
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
