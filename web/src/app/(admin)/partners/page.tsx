"use client";

import { useCallback, useState } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { EmptyState } from "@/components/ui/empty-state";
import { SearchInput } from "@/components/ui/search-input";
import { Modal } from "@/components/ui/modal";
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
  PartnerStatusBadge,
  PartnerTypeBadge,
} from "@/components/ui/status-badge";
import { useAdminPartners, useCreatePartner } from "@/lib/api/hooks";

export default function PartnersPage() {
  const [q, setQ] = useState("");
  const [type, setType] = useState("");
  const [status, setStatus] = useState("");
  const [debouncedQ, setDebouncedQ] = useState("");
  const [showCreate, setShowCreate] = useState(false);

  const handleSearch = useCallback((val: string) => setDebouncedQ(val), []);

  const { data, isLoading, error } = useAdminPartners({
    q: debouncedQ || undefined,
    type: type || undefined,
    status: status || undefined,
  });

  const partners = data?.items ?? [];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Partners"
        description="Workshops and insurers onboarding records"
        actions={
          <Button size="sm" onClick={() => setShowCreate(true)}>
            Add partner
          </Button>
        }
      />

      <div className="flex flex-wrap items-end gap-3">
        <SearchInput
          value={q}
          onChange={(val) => {
            setQ(val);
            handleSearch(val);
          }}
          placeholder="Search partners..."
          className="w-72"
        />
        <Select
          label="Type"
          placeholder="All types"
          options={[
            { value: "workshop", label: "Workshop" },
            { value: "insurer", label: "Insurer" },
          ]}
          value={type}
          onChange={setType}
          className="w-40"
        />
        <Select
          label="Status"
          placeholder="All statuses"
          options={[
            { value: "draft", label: "Draft" },
            { value: "pending_verification", label: "Pending" },
            { value: "verified", label: "Verified" },
            { value: "rejected", label: "Rejected" },
          ]}
          value={status}
          onChange={setStatus}
          className="w-44"
        />
      </div>

      {error ? (
        <Card className="p-6">
          <p className="text-sm text-danger">
            Failed to load partners. Please try again.
          </p>
        </Card>
      ) : isLoading ? (
        <Card className="p-5">
          <SkeletonTable rows={5} cols={6} />
        </Card>
      ) : partners.length === 0 ? (
        <Card>
          <EmptyState
            title="No partners found"
            description={
              debouncedQ || type || status
                ? "Try adjusting your search or filter."
                : "No partners registered yet."
            }
            action={
              <Button size="sm" onClick={() => setShowCreate(true)}>
                Add partner
              </Button>
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
                <TableHeadCell>Email</TableHeadCell>
                <TableHeadCell>Phone</TableHeadCell>
                <TableHeadCell>Updated</TableHeadCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {partners.map((partner) => (
                <TableRow key={partner.id}>
                  <TableCell>
                    <span className="text-gold">{partner.name}</span>
                  </TableCell>
                  <TableCell>
                    <PartnerTypeBadge type={partner.type} />
                  </TableCell>
                  <TableCell>
                    <PartnerStatusBadge status={partner.status} />
                  </TableCell>
                  <TableCell className="text-ink-muted">
                    {partner.contact_email ?? "—"}
                  </TableCell>
                  <TableCell className="text-ink-muted">
                    {partner.contact_phone ?? "—"}
                  </TableCell>
                  <TableCell className="text-ink-caption">
                    {partner.updated_at
                      ? new Intl.DateTimeFormat("en-US", {
                          month: "short",
                          day: "numeric",
                          year: "numeric",
                        }).format(new Date(partner.updated_at))
                      : "—"}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </Card>
      )}

      <CreatePartnerDialog
        open={showCreate}
        onClose={() => setShowCreate(false)}
      />
    </div>
  );
}

function CreatePartnerDialog({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const create = useCreatePartner();

  const [name, setName] = useState("");
  const [type, setType] = useState<"workshop" | "insurer" | "">("");
  const [status, setStatus] = useState("");
  const [contactEmail, setContactEmail] = useState("");
  const [contactPhone, setContactPhone] = useState("");
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState<{ name?: string; type?: string }>({});

  function reset() {
    setName("");
    setType("");
    setStatus("");
    setContactEmail("");
    setContactPhone("");
    setNotes("");
    setErrors({});
  }

  function handleClose() {
    reset();
    onClose();
  }

  function validate() {
    const e: typeof errors = {};
    if (!name.trim()) e.name = "Name is required.";
    if (!type) e.type = "Type is required.";
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  function handleSubmit() {
    if (!validate()) return;

    create.mutate(
      {
        name: name.trim(),
        type: type as "workshop" | "insurer",
        status:
          (status as
            | "draft"
            | "pending_verification"
            | "verified"
            | "rejected") || undefined,
        contact_email: contactEmail || undefined,
        contact_phone: contactPhone || undefined,
        notes: notes || undefined,
      },
      {
        onSuccess: () => {
          reset();
          onClose();
        },
      },
    );
  }

  return (
    <Modal
      open={open}
      onClose={handleClose}
      title="Add partner"
      confirmLabel="Create"
      loading={create.isPending}
      onSubmit={handleSubmit}
    >
      <div className="flex flex-col gap-4">
        <Input
          label="Name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          error={errors.name}
          placeholder="e.g. Acme Workshop"
          maxLength={120}
        />
        <Select
          label="Type"
          placeholder="Select type..."
          options={[
            { value: "workshop", label: "Workshop" },
            { value: "insurer", label: "Insurer" },
          ]}
          value={type}
          onChange={(v) => setType(v as "workshop" | "insurer")}
        />
        {errors.type && (
          <p className="text-xs text-danger">{errors.type}</p>
        )}
        <Select
          label="Status"
          placeholder="Draft (default)"
          options={[
            { value: "draft", label: "Draft" },
            { value: "pending_verification", label: "Pending verification" },
            { value: "verified", label: "Verified" },
            { value: "rejected", label: "Rejected" },
          ]}
          value={status}
          onChange={setStatus}
        />
        <Input
          label="Contact email"
          type="email"
          value={contactEmail}
          onChange={(e) => setContactEmail(e.target.value)}
          placeholder="optional"
        />
        <Input
          label="Contact phone"
          type="tel"
          value={contactPhone}
          onChange={(e) => setContactPhone(e.target.value)}
          placeholder="optional"
        />
        <Input
          label="Notes"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="optional"
        />
        {create.isError && (
          <p className="text-sm text-danger">
            {(create.error as Error)?.message ?? "Failed to create partner."}
          </p>
        )}
      </div>
    </Modal>
  );
}
