"use client";

import { useState } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
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
  useCreateWarrantyTemplate,
  useDeleteWarrantyTemplate,
  useWarrantyTemplates,
} from "@/lib/api/hooks";
import type { WarrantyTemplate } from "@/lib/api/types";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";

export default function WarrantyTemplatesPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const isAdmin = role === "org_admin";

  const { data, isLoading } = useWarrantyTemplates(orgId);
  const createTemplate = useCreateWarrantyTemplate(orgId);
  const deleteTemplate = useDeleteWarrantyTemplate(orgId);

  const [showCreate, setShowCreate] = useState(false);
  const [form, setForm] = useState({
    name: "",
    duration_years: 2,
    mileage_limit_km: 60000,
    coverage_categories: "",
    exclusions: "",
    approved_workshop_ids: "",
  });
  const [error, setError] = useState<string | null>(null);

  async function onCreate() {
    setError(null);
    if (!form.name) {
      setError("Name is required");
      return;
    }
    try {
      await createTemplate.mutateAsync({
        name: form.name,
        duration_years: form.duration_years,
        mileage_limit_km: form.mileage_limit_km,
        coverage_categories: form.coverage_categories
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean),
        exclusions: form.exclusions || null,
        approved_workshop_ids: form.approved_workshop_ids
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean),
      });
      setShowCreate(false);
      setForm({
        name: "",
        duration_years: 2,
        mileage_limit_km: 60000,
        coverage_categories: "",
        exclusions: "",
        approved_workshop_ids: "",
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to create template");
    }
  }

  const templates = data?.items ?? [];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Warranty Templates"
        description="Duration, mileage limits, coverage, and approved workshops"
        actions={
          isAdmin ? (
            <Button onClick={() => setShowCreate(true)}>New template</Button>
          ) : null
        }
      />

      <Card>
        {isLoading ? (
          <div className="p-5">
            <SkeletonTable rows={3} cols={5} />
          </div>
        ) : templates.length === 0 ? (
          <EmptyState
            title="No warranty templates"
            description="Create templates to apply warranties on vehicle transfer."
          />
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Name</TableHeadCell>
                <TableHeadCell>Duration</TableHeadCell>
                <TableHeadCell>Mileage limit</TableHeadCell>
                <TableHeadCell>Coverage</TableHeadCell>
                <TableHeadCell>Workshops</TableHeadCell>
                <TableHeadCell />
              </TableRow>
            </TableHead>
            <TableBody>
              {templates.map((template: WarrantyTemplate) => (
                <TableRow key={template.id}>
                  <TableCell className="font-medium text-ink">
                    {template.name}
                  </TableCell>
                  <TableCell>{template.duration_years} yr</TableCell>
                  <TableCell>{template.mileage_limit_km.toLocaleString()} km</TableCell>
                  <TableCell className="text-xs text-ink-caption">
                    {template.coverage_categories?.join(", ") || "—"}
                    {template.exclusions ? (
                      <p className="mt-0.5 text-danger">
                        excl: {template.exclusions}
                      </p>
                    ) : null}
                  </TableCell>
                  <TableCell className="text-xs text-ink-caption">
                    {template.approved_workshop_ids?.length
                      ? `${template.approved_workshop_ids.length} approved`
                      : "—"}
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

      <Modal
        open={showCreate}
        onClose={() => setShowCreate(false)}
        title="New warranty template"
        confirmLabel="Create"
        loading={createTemplate.isPending}
        onSubmit={() => void onCreate()}
      >
        <div className="flex flex-col gap-3">
          <Input
            label="Name"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
          />
          <div className="grid grid-cols-2 gap-3">
            <Input
              label="Duration (years)"
              type="number"
              min={1}
              max={10}
              value={form.duration_years}
              onChange={(e) =>
                setForm({ ...form, duration_years: Number(e.target.value) })
              }
            />
            <Input
              label="Mileage limit (km)"
              type="number"
              min={1000}
              value={form.mileage_limit_km}
              onChange={(e) =>
                setForm({ ...form, mileage_limit_km: Number(e.target.value) })
              }
            />
          </div>
          <Input
            label="Coverage categories (comma-separated)"
            value={form.coverage_categories}
            onChange={(e) =>
              setForm({ ...form, coverage_categories: e.target.value })
            }
          />
          <Input
            label="Exclusions"
            value={form.exclusions}
            onChange={(e) => setForm({ ...form, exclusions: e.target.value })}
          />
          <Input
            label="Approved workshop IDs (comma-separated UUIDs)"
            value={form.approved_workshop_ids}
            onChange={(e) =>
              setForm({ ...form, approved_workshop_ids: e.target.value })
            }
            hint="Workshops must already be approved for this organization."
          />
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
