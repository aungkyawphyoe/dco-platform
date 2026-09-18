"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";
import { useCreateUser } from "@/lib/api/hooks";

export default function NewUserPage() {
  const router = useRouter();
  const create = useCreateUser();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [role, setRole] = useState<"owner" | "admin">("owner");
  const [plan, setPlan] = useState<"free" | "premium">("free");
  const [errors, setErrors] = useState<{
    email?: string;
    password?: string;
  }>({});
  const [showCreatedModal, setShowCreatedModal] = useState(false);
  const [createdPassword, setCreatedPassword] = useState("");

  function validate() {
    const e: typeof errors = {};
    if (!email.trim()) e.email = "Email is required.";
    if (!/\S+@\S+\.\S+/.test(email)) e.email = "Invalid email format.";
    if (!password) e.password = "Password is required.";
    if (password.length < 8) e.password = "Password must be at least 8 characters.";
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!validate()) return;

    create.mutate(
      {
        email: email.trim().toLowerCase(),
        temporary_password: password,
        display_name: displayName || undefined,
        role,
        plan,
      },
      {
        onSuccess: () => {
          setCreatedPassword(password);
          setShowCreatedModal(true);
        },
      },
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Create user"
        description="Create a new user account with a temporary password"
      />

      <Card className="max-w-xl p-6">
        <form onSubmit={handleSubmit} className="flex flex-col gap-5">
          <Input
            label="Email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            error={errors.email}
            placeholder="user@example.com"
            maxLength={254}
            required
          />

          <Input
            label="Temporary password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            error={errors.password}
            placeholder="Min 8 characters"
            minLength={8}
            required
          />

          <Input
            label="Display name"
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            placeholder="Optional"
            maxLength={50}
          />

          <Select
            label="Role"
            placeholder="Owner (default)"
            options={[
              { value: "owner", label: "Owner" },
              { value: "admin", label: "Admin" },
            ]}
            value={role}
            onChange={(v) => setRole(v as "owner" | "admin")}
          />

          <Select
            label="Plan"
            placeholder="Free (default)"
            options={[
              { value: "free", label: "Free" },
              { value: "premium", label: "Premium" },
            ]}
            value={plan}
            onChange={(v) => setPlan(v as "free" | "premium")}
          />

          {create.isError && (
            <p className="text-sm text-danger">
              {(create.error as Error)?.message ?? "Failed to create user."}
            </p>
          )}

          <div className="flex gap-3 pt-2">
            <Link href="/users">
              <Button type="button" variant="secondary" size="sm">
                Cancel
              </Button>
            </Link>
            <Button
              type="submit"
              size="sm"
              disabled={create.isPending}
            >
              {create.isPending ? "Creating..." : "Create user"}
            </Button>
          </div>
        </form>
      </Card>

      <Modal
        open={showCreatedModal}
        onClose={() => {
          setShowCreatedModal(false);
          router.push("/users");
        }}
        title="User created"
        confirmLabel="Done"
        onConfirm={() => {
          setShowCreatedModal(false);
          router.push("/users");
        }}
      >
        <div className="flex flex-col gap-3">
          <p>
            Account created for <strong>{email}</strong>.
          </p>
          <p>
            Share this temporary password with the user. They will need to
            change it on first login.
          </p>
          <div className="rounded-md bg-field p-3 font-mono text-sm text-ink">
            {createdPassword}
          </div>
          <p className="text-xs text-ink-caption">
            Copy this password now. It will not be shown again.
          </p>
        </div>
      </Modal>
    </div>
  );
}
