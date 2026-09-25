"use client";

import { useState } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { EmptyState } from "@/components/ui/empty-state";
import { SkeletonTable } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeadCell,
  TableRow,
} from "@/components/ui/table";
import {
  useCreateInspectionTemplate,
  useDeleteInspectionTemplate,
  useInspectionTemplates,
  useInspections,
} from "@/lib/api/hooks";
import { inspectionStatusTone } from "@/lib/api/types";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";

export default function InspectionsPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const isAdmin = role === "org_admin";

  const { data: templates, isLoading: templatesLoading } =
    useInspectionTemplates(orgId);
  const { data: inspections, isLoading: inspectionsLoading } =
    useInspections(orgId);
  const createTemplate = useCreateInspectionTemplate(orgId);
  const deleteTemplate = useDeleteInspectionTemplate(orgId);

  const [showCreate, setShowCreate] = useState(false);
  const [name, setName] = useState("");
  const [itemsText, setItemsText] = useState("Tires\nLights\nBrakes");
  const [error, setError] = useState<string | null>(null);

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
        description="Checklist templates and inspection history with failure review"
        actions={
          isAdmin ? (
            <Button onClick={() => setShowCreate(true)}>New template</Button>
          ) : null
        }
      />

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
        <Card>
          <div className="border-b border-line-subtle px-5 py-4">
            <h2 className="font-display text-base font-semibold text-ink">
              Templates
            </h2>
          </div>
          {templatesLoading ? (
            <div className="p-5">
              <SkeletonTable rows={3} cols={3} />
            </div>
          ) : !templates?.items.length ? (
            <EmptyState
              title="No templates"
              description="Create a checklist template to run inspections."
            />
          ) : (
            <Table>
              <TableHead>
                <TableRow>
                  <TableHeadCell>Name</TableHeadCell>
                  <TableHeadCell>Items</TableHeadCell>
                  <TableHeadCell />
                </TableRow>
              </TableHead>
              <TableBody>
                {templates.items.map((template) => (
                  <TableRow key={template.id}>
                    <TableCell>{template.name}</TableCell>
                    <TableCell className="text-xs text-ink-caption">
                      {template.items.map((item) => item.item_name).join(", ")}
                    </TableCell>
                    <TableCell className="text-right">
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
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </Card>

        <Card>
          <div className="border-b border-line-subtle px-5 py-4">
            <h2 className="font-display text-base font-semibold text-ink">
              Inspection history
            </h2>
          </div>
          {inspectionsLoading ? (
            <div className="p-5">
              <SkeletonTable rows={5} cols={4} />
            </div>
          ) : !inspections?.items.length ? (
            <EmptyState
              title="No inspections"
              description="Drivers start pre-trip and post-trip inspections from their assignment."
            />
          ) : (
            <Table>
              <TableHead>
                <TableRow>
                  <TableHeadCell>Type</TableHeadCell>
                  <TableHeadCell>Status</TableHeadCell>
                  <TableHeadCell>Started</TableHeadCell>
                  <TableHeadCell>Failed items</TableHeadCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {inspections.items.map((inspection) => {
                  const failed = inspection.items.filter(
                    (item) => item.result === "not_ok",
                  );
                  return (
                    <TableRow key={inspection.id}>
                      <TableCell className="capitalize">
                        {inspection.inspection_type.replace("_", " ")}
                      </TableCell>
                      <TableCell>
                        <Badge
                          tone={inspectionStatusTone[inspection.status] ?? "neutral"}
                        >
                          {inspection.status}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-xs text-ink-caption">
                        {inspection.started_at
                          ? new Date(inspection.started_at).toLocaleString()
                          : "—"}
                      </TableCell>
                      <TableCell className="text-xs text-danger">
                        {failed.length
                          ? failed.map((item) => item.item_name).join(", ")
                          : "—"}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </Card>
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
          <Input
            label="Template name"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
          <div className="flex flex-col gap-1.5">
            <label className="text-label uppercase tracking-wide text-ink-caption">
              Checklist items (one per line)
            </label>
            <textarea
              className="min-h-28 rounded-md border border-line-strong bg-field p-3 text-sm text-ink"
              value={itemsText}
              onChange={(e) => setItemsText(e.target.value)}
            />
          </div>
          {error ? (
            <p className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">
              {error}
            </p>
          ) : null}
        </div>
      </Modal>
    </div>
  );
}
