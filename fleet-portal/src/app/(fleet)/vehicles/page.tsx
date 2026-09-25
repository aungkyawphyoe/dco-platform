"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { Modal } from "@/components/ui/modal";
import { SearchInput } from "@/components/ui/search-input";
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
  useBulkVehicleStatus,
  useCreateVehicle,
  useImportJob,
  useImportVehicleCsv,
  useUpdateVehicleStatus,
  useVehicles,
} from "@/lib/api/hooks";
import { lifecycleTransitions, type VehicleCreateInput } from "@/lib/api/types";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";

const lifecycleOptions = [
  { value: "showroom", label: "Showroom" },
  { value: "taxi_fleet", label: "Taxi fleet" },
  { value: "rental", label: "Rental" },
  { value: "commercial", label: "Commercial" },
];

const fuelOptions = [
  { value: "petrol", label: "Petrol" },
  { value: "electric", label: "Electric" },
  { value: "hybrid_plugin", label: "Hybrid plugin" },
];

const emptyForm: VehicleCreateInput = {
  id: "",
  name: "",
  make: "",
  model: "",
  year: new Date().getFullYear(),
  license_plate: "",
  vin: "",
  fuel_type: "petrol",
  mileage: 0,
  lifecycle_template: "taxi_fleet",
};

function statusTone(status: string): "success" | "warning" | "danger" | "info" | "neutral" {
  if (["available", "in_service", "listed"].includes(status)) return "success";
  if (["maintenance", "inspection", "return", "reserved"].includes(status)) return "warning";
  if (["retired", "sold"].includes(status)) return "danger";
  return "info";
}

