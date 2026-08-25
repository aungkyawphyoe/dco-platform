"use client";

import { use, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { useAdminPartner, useUpdatePartner } from "@/lib/api/hooks";

export default function EditPartnerPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const router = useRouter();
  const { data: partner, isLoading, error } = useAdminPartner(id);
  const update = useUpdatePartner();

  const [name, setName] = useState("");
  const [type, setType] = useState<"workshop" | "insurer" | "">("");
  const [status, setStatus] = useState("");
  const [contactEmail, setContactEmail] = useState("");
  const [contactPhone, setContactPhone] = useState("");
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState<{ name?: string; type?: string }>({});
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (partner) {
      setName(partner.name ?? "");
      setType(partner.type ?? "");
      setStatus(partner.status ?? "");
      setContactEmail(partner.contact_email ?? "");
      setContactPhone(partner.contact_phone ?? "");
      setNotes(partner.notes ?? "");
    }
  }, [partner]);

  if (isLoading) {
    return (
      <div className="flex flex-col gap-6">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-96 max-w-xl rounded-lg" />
      </div>
    );
  }

  if (error || !partner) {
    return (
      <div className="flex flex-col gap-6">
        <PageHeader title="Edit partner" />
        <Card className="p-6">
          <p className="text-sm text-danger">
            Failed to load partner.{" "}
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

  function validate() {
    const e: typeof errors = {};
    if (!name.trim()) e.name = "Name is required.";
    if (!type) e.type = "Type is required.";
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!validate()) return;
    setSaved(false);

    update.mutate(
      {
        id,
        name: name.trim(),
        type: type as "workshop" | "insurer",
        status: (status as "draft" | "pending_verification" | "verified" | "rejected") || undefined,
        contact_email: contactEmail || undefined,
        contact_phone: contactPhone || undefined,
        notes: notes || undefined,
      },
      {
        onSuccess: () => setSaved(true),
      },
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={partner.name}
        description="Update record and verification status"
      />

      {saved && (
        <div className="rounded-md bg-success-dim px-4 py-3 text-sm text-success">
          Partner updated.
        </div>
      )}

      <Card className="max-w-xl p-6">
        <form onSubmit={handleSubmit} className="flex flex-col gap-5">
          <Input
            label="Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            error={errors.name}
            maxLength={120}
            required
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
            placeholder="Select status..."
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
          />

          <Input
            label="Contact phone"
            type="tel"
            value={contactPhone}
            onChange={(e) => setContactPhone(e.target.value)}
          />

          <Input
            label="Notes"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
          />

          {update.isError && (
            <p className="text-sm text-danger">
              {(update.error as Error)?.message ?? "Failed to update partner."}
            </p>
          )}

          <div className="flex gap-3 pt-2">
            <Link href="/partners">
              <Button type="button" variant="secondary" size="sm">
                Cancel
              </Button>
            </Link>
            <Button
              type="submit"
              size="sm"
              disabled={update.isPending}
            >
              {update.isPending ? "Saving..." : "Save changes"}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
