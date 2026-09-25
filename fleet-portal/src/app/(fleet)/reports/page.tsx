"use client";

import { useState } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { downloadReport } from "@/lib/api/hooks";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";

const reports = [
  {
    type: "vehicles" as const,
    title: "Vehicle inventory",
    description: "Full inventory list with lifecycle status, plate, and VIN.",
  },
  {
    type: "fleet" as const,
    title: "Fleet cost report",
    description: "Per-vehicle TCO, distance driven, and cost-per-kilometre.",
  },
  {
    type: "lemons" as const,
    title: "Lemon flags",
    description: "Vehicles currently above the organization lemon threshold.",
  },
];

export default function ReportsPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const canExport = role === "org_admin" || role === "org_manager";
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function onExport(type: "vehicles" | "fleet" | "lemons") {
    if (!orgId) return;
    setPending(type);
    setError(null);
    try {
      await downloadReport(orgId, type);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Export failed");
    } finally {
      setPending(null);
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Reports"
        description="CSV exports for inventory, cost analysis, and lemon flags"
      />

      {error ? (
        <Card className="p-4 text-sm text-danger">{error}</Card>
      ) : null}

      {!canExport ? (
        <Card className="p-4 text-sm text-ink-caption">
          Exports require Org Admin or Manager role.
        </Card>
      ) : null}

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        {reports.map((report) => (
          <Card key={report.type} className="flex flex-col p-5">
            <h2 className="font-display text-base font-semibold text-ink">
              {report.title}
            </h2>
            <p className="mt-2 flex-1 text-sm text-ink-caption">
              {report.description}
            </p>
            <Button
              className="mt-4 self-start"
              size="sm"
              disabled={!canExport || pending !== null}
              onClick={() => void onExport(report.type)}
            >
              {pending === report.type ? "Exporting…" : "Download CSV"}
            </Button>
          </Card>
        ))}
      </div>
    </div>
  );
}
