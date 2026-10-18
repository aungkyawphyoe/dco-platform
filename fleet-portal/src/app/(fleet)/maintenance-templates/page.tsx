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

type IntervalUnit = "day" | "month" | "year";

type TemplateForm = {
  name: string;
  interval_time: string;
  interval_unit: IntervalUnit;
  interval_distance: string;
  fuel_types: FuelType[];
  vehicle_class: VehicleClass;
  lifecycle_template: "" | LifecycleTemplate;
  enabled: boolean;
};

const INTERVAL_UNIT_OPTIONS: { value: IntervalUnit; label: string; days: number }[] = [
  { value: "day", label: "Day(s)", days: 1 },
  { value: "month", label: "Month(s)", days: 30 },
  { value: "year", label: "Year(s)", days: 365 },
];

function daysToUnit(days: number | null): { value: number; unit: IntervalUnit } | null {
  if (days == null) return null;
  for (const opt of [...INTERVAL_UNIT_OPTIONS].reverse()) {
    if (days % opt.days === 0) {
      return { value: days / opt.days, unit: opt.value };
    }
  }
  return { value: days, unit: "day" };
}

function unitToDays(value: number, unit: IntervalUnit): number {
  const opt = INTERVAL_UNIT_OPTIONS.find((o) => o.value === unit);
  return value * (opt?.days ?? 1);
}

const emptyForm: TemplateForm = {
  name: "",
  interval_time: "",
  interval_unit: "day",
  interval_distance: "",
  fuel_types: ["petrol", "electric", "hybrid_plugin"],
  vehicle_class: "car",
  lifecycle_template: "",
  enabled: true,
};

function formFromTemplate(template: MaintenanceTemplate): TemplateForm {
  const converted = daysToUnit(template.interval_days);
  return {
    name: template.name,
    interval_time: converted ? String(converted.value) : "",
    interval_unit: converted?.unit ?? "day",
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
  const [fuelFilter, setFuelFilter] = useState("");

  const { data, isLoading } = useMaintenanceTemplates(orgId, {
    vehicle_class: classFilter || undefined,
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

  function findOrgCopy(source: MaintenanceTemplate) {
    return templates.find(
      (t) => t.source === "org" && t.name.trim().toLowerCase() === source.name.trim().toLowerCase(),
    );
  }

  function openGlobalRowEdit(source: MaintenanceTemplate) {
    const orgCopy = findOrgCopy(source);
    if (orgCopy) openEdit(orgCopy);
    else openCopy(source);
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
    const days = form.interval_time ? unitToDays(Number(form.interval_time), form.interval_unit) : null;
    return {
      name: form.name.trim(),
      interval_days: days,
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
    if (!form.name.trim()) {
      setFormError("Name is required.");
      return;
    }
    if (form.interval_time && parseInt(form.interval_time, 10) < 1) {
      setFormError("Interval must be at least 1.");
      return;
    }
    if (form.interval_distance && Number(form.interval_distance) < 1) {
      setFormError("Distance must be at least 1.");
      return;
    }
    if (!form.fuel_types.length) {
      setFormError("Select at least one fuel type.");
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
    editor?.mode === "edit" ? "Edit catalog item" : "Add catalog item";

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Maintenance Catalog"
        description="Vehicle-class maintenance catalog — platform defaults plus your organization's copies"
        actions={canManage ? <Button onClick={openNew}>Add item</Button> : null}
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
          label="Fuel type"
          options={fuelTypeOptions}
          placeholder="All fuel types"
          value={fuelFilter}
          onChange={setFuelFilter}
          className="w-44"
        />
      </div>

      <Card>
        {isLoading ? (
          <div className="p-5">
            <SkeletonTable rows={8} cols={canManage ? 8 : 7} />
          </div>
        ) : templates.length === 0 ? (
          <EmptyState
            title="No catalog items"
            description="No global or organization catalog items match these filters."
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
                    {lifecycleTemplateOptions.find((o) => o.value === template.lifecycle_template)
                      ?.label ?? "Any"}
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-wrap gap-1">
                      {template.fuel_types.map((ft) => (
                        <Badge key={ft} tone="neutral">
                          {fuelTypeOptions.find((o) => o.value === ft)?.label ?? ft}
                        </Badge>
                      ))}
                    </div>
                  </TableCell>
                  <TableCell className="text-xs text-ink-muted">{intervalLabel(template)}</TableCell>
                  <TableCell>
                    <Badge tone={template.source === "org" ? "info" : "neutral"}>
                      {template.source === "org" ? "Org copy" : "Global"}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <Badge tone={template.enabled ? "success" : "danger"}>
                      {template.enabled ? "Active" : "Disabled"}
                    </Badge>
                  </TableCell>
                  {canManage ? (
                    <TableCell>
                      <div className="flex items-center justify-end gap-2">
                        <Button
                          size="sm"
                          variant="secondary"
                          onClick={() =>
                            template.source === "global"
                              ? openGlobalRowEdit(template)
                              : openEdit(template)
                          }
                        >
                          Edit
                        </Button>
                        {template.source === "org" ? (
                          <Button size="sm" variant="destructive" onClick={() => setDeleteTarget(template)}>
                            Delete
                          </Button>
                        ) : null}
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
            placeholder="e.g. Oil Change"
            maxLength={80}
          />
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
              label="Lifecycle"
              options={lifecycleTemplateOptions}
              placeholder="Any lifecycle"
              value={form.lifecycle_template}
              onChange={(value) =>
                setForm({ ...form, lifecycle_template: value as "" | LifecycleTemplate })
              }
            />
          </div>
          <div>
            <div className="flex gap-2">
              <Input
                label="Interval (time)"
                type="number"
                placeholder="e.g. 6"
                min={1}
                value={form.interval_time}
                onChange={(e) => setForm({ ...form, interval_time: e.target.value })}
              />
              <Select
                label="Unit"
                options={INTERVAL_UNIT_OPTIONS.map((o) => ({ value: o.value, label: o.label }))}
                value={form.interval_unit}
                onChange={(value) =>
                  setForm({ ...form, interval_unit: value as IntervalUnit })
                }
                className="flex-1 min-w-[120px]"
              />
            </div>
          </div>
          <Input
            label="Interval (km)"
            type="number"
            placeholder="optional"
            min={1}
            step="0.1"
            value={form.interval_distance}
            onChange={(e) => setForm({ ...form, interval_distance: e.target.value })}
          />
          <div>
            <label className="mb-1.5 block text-sm font-medium text-ink">Fuel Types</label>
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
        title="Delete catalog item"
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
