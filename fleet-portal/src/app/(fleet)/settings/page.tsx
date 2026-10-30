"use client";
import { CurrencySettings } from "@/components/currency/currency-settings";

import { useState } from "react";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Badge } from "@dco/ui/components/badge";
import { Button } from "@dco/ui/components/button";
import { Input } from "@dco/ui/components/input";
import { Select } from "@dco/ui/components/select";
import { DataPlate } from "@dco/ui/components/data-plate";
import { SectionHeading } from "@dco/ui/components/section-heading";
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
        title="Organization settings"
        description="Organization profile and lemon threshold configuration"
      />

      <CurrencySettings />
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card className="flex flex-col">
          <SectionHeading title="Organization">
            <Badge tone="info">{organization?.status ?? "—"}</Badge>
          </SectionHeading>
          <div className="p-5">
            <DataPlate
              className=""
              fields={[
                { label: "Name", value: organization?.name ?? "—" },
                { label: "Type", value: organization?.type ?? "—" },
                { label: "Plan", value: organization?.plan ?? "—" },
                { label: "Contact email", value: organization?.contact_email ?? "—" },
                { label: "Contact phone", value: organization?.contact_phone ?? "—" },
                {
                  label: "Your role",
                  value: orgRoleLabel[organization?.role ?? ""] ?? organization?.role ?? "—",
                },
              ]}
            />
            <p className="mt-5 text-xs text-ink-caption">
              Contact details are managed by AutoX Admin for this MVP.
            </p>
          </div>
        </Card>

        <Card className="flex flex-col">
          <SectionHeading title="Lemon threshold" />
          <div className="flex flex-1 flex-col p-5">
            <p className="text-sm text-ink">
              Current threshold:{" "}
              <span className="font-mono text-ink">
                {lemons ? `${lemons.threshold_cost_per_km.toFixed(3)} MMK/km` : "—"}
              </span>
            </p>
            <p className="mt-1 text-xs text-ink-caption">
              Vehicles above this cost per kilometre are flagged as lemons.
            </p>

            {isAdmin ? (
              <div className="mt-5 flex flex-col gap-3">
                <Select
                  label="Mode"
                  options={[
                    { value: "multiplier", label: "Multiplier of fleet average" },
                    { value: "absolute", label: "Absolute MMK/km" },
                  ]}
                  value={mode}
                  onChange={(v) => setMode(v as "multiplier" | "absolute")}
                />
                <Input
                  label={mode === "multiplier" ? "Multiplier" : "Cost per km (MMK)"}
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
                  <p className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">{error}</p>
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
              <p className="mt-5 text-sm text-ink-caption">
                Only the Org Admin can change the lemon threshold.
              </p>
            )}
          </div>
        </Card>
      </div>
    </div>
  );
}
