"use client";

import { useState, useEffect, useRef, useImperativeHandle, forwardRef } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { EmptyState } from "@/components/ui/empty-state";
import { Modal } from "@/components/ui/modal";
import {
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableHeadCell,
  TableCell,
} from "@/components/ui/table";
import { SkeletonTable } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import {
  useCatalogItems,
  useCreateCatalogItem,
  useUpdateCatalogItem,
  useDeleteCatalogItem,
} from "@/lib/api/hooks";

type FuelType = "petrol" | "electric" | "hybrid_plugin";
type IntervalUnit = "day" | "month" | "year";

const FUEL_LABELS: Record<FuelType, string> = {
  petrol: "Petrol",
  electric: "Electric",
  hybrid_plugin: "Hybrid",
};

const INTERVAL_UNIT_OPTIONS: { value: IntervalUnit; label: string; days: number }[] = [
  { value: "day", label: "Day(s)", days: 1 },
  { value: "month", label: "Month(s)", days: 30 },
  { value: "year", label: "Year(s)", days: 365 },
];

function daysToUnit(days: number | null): { value: number; unit: IntervalUnit } | null {
  if (days == null) return null;
  for (const opt of INTERVAL_UNIT_OPTIONS) {
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

function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 50);
}

export default function CatalogPage() {
  const [showCreate, setShowCreate] = useState(false);
  const [editItem, setEditItem] = useState<{
    id: string;
    catalog_key: string;
    name: string;
    interval_days: number | null;
    interval_distance: number | null;
    fuel_types: FuelType[];
    sort_order: number;
    enabled: boolean;
  } | null>(null);

  const { data, isLoading, error } = useCatalogItems();
  const items = data?.items ?? [];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Maintenance Catalog"
        description="Manage suggested maintenance items shown to app users"
        actions={
          <Button size="sm" onClick={() => setShowCreate(true)}>
            Add item
          </Button>
        }
      />

      {error ? (
        <Card className="p-6">
          <p className="text-sm text-danger">Failed to load catalog. Please try again.</p>
        </Card>
      ) : isLoading ? (
        <Card className="p-5">
          <SkeletonTable rows={5} cols={6} />
        </Card>
      ) : items.length === 0 ? (
        <Card>
          <EmptyState
            title="No catalog items"
            description="Add your first maintenance catalog item."
            action={
              <Button size="sm" onClick={() => setShowCreate(true)}>
                Add item
              </Button>
            }
          />
        </Card>
      ) : (
        <Card>
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Name</TableHeadCell>
                <TableHeadCell>Key</TableHeadCell>
                <TableHeadCell>Time</TableHeadCell>
                <TableHeadCell>Distance</TableHeadCell>
                <TableHeadCell>Fuel Types</TableHeadCell>
                <TableHeadCell>Order</TableHeadCell>
                <TableHeadCell>Status</TableHeadCell>
                <TableHeadCell />
              </TableRow>
            </TableHead>
            <TableBody>
              {items.map((item) => (
                <TableRow key={item.id}>
                  <TableCell>
                    <span className="text-gold font-medium">{item.name}</span>
                  </TableCell>
                  <TableCell className="font-mono text-xs text-ink-muted">
                    {item.catalog_key}
                  </TableCell>
                  <TableCell className="text-ink-muted">
                    {item.interval_days != null ? `${item.interval_days}d` : "—"}
                  </TableCell>
                  <TableCell className="text-ink-muted">
                    {item.interval_distance != null
                      ? `${item.interval_distance.toLocaleString()}km`
                      : "—"}
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-wrap gap-1">
                      {item.fuel_types.map((ft) => (
                        <Badge key={ft} tone="neutral">
                          {FUEL_LABELS[ft] ?? ft}
                        </Badge>
                      ))}
                    </div>
                  </TableCell>
                  <TableCell className="text-ink-muted">
                    {item.sort_order}
                  </TableCell>
                  <TableCell>
                    <Badge tone={item.enabled ? "success" : "danger"}>
                      {item.enabled ? "Active" : "Disabled"}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() =>
                        setEditItem({
                          id: item.id,
                          catalog_key: item.catalog_key,
                          name: item.name,
                          interval_days: item.interval_days ?? null,
                          interval_distance: item.interval_distance ?? null,
                          fuel_types: item.fuel_types,
                          sort_order: item.sort_order,
                          enabled: item.enabled,
                        })
                      }
                    >
                      Edit
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </Card>
      )}

      <CreateCatalogDialog open={showCreate} onClose={() => setShowCreate(false)} />

      {editItem && (
        <EditCatalogDialog open item={editItem} onClose={() => setEditItem(null)} />
      )}
    </div>
  );
}

type CatalogFormRef = {
  submit: () => void;
};

const CatalogForm = forwardRef<CatalogFormRef, {
  initialName: string;
  initialIntervalDays: number | null;
  initialIntervalDistance: number | null;
  initialFuelTypes: FuelType[];
  initialSortOrder: number;
  initialEnabled: boolean;
  onSubmit: (data: {
    name: string;
    interval_days: number | null;
    interval_distance: number | null;
    fuel_types: FuelType[];
    sort_order: number;
    enabled: boolean;
  }) => void;
  error: string | null;
}>((props, ref) => {
  const {
    initialName,
    initialIntervalDays,
    initialIntervalDistance,
    initialFuelTypes,
    initialSortOrder,
    initialEnabled,
    onSubmit,
    error,
  } = props;

  const [name, setName] = useState(initialName);
  const [intervalValue, setIntervalValue] = useState("");
  const [intervalUnit, setIntervalUnit] = useState<IntervalUnit>("day");
  const [intervalDistance, setIntervalDistance] = useState(
    initialIntervalDistance?.toString() ?? "",
  );
  const [fuelTypes, setFuelTypes] = useState<FuelType[]>(initialFuelTypes);
  const [sortOrder, setSortOrder] = useState(initialSortOrder.toString());
  const [enabled, setEnabled] = useState(initialEnabled);
  const [errors, setErrors] = useState<{
    name?: string;
    interval_days?: string;
    interval_distance?: string;
    fuel_types?: string;
  }>({});

  useImperativeHandle(ref, () => ({
    submit: () => {
      const e: typeof errors = {};
      if (!name.trim()) e.name = "Name is required.";
      if (intervalValue && parseInt(intervalValue, 10) < 1) e.interval_days = "Interval must be at least 1.";
      if (intervalDistance && parseFloat(intervalDistance) < 1)
        e.interval_distance = "Distance must be at least 1.";
      if (fuelTypes.length === 0) e.fuel_types = "Select at least one fuel type.";
      setErrors(e);
      if (Object.keys(e).length === 0) {
        const days = intervalValue ? unitToDays(parseInt(intervalValue, 10), intervalUnit) : null;
        onSubmit({
          name: name.trim(),
          interval_days: days,
          interval_distance: intervalDistance ? parseFloat(intervalDistance) : null,
          fuel_types: fuelTypes,
          sort_order: parseInt(sortOrder, 10) || 0,
          enabled,
        });
      }
    },
  }));

  useEffect(() => {
    const converted = daysToUnit(initialIntervalDays);
    if (converted) {
      setIntervalValue(converted.value.toString());
      setIntervalUnit(converted.unit);
    } else {
      setIntervalValue("");
      setIntervalUnit("day");
    }
  }, [initialIntervalDays]);

  function validate() {
    const e: typeof errors = {};
    if (!name.trim()) e.name = "Name is required.";
    if (intervalValue && parseInt(intervalValue, 10) < 1) e.interval_days = "Interval must be at least 1.";
    if (intervalDistance && parseFloat(intervalDistance) < 1)
      e.interval_distance = "Distance must be at least 1.";
    if (fuelTypes.length === 0) e.fuel_types = "Select at least one fuel type.";
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!validate()) return;
    const days = intervalValue ? unitToDays(parseInt(intervalValue, 10), intervalUnit) : null;
    onSubmit({
      name: name.trim(),
      interval_days: days,
      interval_distance: intervalDistance ? parseFloat(intervalDistance) : null,
      fuel_types: fuelTypes,
      sort_order: parseInt(sortOrder, 10) || 0,
      enabled,
    });
  }

  function toggleFuelType(ft: FuelType) {
    setFuelTypes((prev) =>
      prev.includes(ft) ? prev.filter((f) => f !== ft) : [...prev, ft],
    );
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <Input
        label="Name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        error={errors.name}
        placeholder="e.g. Oil Change"
        maxLength={80}
      />
      <div>
        <div className="flex gap-2">
          <Input
            label="Interval (time)"
            type="number"
            value={intervalValue}
            onChange={(e) => setIntervalValue(e.target.value)}
            placeholder="e.g. 6"
            min={1}
          />
          <Select
            label="Unit"
            value={intervalUnit}
            onChange={(v) => setIntervalUnit(v as IntervalUnit)}
            options={INTERVAL_UNIT_OPTIONS.map((o) => ({ value: o.value, label: o.label }))}
            className="flex-1 min-w-[120px]"
          />
        </div>
        {errors.interval_days && (
          <p className="mt-1 text-xs text-danger">{errors.interval_days}</p>
        )}
      </div>
      <Input
        label="Interval (km)"
        type="number"
        value={intervalDistance}
        onChange={(e) => setIntervalDistance(e.target.value)}
        placeholder="optional"
        min={1}
        step="0.1"
      />
      <div>
        <label className="mb-1.5 block text-sm font-medium text-ink">
          Fuel Types
        </label>
        <div className="flex gap-3">
          {(["petrol", "electric", "hybrid_plugin"] as FuelType[]).map((ft) => (
            <label key={ft} className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={fuelTypes.includes(ft)}
                onChange={() => toggleFuelType(ft)}
                className="rounded border-line-subtle"
              />
              {FUEL_LABELS[ft]}
            </label>
          ))}
        </div>
        {errors.fuel_types && (
          <p className="mt-1 text-xs text-danger">{errors.fuel_types}</p>
        )}
      </div>
      <div className="grid grid-cols-2 gap-4">
        <Input
          label="Sort Order"
          type="number"
          value={sortOrder}
          onChange={(e) => setSortOrder(e.target.value)}
          min={0}
        />
        <label className="flex items-center gap-2 pt-6 text-sm">
          <input
            type="checkbox"
            checked={enabled}
            onChange={(e) => setEnabled(e.target.checked)}
            className="rounded border-line-subtle"
          />
          Enabled
        </label>
      </div>
      {error && <p className="text-sm text-danger">{error}</p>}
    </form>
  );
});

