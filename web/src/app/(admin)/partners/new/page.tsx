"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { useCreatePartner } from "@/lib/api/hooks";

export default function NewPartnerPage() {
  const router = useRouter();
  const create = useCreatePartner();

  const [name, setName] = useState("");
  const [type, setType] = useState<"workshop" | "insurer" | "">("");
  const [status, setStatus] = useState("");
  const [contactEmail, setContactEmail] = useState("");
  const [contactPhone, setContactPhone] = useState("");
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState<{ name?: string; type?: string }>({});

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

    create.mutate(
      {
        name: name.trim(),
        type: type as "workshop" | "insurer",
        status: (status as "draft" | "pending_verification" | "verified" | "rejected") || undefined,
        contact_email: contactEmail || undefined,
        contact_phone: contactPhone || undefined,
        notes: notes || undefined,
      },
      {
        onSuccess: () => router.push("/partners"),
      },
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="New partner"
        description="Register a workshop or insurer"
      />

      <Card className="max-w-xl p-6">
        <form onSubmit={handleSubmit} className="flex flex-col gap-5">
          <Input
            label="Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            error={errors.name}
            placeholder="e.g. Acme Workshop"
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

          <div className="flex gap-3 pt-2">
            <Link href="/partners">
              <Button type="button" variant="secondary" size="sm">
                Cancel
              </Button>
            </Link>
            <Button
              type="submit"
              size="sm"
              disabled={create.isPending}
            >
              {create.isPending ? "Creating..." : "Create partner"}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
