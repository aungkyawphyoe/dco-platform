"use client";

import { useMemo, useState } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
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
  useCreateMaintenanceTemplate,
  useDeleteMaintenanceTemplate,
  useMaintenanceTemplates,
  useUpdateMaintenanceTemplate,
} from "@/lib/api/hooks";
import {
  fuelTypeOptions,
  lifecycleTemplateOptions,
  vehicleClassOptions,
  type FuelType,
  type LifecycleTemplate,
  type MaintenanceTemplate,
  type MaintenanceTemplateWrite,
  type VehicleClass,
} from "@/lib/api/types";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";

type EditorMode = "new" | "copy" | "edit";

type TemplateForm = {
  name: string;
  interval_days: string;
  interval_distance: string;
  fuel_types: FuelType[];
  vehicle_class: VehicleClass;
  lifecycle_template: "" | LifecycleTemplate;
  enabled: boolean;
};

const emptyForm: TemplateForm = {
  name: "",
  interval_days: "",
  interval_distance: "",
  fuel_types: ["petrol"],
  vehicle_class: "car",
  lifecycle_template: "",
  enabled: true,
};

function formFromTemplate(template: MaintenanceTemplate): TemplateForm {
  return {
    name: template.name,
    interval_days: template.interval_days != null ? String(template.interval_days) : "",
    interval_distance:
      template.interval_distance != null ? String(template.interval_distance) : "",
    fuel_types: [...template.fuel_types],
    vehicle_class: template.vehicle_class,
    lifecycle_template: template.lifecycle_template ?? "",
    enabled: template.enabled,
  };
}

function intervalLabel(template: MaintenanceTemplate) {
  const parts: string[] = [];
  if (template.interval_days) parts.push(`${template.interval_days} d`);
  if (template.interval_distance) parts.push(`${template.interval_distance.toLocaleString()} km`);
  return parts.length ? parts.join(" · ") : "—";
}

