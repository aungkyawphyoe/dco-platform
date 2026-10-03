"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { useCreateOrganization } from "@/lib/api/hooks";

const ORGANIZATION_TYPES = [
  { value: "showroom", label: "Showroom" },
  { value: "dealership", label: "Dealership" },
  { value: "taxi_fleet", label: "Taxi fleet" },
  { value: "rental", label: "Rental" },
  { value: "commercial", label: "Commercial" },
  { value: "logistics", label: "Logistics" },
] as const;

type OrganizationType = (typeof ORGANIZATION_TYPES)[number]["value"];

export default function NewOrganizationPage() {
  const router = useRouter();
  const create = useCreateOrganization();

  const [name, setName] = useState("");
  const [type, setType] = useState<OrganizationType | "">("");
  const [adminEmail, setAdminEmail] = useState("");
  const [adminPassword, setAdminPassword] = useState("");
  const [contactEmail, setContactEmail] = useState("");
  const [contactPhone, setContactPhone] = useState("");
  const [errors, setErrors] = useState<{
    name?: string;
    type?: string;
    adminEmail?: string;
    adminPassword?: string;
  }>({});

  function validate() {
    const e: typeof errors = {};
    if (!name.trim()) e.name = "Name is required.";
    else if (name.trim().length > 200) e.name = "Name must be 200 characters or fewer.";
    if (!type) e.type = "Type is required.";
    if (!adminEmail.trim()) {
      e.adminEmail = "Org Admin email is required.";
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(adminEmail.trim())) {
      e.adminEmail = "Enter a valid email address.";
    }
    // Password is only required if no account exists — server validates this
    if (adminPassword && adminPassword.length < 8) {
      e.adminPassword = "Temporary password must be at least 8 characters.";
    }
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!validate()) return;

    create.mutate(
      {
        name: name.trim(),
        type: type as OrganizationType,
        admin_email: adminEmail.trim(),
        admin_password: adminPassword || undefined,
        contact_email: contactEmail.trim() || undefined,
        contact_phone: contactPhone.trim() || undefined,
      },
      {
        onSuccess: (data) => router.push(`/organizations/${data.id}`),
      },
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="New organization"
        description="Provision an Enterprise organization and invite its Org Admin"
      />

      <Card className="max-w-xl p-6">
        <form onSubmit={handleSubmit} className="flex flex-col gap-5">
          <Input
            label="Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            error={errors.name}
            placeholder="e.g. Acme Motors"
            maxLength={200}
            required
          />

          <Select
            label="Type"
            placeholder="Select type..."
            options={ORGANIZATION_TYPES.map((option) => ({ ...option }))}
            value={type}
            onChange={(v) => setType(v as OrganizationType)}
          />
          {errors.type && (
            <p className="text-xs text-danger">{errors.type}</p>
          )}

          <Input
            label="Org Admin email"
            type="email"
            value={adminEmail}
            onChange={(e) => setAdminEmail(e.target.value)}
            error={errors.adminEmail}
            placeholder="owner@example.com"
            maxLength={254}
            required
          />
          <p className="text-xs text-ink-caption">
            The organization starts as <strong>pending</strong>. This email is
            linked as Org Admin — an owner account is invited if none exists.
            Activate the organization to grant Fleet access.
          </p>

          <Input
            label="Temporary password (optional)"
            type="password"
            value={adminPassword}
            onChange={(e) => setAdminPassword(e.target.value)}
            error={errors.adminPassword}
            placeholder="Leave blank to send invitation email"
            minLength={8}
          />
          <p className="text-xs text-ink-caption">
            If an account already exists for this email, the password is ignored
            and an invitation is sent. If no account exists, a new account is
            created with this temporary password (must be changed on first login).
          </p>

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
            maxLength={20}
          />

          {create.isError && (
            <p className="text-sm text-danger">
              {(create.error as Error)?.message ?? "Failed to create organization."}
            </p>
          )}

          <div className="flex gap-3 pt-2">
            <Link href="/organizations">
              <Button type="button" variant="secondary" size="sm">
                Cancel
              </Button>
            </Link>
            <Button
              type="submit"
              size="sm"
              disabled={create.isPending}
            >
              {create.isPending ? "Creating..." : "Create organization"}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
