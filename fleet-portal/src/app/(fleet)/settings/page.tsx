"use client";

import { useState } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { useLemons, useUpdateLemonThreshold } from "@/lib/api/hooks";
import { orgRoleLabel } from "@/lib/api/types";
import { useOrgId, useOrgRole, useSession } from "@/lib/auth/session-context";

export default function SettingsPage() {
  const { org } = useSession();
  const orgId = useOrgId();
  const role = useOrgRole();
  const isAdmin = role === "org_admin";
  const { data: lemons } = useLemons(orgId);
  const updateThreshold = useUpdateLemonThreshold(orgId);

  const [mode, setMode] = useState<"multiplier" | "absolute">("multiplier");
  const [value, setValue] = useState("1.5");
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const organization = org?.organization;

  async function onSaveThreshold() {
    setMessage(null);
    setError(null);
    const num = Number(value);
    if (!Number.isFinite(num) || num < 0) {
      setError("Enter a valid number");
      return;
    }
    try {
      await updateThreshold.mutateAsync(
        mode === "multiplier" ? { multiplier: num } : { absolute_cost_per_km: num },
      );
      setMessage("Lemon threshold updated");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Update failed");
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Org Settings"
        description="Organization profile and lemon threshold configuration"
      />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card className="p-5">
          <div className="flex items-center justify-between">
            <h2 className="font-display text-base font-semibold text-ink">
              Organization
            </h2>
            <Badge tone="info">{organization?.status ?? "—"}</Badge>
          </div>
          <dl className="mt-4 grid grid-cols-2 gap-y-3 text-sm">
            <dt className="text-ink-caption">Name</dt>
            <dd className="text-ink">{organization?.name ?? "—"}</dd>
            <dt className="text-ink-caption">Type</dt>
            <dd className="text-ink">{organization?.type ?? "—"}</dd>
            <dt className="text-ink-caption">Plan</dt>
            <dd className="text-ink">{organization?.plan ?? "—"}</dd>
            <dt className="text-ink-caption">Contact email</dt>
            <dd className="text-ink">{organization?.contact_email ?? "—"}</dd>
            <dt className="text-ink-caption">Contact phone</dt>
            <dd className="text-ink">{organization?.contact_phone ?? "—"}</dd>
            <dt className="text-ink-caption">Your role</dt>
            <dd className="text-ink">
              {orgRoleLabel[organization?.role ?? ""] ?? organization?.role ?? "—"}
            </dd>
          </dl>
          <p className="mt-4 text-xs text-ink-caption">
            Contact details are managed by DCO Admin for this MVP.
          </p>
        </Card>

        <Card className="p-5">
          <h2 className="font-display text-base font-semibold text-ink">
            Lemon threshold
          </h2>
          <p className="mt-1 text-sm text-ink-caption">
            Current threshold:{" "}
            {lemons ? `${lemons.threshold_cost_per_km.toFixed(3)} €/km` : "—"}
          </p>

          {isAdmin ? (
            <div className="mt-4 flex flex-col gap-3">
              <Select
                label="Mode"
                options={[
                  { value: "multiplier", label: "Multiplier of fleet average" },
                  { value: "absolute", label: "Absolute €/km" },
                ]}
                value={mode}
                onChange={(v) => setMode(v as "multiplier" | "absolute")}
              />
              <Input
                label={mode === "multiplier" ? "Multiplier" : "Cost per km (€)"}
                type="number"
                step={mode === "multiplier" ? "0.1" : "0.001"}
                min={mode === "multiplier" ? 1 : 0}
                value={value}
                onChange={(e) => setValue(e.target.value)}
              />
              {message ? (
                <p className="rounded-md bg-success-dim px-3 py-2 text-sm text-success">
                  {message}
                </p>
              ) : null}
              {error ? (
                <p className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">
                  {error}
                </p>
              ) : null}
              <Button
                className="self-start"
                size="sm"
                disabled={updateThreshold.isPending}
                onClick={() => void onSaveThreshold()}
              >
                {updateThreshold.isPending ? "Saving…" : "Save threshold"}
              </Button>
            </div>
          ) : (
            <p className="mt-4 text-sm text-ink-caption">
              Only the Org Admin can change the lemon threshold.
            </p>
          )}
        </Card>
      </div>
    </div>
  );
}
