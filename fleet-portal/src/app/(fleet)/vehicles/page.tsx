"use client";

import { useMemo, useRef, useState } from "react";
import Link from "next/link";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Badge } from "@dco/ui/components/badge";
import { Button } from "@dco/ui/components/button";
import { Input } from "@dco/ui/components/input";
import { Select } from "@dco/ui/components/select";
import { Modal } from "@dco/ui/components/modal";
import { SearchInput } from "@dco/ui/components/search-input";
import { EmptyState } from "@dco/ui/components/empty-state";
import { SkeletonTable } from "@dco/ui/components/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeadCell,
  TableRow,
} from "@dco/ui/components/table";
import {
  useCreateVehicle,
  useImportJob,
  useImportVehicleCsv,
  useVehicles,
} from "@/lib/api/hooks";
import {
  lifecycleTemplateOptions,
  vehicleClassOptions,
  type VehicleCreateInput,
} from "@/lib/api/types";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";

const fuelOptions = [
  { value: "petrol", label: "Petrol" },
  { value: "electric", label: "Electric" },
  { value: "hybrid_plugin", label: "Hybrid" },
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
  vehicle_class: "car",
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
  const importInput = useRef<HTMLInputElement>(null);
  const orgId = useOrgId();
  const role = useOrgRole();
  const canManage = role === "org_admin" || role === "org_manager";
  const canImport = role === "org_admin";

  const { data, isLoading } = useVehicles(orgId);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [lifecycleFilter, setLifecycleFilter] = useState("");
  const [classFilter, setClassFilter] = useState("");
  const [showCreate, setShowCreate] = useState(false);
  const [form, setForm] = useState<VehicleCreateInput>({ ...emptyForm, id: crypto.randomUUID() });
  const [createError, setCreateError] = useState<string | null>(null);
  const [importJobId, setImportJobId] = useState<string | null>(null);

  const createVehicle = useCreateVehicle(orgId);
  const importCsv = useImportVehicleCsv(orgId);
  const { data: importJob } = useImportJob(orgId, importJobId);

  const vehicles = useMemo(() => data?.items ?? [], [data]);
  const statusCounts = useMemo(() => {
    const map = new Map<string, number>();
    for (const v of vehicles) map.set(v.status, (map.get(v.status) ?? 0) + 1);
    return [...map.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
  }, [vehicles]);

  const filtered = vehicles.filter((v) => {
    const q = search.toLowerCase();
    const matchesSearch =
      !q ||
      v.name.toLowerCase().includes(q) ||
      v.license_plate.toLowerCase().includes(q) ||
      v.vin.toLowerCase().includes(q) ||
      `${v.make} ${v.model}`.toLowerCase().includes(q);
    const matchesStatus = !statusFilter || v.status === statusFilter;
    const matchesLifecycle = !lifecycleFilter || v.lifecycle_template === lifecycleFilter;
    const matchesClass = !classFilter || (v.vehicle_class ?? "car") === classFilter;
    return matchesSearch && matchesStatus && matchesLifecycle && matchesClass;
  });

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

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Vehicle inventory"
        meta={
          filtered.length === vehicles.length
            ? `${vehicles.length} vehicles`
            : `${filtered.length} of ${vehicles.length} vehicles`
        }
        actions={
          <>
            {canImport ? (
              <>
                <input
                  ref={importInput}
                  type="file"
                  accept=".csv"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) void onImport(file);
                    e.target.value = "";
                  }}
                />
                <Button variant="secondary" onClick={() => importInput.current?.click()}>
                  Import CSV
                </Button>
              </>
            ) : null}
            {canManage ? <Button onClick={() => setShowCreate(true)}>Add vehicle</Button> : null}
          </>
        }
      />

      {importJob ? (
        <Card className="p-4 text-sm">
          <p className="text-ink">
            Import job <span className="font-mono">{importJob.job_id}</span>{" "}
            <Badge
              tone={
                importJob.status === "completed"
                  ? "success"
                  : importJob.status === "failed"
                    ? "danger"
                    : "info"
              }
            >
              {importJob.status}
            </Badge>
            {typeof importJob.total_rows === "number" ? `, ${importJob.total_rows} rows` : ""}
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

      <div className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => setStatusFilter("")}
            className={`rounded-full border px-3 py-1 text-xs transition-colors ${
              statusFilter === ""
                ? "border-transparent bg-btn-primary font-semibold text-on-gold"
                : "border-line-subtle bg-card text-ink-muted hover:border-line-strong hover:text-ink"
            }`}
          >
            All <span className="font-mono">{vehicles.length}</span>
          </button>
          {statusCounts.map(([status, count]) => (
            <button
              key={status}
              type="button"
              onClick={() => setStatusFilter(statusFilter === status ? "" : status)}
              className={`rounded-full border px-3 py-1 text-xs transition-colors ${
                statusFilter === status
                  ? "border-transparent bg-btn-primary font-semibold text-on-gold"
                  : "border-line-subtle bg-card text-ink-muted hover:border-line-strong hover:text-ink"
              }`}
            >
              {status} <span className="font-mono">{count}</span>
            </button>
          ))}
        </div>

        <div className="flex flex-wrap items-end gap-3">
          <SearchInput
            value={search}
            onChange={setSearch}
            placeholder="Search name, plate, VIN…"
            className="w-72"
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
            label="Class"
            options={vehicleClassOptions}
            placeholder="All classes"
            value={classFilter}
            onChange={setClassFilter}
            className="w-44"
          />

        </div>
      </div>

      <Card>
        {isLoading ? (
          <div className="p-5">
            <SkeletonTable rows={6} cols={6} />
          </div>
        ) : filtered.length === 0 ? (
          <EmptyState
            title={vehicles.length === 0 ? "No vehicles yet" : "No vehicles match"}
            description={
              vehicles.length === 0
                ? "Add vehicles one at a time, or import your inventory from a CSV."
                : "Adjust the search or filters to see more of the fleet."
            }
            action={
              vehicles.length === 0 && canManage ? (
                <Button onClick={() => setShowCreate(true)}>Add vehicle</Button>
              ) : null
            }
          />
        ) : (
          <Table>
            <TableHead>
              <TableRow>

                <TableHeadCell>Vehicle</TableHeadCell>
                <TableHeadCell>Plate</TableHeadCell>
                <TableHeadCell>Lifecycle</TableHeadCell>
                <TableHeadCell>Status</TableHeadCell>
                <TableHeadCell>Distance</TableHeadCell>
                <TableHeadCell />
              </TableRow>
            </TableHead>
            <TableBody>
              {filtered.map((vehicle) => {
                return (
                  <TableRow key={vehicle.id}>

                    <TableCell>
                      <Link
                        href={`/vehicles/${vehicle.id}`}
                        className="font-medium text-ink hover:text-gold"
                      >
                        {vehicle.name}
                      </Link>
                      <p className="text-xs text-ink-caption">
                        {vehicle.year} {vehicle.make} {vehicle.model}
                      </p>
                    </TableCell>
                    <TableCell className="font-mono text-xs">{vehicle.license_plate}</TableCell>
                    <TableCell className="text-xs text-ink-muted">
                      {lifecycleTemplateOptions.find((o) => o.value === vehicle.lifecycle_template)
                        ?.label ?? vehicle.lifecycle_template}
                    </TableCell>
                    <TableCell>
                      <Badge tone={statusTone(vehicle.status)}>{vehicle.status}</Badge>
                    </TableCell>
                    <TableCell className="font-mono text-xs text-ink-caption">
                      {vehicle.mileage.toLocaleString(undefined, { maximumFractionDigits: 0 })} km
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center justify-end gap-2">

                        <Link
                          href={`/vehicles/${vehicle.id}`}
                          className="font-display text-sm font-semibold text-gold hover:underline"
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
            label="VIN (17 characters)"
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
              label="Class"
              options={vehicleClassOptions}
              value={form.vehicle_class ?? "car"}
              onChange={(value) =>
                setForm({ ...form, vehicle_class: value as VehicleCreateInput["vehicle_class"] })
              }
            />
          </div>
          <Select
            label="Lifecycle"
            options={lifecycleTemplateOptions}
            value={form.lifecycle_template}
            onChange={(value) =>
              setForm({
                ...form,
                lifecycle_template: value as VehicleCreateInput["lifecycle_template"],
              })
            }
          />
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