export default function MaintenanceTemplatesPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const canManage = role === "org_admin" || role === "org_manager";

  const [classFilter, setClassFilter] = useState("");
  const [lifecycleFilter, setLifecycleFilter] = useState("");
  const [fuelFilter, setFuelFilter] = useState("");

  const { data, isLoading } = useMaintenanceTemplates(orgId, {
    vehicle_class: classFilter || undefined,
    lifecycle_template: lifecycleFilter || undefined,
    fuel_type: fuelFilter || undefined,
  });

  const createTemplate = useCreateMaintenanceTemplate(orgId);
  const updateTemplate = useUpdateMaintenanceTemplate(orgId);
  const deleteTemplate = useDeleteMaintenanceTemplate(orgId);

  const [editor, setEditor] = useState<{ mode: EditorMode; template?: MaintenanceTemplate } | null>(null);
  const [form, setForm] = useState<TemplateForm>(emptyForm);
  const [formError, setFormError] = useState<string | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<MaintenanceTemplate | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const templates = useMemo(() => data?.items ?? [], [data]);

  function openNew() {
    setForm(emptyForm);
    setFormError(null);
    setEditor({ mode: "new" });
  }

  function openCopy(source: MaintenanceTemplate) {
    setForm({ ...formFromTemplate(source), name: source.name });
    setFormError(null);
    setEditor({ mode: "copy", template: source });
  }

  function openEdit(template: MaintenanceTemplate) {
    setForm(formFromTemplate(template));
    setFormError(null);
    setEditor({ mode: "edit", template: template });
  }

  function toggleFuel(fuel: FuelType) {
    setForm((prev) => {
      const next = prev.fuel_types.includes(fuel)
        ? prev.fuel_types.filter((f) => f !== fuel)
        : [...prev.fuel_types, fuel];
      return { ...prev, fuel_types: next };
    });
  }

  function buildBody(): MaintenanceTemplateWrite {
    return {
      name: form.name.trim() || undefined,
      interval_days: form.interval_days ? Number(form.interval_days) : null,
      interval_distance: form.interval_distance ? Number(form.interval_distance) : null,
      fuel_types: form.fuel_types.length ? form.fuel_types : undefined,
      vehicle_class: form.vehicle_class,
      lifecycle_template: form.lifecycle_template === "" ? null : form.lifecycle_template,
      enabled: form.enabled,
    };
  }

  async function onSubmitEditor() {
    if (!editor) return;
    setFormError(null);
    if (!form.name.trim() && editor.mode !== "edit") {
      setFormError("Name is required");
      return;
    }
    if (!form.fuel_types.length) {
      setFormError("Select at least one fuel type");
      return;
    }
    try {
      if (editor.mode === "edit" && editor.template) {
        await updateTemplate.mutateAsync({ id: editor.template.id, body: buildBody() });
      } else {
        await createTemplate.mutateAsync({
          ...buildBody(),
          ...(editor.mode === "copy" && editor.template
            ? { source_template_id: editor.template.id }
            : {}),
        });
      }
      setEditor(null);
    } catch (error) {
      setFormError(error instanceof Error ? error.message : "Failed to save template");
    }
  }

  async function onDelete() {
    if (!deleteTarget) return;
    setDeleteError(null);
    try {
      await deleteTemplate.mutateAsync(deleteTarget.id);
      setDeleteTarget(null);
    } catch (error) {
      setDeleteError(error instanceof Error ? error.message : "Failed to delete template");
    }
  }

  const editorTitle =
    editor?.mode === "edit" ? "Edit org template" : editor?.mode === "copy" ? "Copy template" : "New template";

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Maintenance Templates"
        description="Vehicle-class maintenance templates — platform defaults plus your organization's copies"
        actions={canManage ? <Button onClick={openNew}>New template</Button> : null}
      />

      <div className="flex flex-wrap items-end gap-3">
        <Select
          label="Vehicle class"
          options={vehicleClassOptions}
          placeholder="All classes"
          value={classFilter}
          onChange={setClassFilter}
          className="w-44"
        />
        <Select
          label="Lifecycle"
          options={lifecycleTemplateOptions}
          placeholder="All lifecycles"
          value={lifecycleFilter}
          onChange={setLifecycleFilter}
          className="w-44"
        />
        <Select
          label="Fuel"
          options={fuelTypeOptions}
          placeholder="All fuels"
          value={fuelFilter}
          onChange={setFuelFilter}
          className="w-44"
        />
      </div>

      <Card>
        {isLoading ? (
          <div className="p-5">
            <SkeletonTable rows={8} cols={7} />
          </div>
        ) : templates.length === 0 ? (
          <EmptyState
            title="No templates"
            description="No global or organization templates match these filters."
          />
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Name</TableHeadCell>
                <TableHeadCell>Class</TableHeadCell>
                <TableHeadCell>Lifecycle</TableHeadCell>
                <TableHeadCell>Fuel</TableHeadCell>
                <TableHeadCell>Interval</TableHeadCell>
                <TableHeadCell>Source</TableHeadCell>
                <TableHeadCell>Status</TableHeadCell>
                {canManage ? <TableHeadCell /> : null}
              </TableRow>
            </TableHead>
            <TableBody>
              {templates.map((template) => (
                <TableRow key={template.id}>
                  <TableCell>
                    <p className="font-medium text-ink">{template.name}</p>
                    <p className="font-mono text-xs text-ink-caption">{template.catalog_key}</p>
                  </TableCell>
                  <TableCell className="text-xs text-ink-muted">
                    {vehicleClassOptions.find((o) => o.value === template.vehicle_class)?.label ??
                      template.vehicle_class}
                  </TableCell>
                  <TableCell className="text-xs text-ink-muted">
                    {template.lifecycle_template ?? "Any"}
                  </TableCell>
                  <TableCell className="text-xs text-ink-muted">
                    {template.fuel_types.join(", ")}
                  </TableCell>
                  <TableCell className="text-xs text-ink-muted">{intervalLabel(template)}</TableCell>
                  <TableCell>
                    <Badge tone={template.source === "org" ? "info" : "neutral"}>
                      {template.source === "org" ? "Org copy" : "Global"}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <Badge tone={template.enabled ? "success" : "neutral"}>
                      {template.enabled ? "Enabled" : "Disabled"}
                    </Badge>
                  </TableCell>
                  {canManage ? (
                    <TableCell>
                      <div className="flex items-center justify-end gap-2">
                        {template.source === "global" ? (
                          <Button size="sm" variant="secondary" onClick={() => openCopy(template)}>
                            Copy
                          </Button>
                        ) : (
                          <>
                            <Button size="sm" variant="secondary" onClick={() => openEdit(template)}>
                              Edit
                            </Button>
                            <Button size="sm" variant="destructive" onClick={() => setDeleteTarget(template)}>
                              Delete
                            </Button>
                          </>
                        )}
                      </div>
                    </TableCell>
                  ) : null}
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </Card>

      <Modal
        open={editor !== null}
        onClose={() => setEditor(null)}
        title={editorTitle}
        confirmLabel={editor?.mode === "edit" ? "Save" : "Create"}
        loading={createTemplate.isPending || updateTemplate.isPending}
        onSubmit={() => void onSubmitEditor()}
      >
        <div className="flex flex-col gap-3">
          <Input
            label="Name"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
          />
          <div className="grid grid-cols-2 gap-3">
            <Input
              label="Every (days)"
              type="number"
              placeholder="e.g. 365"
              value={form.interval_days}
              onChange={(e) => setForm({ ...form, interval_days: e.target.value })}
            />
            <Input
              label="Every (km)"
              type="number"
              placeholder="e.g. 15000"
              value={form.interval_distance}
              onChange={(e) => setForm({ ...form, interval_distance: e.target.value })}
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <Select
              label="Vehicle class"
              options={vehicleClassOptions}
              value={form.vehicle_class}
              onChange={(value) =>
                setForm({ ...form, vehicle_class: value as VehicleClass })
              }
            />
            <Select
              label="Lifecycle (optional)"
              options={lifecycleTemplateOptions}
              placeholder="Any lifecycle"
              value={form.lifecycle_template}
              onChange={(value) =>
                setForm({ ...form, lifecycle_template: value as "" | LifecycleTemplate })
              }
            />
          </div>
          <div>
            <p className="pb-1.5 text-xs font-medium text-ink-caption">Fuel types</p>
            <div className="flex flex-wrap gap-4">
              {fuelTypeOptions.map((fuel) => (
                <label key={fuel.value} className="inline-flex items-center gap-2 text-sm text-ink">
                  <input
                    type="checkbox"
                    checked={form.fuel_types.includes(fuel.value)}
                    onChange={() => toggleFuel(fuel.value)}
                    className="size-4 accent-[var(--accent)]"
                  />
                  {fuel.label}
                </label>
              ))}
            </div>
          </div>
          <label className="inline-flex items-center gap-2 text-sm text-ink">
            <input
              type="checkbox"
              checked={form.enabled}
              onChange={(e) => setForm({ ...form, enabled: e.target.checked })}
              className="size-4 accent-[var(--accent)]"
            />
            Enabled
          </label>
          {formError ? (
            <p className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">{formError}</p>
          ) : null}
        </div>
      </Modal>

      <Modal
        open={deleteTarget !== null}
        onClose={() => {
          setDeleteTarget(null);
          setDeleteError(null);
        }}
        title="Delete org template"
        confirmLabel="Delete"
        destructive
        loading={deleteTemplate.isPending}
        onSubmit={() => void onDelete()}
      >
        <div className="flex flex-col gap-3">
          <p>
            Delete <span className="font-semibold text-ink">{deleteTarget?.name}</span>? This only
            removes the organization copy — generated plans are unaffected.
          </p>
          {deleteError ? (
            <p className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">{deleteError}</p>
          ) : null}
        </div>
      </Modal>
    </div>
  );
}