export default function VehiclesPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const canManage = role === "org_admin" || role === "org_manager";
  const canImport = role === "org_admin";

  const { data, isLoading } = useVehicles(orgId);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [showCreate, setShowCreate] = useState(false);
  const [form, setForm] = useState<VehicleCreateInput>({ ...emptyForm, id: crypto.randomUUID() });
  const [createError, setCreateError] = useState<string | null>(null);
  const [importJobId, setImportJobId] = useState<string | null>(null);
  const [bulkStatus, setBulkStatus] = useState("");

  const createVehicle = useCreateVehicle(orgId);
  const updateStatus = useUpdateVehicleStatus(orgId);
  const bulkUpdate = useBulkVehicleStatus(orgId);
  const importCsv = useImportVehicleCsv(orgId);
  const { data: importJob } = useImportJob(orgId, importJobId);

  const vehicles = useMemo(() => data?.items ?? [], [data]);
  const statuses = useMemo(
    () => Array.from(new Set(vehicles.map((v) => v.status))).sort(),
    [vehicles],
  );

  const filtered = vehicles.filter((v) => {
    const q = search.toLowerCase();
    const matchesSearch =
      !q ||
      v.name.toLowerCase().includes(q) ||
      v.license_plate.toLowerCase().includes(q) ||
      v.vin.toLowerCase().includes(q) ||
      `${v.make} ${v.model}`.toLowerCase().includes(q);
    const matchesStatus = !statusFilter || v.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  function toggle(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleAll() {
    if (selected.size === filtered.length) setSelected(new Set());
    else setSelected(new Set(filtered.map((v) => v.id)));
  }

  async function onCreate() {
    setCreateError(null);
    try {
      await createVehicle.mutateAsync(form);
      setShowCreate(false);
      setForm({ ...emptyForm, id: crypto.randomUUID() });
    } catch (error) {
      setCreateError(error instanceof Error ? error.message : "Failed to add vehicle");
    }
  }

  async function onImport(file: File) {
    try {
      const job = await importCsv.mutateAsync(file);
      setImportJobId(job.job_id);
    } catch {
      setImportJobId(null);
    }
  }

  async function onBulkStatus() {
    if (!bulkStatus || !selected.size) return;
    await bulkUpdate.mutateAsync({ vehicleIds: [...selected], status: bulkStatus });
    setSelected(new Set());
    setBulkStatus("");
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Vehicle Inventory"
        description="Table view with filters and lifecycle status controls"
        actions={
          <>
            {canImport ? (
              <label className="inline-flex">
                <input
                  type="file"
                  accept=".csv"
                  className="sr-only"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) void onImport(file);
                    e.target.value = "";
                  }}
                />
                <span className="inline-flex h-11 cursor-pointer items-center justify-center rounded-md border border-line-strong bg-card px-5 font-display text-sm font-semibold text-ink transition-colors hover:bg-skeleton">
                  Import CSV
                </span>
              </label>
            ) : null}
            {canManage ? (
              <Button onClick={() => setShowCreate(true)}>Add vehicle</Button>
            ) : null}
          </>
        }
      />

      {importJob ? (
        <Card className="p-4 text-sm">
          <p className="text-ink">
            Import job <span className="font-mono">{importJob.job_id}</span> —{" "}
            <Badge tone={importJob.status === "completed" ? "success" : importJob.status === "failed" ? "danger" : "info"}>
              {importJob.status}
            </Badge>
            {typeof importJob.total_rows === "number"
              ? ` · ${importJob.total_rows} rows`
              : ""}
          </p>
          {importJob.results?.length ? (
            <ul className="mt-2 list-inside list-disc text-ink-caption">
              {importJob.results.slice(0, 8).map((r, i) => (
                <li key={i}>{r.error ?? r.plate ?? JSON.stringify(r)}</li>
              ))}
            </ul>
          ) : null}
        </Card>
      ) : null}

      <div className="flex flex-wrap items-end gap-3">
        <SearchInput
          value={search}
          onChange={setSearch}
          placeholder="Search name, plate, VIN…"
          className="w-72"
        />
        <Select
          label="Status"
          options={statuses.map((s) => ({ value: s, label: s }))}
          placeholder="All statuses"
          value={statusFilter}
          onChange={setStatusFilter}
          className="w-44"
        />
        {canManage && selected.size > 0 ? (
          <div className="flex items-end gap-2">
            <Select
              label="Bulk status"
              options={[{ value: bulkStatus, label: bulkStatus || "Choose…" }].filter(
                (o) => o.value,
              )}
              placeholder="Next status…"
              value={bulkStatus}
              onChange={setBulkStatus}
              className="w-44"
            />
            <Button
              size="sm"
              className="h-11"
              disabled={!bulkStatus || bulkUpdate.isPending}
              onClick={() => void onBulkStatus()}
            >
              Apply to {selected.size}
            </Button>
          </div>
        ) : null}
      </div>

      <Card>
        {isLoading ? (
          <div className="p-5">
            <SkeletonTable rows={6} cols={6} />
          </div>
        ) : filtered.length === 0 ? (
          <EmptyState
            title="No vehicles"
            description="Add vehicles one at a time or import a CSV."
          />
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                {canManage ? (
                  <TableHeadCell className="w-10">
                    <input
                      type="checkbox"
                      aria-label="Select all"
                      checked={selected.size > 0 && selected.size === filtered.length}
                      onChange={toggleAll}
                      className="size-4 accent-[var(--accent)]"
                    />
                  </TableHeadCell>
                ) : null}
                <TableHeadCell>Vehicle</TableHeadCell>
                <TableHeadCell>Plate</TableHeadCell>
                <TableHeadCell>Lifecycle</TableHeadCell>
                <TableHeadCell>Status</TableHeadCell>
                <TableHeadCell>km</TableHeadCell>
                <TableHeadCell>Driver</TableHeadCell>
                <TableHeadCell />
              </TableRow>
            </TableHead>
            <TableBody>
              {filtered.map((vehicle) => {
                const nextStatuses =
                  lifecycleTransitions[vehicle.lifecycle_template]?.[vehicle.status] ?? [];
                return (
                  <TableRow key={vehicle.id}>
                    {canManage ? (
                      <TableCell>
                        <input
                          type="checkbox"
                          aria-label={`Select ${vehicle.name}`}
                          checked={selected.has(vehicle.id)}
                          onChange={() => toggle(vehicle.id)}
                          className="size-4 accent-[var(--accent)]"
                        />
                      </TableCell>
                    ) : null}
                    <TableCell>
                      <p className="font-medium text-ink">{vehicle.name}</p>
                      <p className="text-xs text-ink-caption">
                        {vehicle.year} {vehicle.make} {vehicle.model}
                      </p>
                    </TableCell>
                    <TableCell className="font-mono text-xs">
                      {vehicle.license_plate}
                    </TableCell>
                    <TableCell className="text-xs text-ink-muted">
                      {vehicle.lifecycle_template}
                    </TableCell>
                    <TableCell>
                      <Badge tone={statusTone(vehicle.status)}>{vehicle.status}</Badge>
                    </TableCell>
                    <TableCell>{vehicle.mileage.toLocaleString()}</TableCell>
                    <TableCell className="font-mono text-xs text-ink-caption">
                      {vehicle.assigned_driver_id
                        ? vehicle.assigned_driver_id.slice(0, 8)
                        : "—"}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center justify-end gap-2">
                        {canManage && nextStatuses.length ? (
                          <select
                            aria-label={`Change status for ${vehicle.name}`}
                            className="h-8 rounded-sm border border-line-strong bg-field px-2 text-xs text-ink"
                            value=""
                            onChange={async (e) => {
                              if (!e.target.value) return;
                              try {
                                await updateStatus.mutateAsync({
                                  vehicleId: vehicle.id,
                                  status: e.target.value,
                                });
                              } catch {
                                // surface via react-query error state if needed
                              }
                            }}
                          >
                            <option value="">Status…</option>
                            {nextStatuses.map((s) => (
                              <option key={s} value={s}>
                                → {s}
                              </option>
                            ))}
                          </select>
                        ) : null}
                        <Link
                          href={`/vehicles/${vehicle.id}`}
                          className="text-sm text-gold hover:underline"
                        >
                          View
                        </Link>
                      </div>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        )}
      </Card>

      <Modal
        open={showCreate}
        onClose={() => setShowCreate(false)}
        title="Add vehicle"
        confirmLabel="Add vehicle"
        loading={createVehicle.isPending}
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
              label="Make"
              value={form.make}
              onChange={(e) => setForm({ ...form, make: e.target.value })}
            />
            <Input
              label="Model"
              value={form.model}
              onChange={(e) => setForm({ ...form, model: e.target.value })}
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <Input
              label="Year"
              type="number"
              value={form.year}
              onChange={(e) => setForm({ ...form, year: Number(e.target.value) })}
            />
            <Input
              label="License plate"
              value={form.license_plate}
              onChange={(e) => setForm({ ...form, license_plate: e.target.value })}
            />
          </div>
          <Input
            label="VIN (17 chars)"
            value={form.vin}
            maxLength={17}
            onChange={(e) => setForm({ ...form, vin: e.target.value })}
          />
          <div className="grid grid-cols-2 gap-3">
            <Select
              label="Fuel"
              options={fuelOptions}
              value={form.fuel_type}
              onChange={(value) =>
                setForm({ ...form, fuel_type: value as VehicleCreateInput["fuel_type"] })
              }
            />
            <Select
              label="Lifecycle"
              options={lifecycleOptions}
              value={form.lifecycle_template}
              onChange={(value) =>
                setForm({
                  ...form,
                  lifecycle_template: value as VehicleCreateInput["lifecycle_template"],
                })
              }
            />
          </div>
          <Input
            label="Odometer (km)"
            type="number"
            value={form.mileage}
            onChange={(e) => setForm({ ...form, mileage: Number(e.target.value) })}
          />
          {createError ? (
            <p className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">
              {createError}
            </p>
          ) : null}
        </div>
      </Modal>
    </div>
  );
}