CatalogForm.displayName = "CatalogForm";

function CreateCatalogDialog({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const create = useCreateCatalogItem();
  const formRef = useRef<HTMLFormElement>(null);

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Add catalog item"
      confirmLabel="Create"
      loading={create.isPending}
      onSubmit={() => formRef.current?.submit()}
    >
      <CatalogForm
        ref={formRef}
        initialName=""
        initialIntervalDays={null}
        initialIntervalDistance={null}
        initialFuelTypes={["petrol", "electric", "hybrid_plugin"]}
        initialSortOrder={0}
        initialEnabled={true}
        onSubmit={(data) => {
          create.mutate(data, { onSuccess: onClose });
        }}
        error={create.isError ? (create.error as Error)?.message ?? "Failed to create." : null}
      />
    </Modal>
  );
}

function EditCatalogDialog({
  open,
  item,
  onClose,
}: {
  open: boolean;
  item: {
    id: string;
    catalog_key: string;
    name: string;
    interval_days: number | null;
    interval_distance: number | null;
    fuel_types: FuelType[];
    sort_order: number;
    enabled: boolean;
  };
  onClose: () => void;
}) {
  const update = useUpdateCatalogItem();
  const remove = useDeleteCatalogItem();
  const [deleteConfirm, setDeleteConfirm] = useState(false);
  const formRef = useRef<HTMLFormElement>(null);

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Edit catalog item"
      confirmLabel="Save"
      loading={update.isPending || remove.isPending}
      onSubmit={() => formRef.current?.submit()}
      footer={
        <div className="flex w-full justify-between">
          <Button
            variant="destructive"
            size="sm"
            onClick={() => setDeleteConfirm(true)}
            disabled={remove.isPending}
          >
            Delete item
          </Button>
          <div className="flex gap-2">
            <Button variant="secondary" size="sm" onClick={onClose} disabled={update.isPending}>
              Cancel
            </Button>
            <Button
              variant="primary"
              size="sm"
              onClick={() => formRef.current?.submit()}
              disabled={update.isPending}
            >
              {update.isPending ? "Saving..." : "Save"}
            </Button>
          </div>
        </div>
      }
    >
      <CatalogForm
        ref={formRef}
        initialName={item.name}
        initialIntervalDays={item.interval_days}
        initialIntervalDistance={item.interval_distance}
        initialFuelTypes={item.fuel_types}
        initialSortOrder={item.sort_order}
        initialEnabled={item.enabled}
        onSubmit={(data) => {
          update.mutate({ id: item.id, ...data }, { onSuccess: onClose });
        }}
        error={update.isError ? (update.error as Error)?.message ?? "Failed to update." : null}
      />
      {deleteConfirm && (
        <Modal
          open
          onClose={() => setDeleteConfirm(false)}
          title="Delete catalog item"
          confirmLabel="Delete"
          destructive
          loading={remove.isPending}
          onSubmit={() => {
            remove.mutate(item.id, { onSuccess: onClose });
          }}
        >
          <p className="text-sm text-ink-muted">
            Are you sure you want to delete &ldquo;{item.name}&rdquo;? This action cannot be
            undone.
          </p>
        </Modal>
      )}
    </Modal>
  );
}