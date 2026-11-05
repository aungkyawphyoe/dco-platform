"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Table, TableHead, TableHeadCell, TableBody, TableRow, TableCell } from "@dco/ui/components/table";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Badge } from "@dco/ui/components/badge";
import { Button } from "@dco/ui/components/button";
import { Input } from "@dco/ui/components/input";
import { Modal } from "@dco/ui/components/modal";
import { EmptyState } from "@dco/ui/components/empty-state";
import { Skeleton } from "@dco/ui/components/skeleton";
import { InstrumentBand } from "@dco/ui/components/instrument-band";
import { SectionHeading } from "@dco/ui/components/section-heading";
import { Stat } from "@dco/ui/components/stat";
import {
  useCreateInspectionTemplate,
  useDeleteInspectionTemplate,
  useInspectionTemplates,
  useInspections,
} from "@/lib/api/hooks";
import { inspectionStatusTone } from "@/lib/api/types";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";
import { formatDateTime } from "@dco/ui/lib/format";

export default function InspectionsPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const isAdmin = role === "org_admin";

  const { data: templates, isLoading: templatesLoading } = useInspectionTemplates(orgId);
  const { data: inspections, isLoading: inspectionsLoading, error: inspectionsError, refetch: refetchInspections } = useInspections(orgId);
  const createTemplate = useCreateInspectionTemplate(orgId);
  const deleteTemplate = useDeleteInspectionTemplate(orgId);

  const [showCreate, setShowCreate] = useState(false);
  const [name, setName] = useState("");
  const [itemsText, setItemsText] = useState("Tires\nLights\nBrakes");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (window.location.hash) document.getElementById(window.location.hash.slice(1))?.scrollIntoView({ block: "center" });
  }, [inspections]);

  const runs = inspections?.items ?? [];
  const completed = runs.filter((r) => r.status === "completed").length;
  const inProgress = runs.filter((r) => r.status === "in_progress").length;
  const failedRuns = runs.filter((r) => r.items.some((item) => item.result === "not_ok")).length;

  async function onCreate() {
    setError(null);
    const items = itemsText
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean)
      .map((item_name) => ({ item_name, required: true }));
    if (!name || !items.length) {
      setError("Name and at least one checklist item are required");
      return;
    }
    try {
      await createTemplate.mutateAsync({ name, items });
      setShowCreate(false);
      setName("");
      setItemsText("Tires\nLights\nBrakes");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to create template");
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Inspections"
        meta={
          runs.length ? `${runs.length} runs logged, ${failedRuns} with failures` : undefined
        }
        actions={
          isAdmin ? <Button onClick={() => setShowCreate(true)}>New template</Button> : null
        }
      />

      <InstrumentBand>
        <div className="grid grid-cols-2 gap-4 p-5 sm:grid-cols-4">
          <Stat label="Runs logged" value={runs.length.toLocaleString()} />
          <Stat label="Completed" value={completed.toLocaleString()} />
          <Stat label="In progress" value={inProgress.toLocaleString()} />
          <Stat label="Runs with failures" value={failedRuns.toLocaleString()} />
        </div>
      </InstrumentBand>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-5">
        <div className="min-w-0 xl:col-span-3">
          <Card className="flex h-full flex-col">
            <SectionHeading title="Inspection history" count={runs.length} />
            <div className="flex-1 p-5">
              {inspectionsLoading ? (
                <Skeleton className="h-32 w-full" />
              ) : inspectionsError ? (
                <div role="alert">
                  <p className="text-sm text-danger">Inspection history could not be loaded.</p>
                  <Button className="mt-3" variant="secondary" size="sm" onClick={() => void refetchInspections()}>Try again</Button>
                </div>
              ) : runs.length === 0 ? (
                <EmptyState
                  title="No inspections yet"
                  description="Drivers start pre-trip and post-trip checks from their assignment; completed runs list here."
                />
              ) : (
                <Table aria-label="Inspection history">
                  <TableHead>
                    <TableRow>
                      <TableHeadCell>Vehicle</TableHeadCell>
                      <TableHeadCell>Inspection</TableHeadCell>
                      <TableHeadCell>Status</TableHeadCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {runs.map((inspection) => {
                      const failed = inspection.items.filter((item) => item.result === "not_ok");
                      const vehicleName = inspection.vehicle_name || inspection.vehicle_license_plate || `Vehicle ${inspection.vehicle_id}`;
                      return (
                        <TableRow key={inspection.id} id={`inspection-${inspection.id}`} className="align-top">
                          <TableCell>
                            <Link
                              href={`/vehicles/${inspection.vehicle_id}`}
                              className="font-medium text-link underline underline-offset-4 focus-visible:outline focus-visible:outline-2 focus-visible:outline-focus"
                            >
                              {vehicleName}
                            </Link>
                            {inspection.vehicle_license_plate && (
                              <p className="mt-1 text-xs text-ink-caption">{inspection.vehicle_license_plate}</p>
                            )}
                          </TableCell>
                          <TableCell>
                            <p className="font-medium capitalize">{inspection.inspection_type.replaceAll("_", " ")}</p>
                            <p className="mt-1 text-xs text-ink-caption">
                              {inspection.started_at ? formatDateTime(inspection.started_at) : "—"}
                            </p>
                            {failed.length > 0 && (
                              <p className="mt-1 text-xs text-danger">Failed: {failed.map((item) => item.item_name).join(", ")}</p>
                            )}
                            <details className="mt-2 text-xs">
                              <summary className="cursor-pointer rounded text-link focus-visible:outline focus-visible:outline-2 focus-visible:outline-focus">
                                View details<span className="sr-only"> for {vehicleName}</span>
                              </summary>
                              <div className="mt-2 space-y-2">
                                <p className="font-medium">{vehicleName}{inspection.vehicle_license_plate ? ` (${inspection.vehicle_license_plate})` : ""}</p>
                                {inspection.completed_at && <p className="text-ink-caption">Completed {formatDateTime(inspection.completed_at)}</p>}
                                {inspection.items.length ? (
                                  <ul className="space-y-2">
                                    {inspection.items.map((item, index) => (
                                      <li key={`${item.item_name}-${index}`}>
                                        <p className={item.result === "not_ok" ? "text-danger" : "text-ink"}>
                                          {item.item_name}: {item.result === "not_ok" ? "Failed" : "Passed"}
                                        </p>
                                        {item.notes && <p className="whitespace-pre-wrap text-ink-caption">{item.notes}</p>}
                                      </li>
                                    ))}
                                  </ul>
                                ) : <p className="text-ink-caption">No checklist results recorded yet.</p>}
                                {inspection.notes && <p className="whitespace-pre-wrap text-ink-caption">{inspection.notes}</p>}
                              </div>
                            </details>
                          </TableCell>
                          <TableCell>
                            <Badge tone={inspectionStatusTone[inspection.status] ?? "neutral"}>
                              {inspection.status.replaceAll("_", " ")}
                            </Badge>
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              )}
            </div>
          </Card>
        </div>

        <div className="min-w-0 xl:col-span-2">
          <Card className="flex h-full flex-col">
            <SectionHeading title="Checklist templates" count={templates?.items.length ?? 0} />
            <div className="flex-1 p-5">
              {templatesLoading ? (
                <Skeleton className="h-24 w-full" />
              ) : !templates?.items.length ? (
                <EmptyState
                  title="No templates"
                  description="Create a checklist template to run inspections."
                />
              ) : (
                <ul className="divide-y divide-line-subtle">
                  {templates.items.map((template) => (
                    <li key={template.id} className="py-3 first:pt-0 last:pb-0">
                      <div className="flex items-start justify-between gap-3">
                        <p className="text-sm font-medium text-ink">{template.name}</p>
                        {isAdmin ? (
                          <Button
                            size="sm"
                            variant="destructive"
                            onClick={() => void deleteTemplate.mutateAsync(template.id)}
                            disabled={deleteTemplate.isPending}
                          >
                            Delete
                          </Button>
                        ) : null}
                      </div>
                      <p className="mt-1 text-xs text-ink-caption">
                        {template.items.map((item) => item.item_name).join(", ")}
                      </p>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </Card>
        </div>
      </div>

      <Modal
        open={showCreate}
        onClose={() => setShowCreate(false)}
        title="New inspection template"
        confirmLabel="Create"
        loading={createTemplate.isPending}
        onSubmit={() => void onCreate()}
      >
        <div className="flex flex-col gap-3">
          <Input label="Template name" value={name} onChange={(e) => setName(e.target.value)} />
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-medium text-ink-caption">
              Checklist items (one per line)
            </label>
            <textarea
              className="min-h-28 rounded-md border border-line-strong bg-field p-3 text-sm text-ink"
              value={itemsText}
              onChange={(e) => setItemsText(e.target.value)}
            />
          </div>
          {error ? (
            <p className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">{error}</p>
          ) : null}
        </div>
      </Modal>
    </div>
  );
}
