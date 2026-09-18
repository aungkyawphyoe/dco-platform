"use client";

import { useState } from "react";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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

const FUEL_LABELS: Record<FuelType, string> = {
  petrol: "Petrol",
  electric: "Electric",
  hybrid_plugin: "Hybrid",
};

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
          <p className="text-sm text-danger">
            Failed to load catalog. Please try again.
          </p>
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
                      ? `${item.interval_distance.toLocaleString()}mi`
                      : "—"}
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-wrap gap-1">
                      {item.fuel_types.map((ft) => (
                        <Badge key={ft} variant="secondary">
                          {FUEL_LABELS[ft] ?? ft}
                        </Badge>
                      ))}
                    </div>
                  </TableCell>
                  <TableCell className="text-ink-muted">
                    {item.sort_order}
                  </TableCell>
                  <TableCell>
                    <Badge
                      variant={item.enabled ? "default" : "destructive"}
                    >
                      {item.enabled ? "Active" : "Disabled"}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setEditItem(item)}
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

      <CreateCatalogDialog
        open={showCreate}
        onClose={() => setShowCreate(false)}
      />

      {editItem && (
        <EditCatalogDialog
          open
          item={editItem}
          onClose={() => setEditItem(null)}
        />
      )}
    </div>
  );
}

function CatalogForm({
  initialName,
  initialKey,
  initialIntervalDays,
  initialIntervalDistance,
  initialFuelTypes,
  initialSortOrder,
  initialEnabled,
  keyDisabled,
  onSubmit,
  loading,
  error,
  submitLabel,
}: {
  initialName: string;
  initialKey: string;
  initialIntervalDays: number | null;
  initialIntervalDistance: number | null;
  initialFuelTypes: FuelType[];
  initialSortOrder: number;
  initialEnabled: boolean;
  keyDisabled?: boolean;
  onSubmit: (data: {
    catalog_key: string;
    name: string;
    interval_days: number | null;
    interval_distance: number | null;
    fuel_types: FuelType[];
    sort_order: number;
    enabled: boolean;
  }) => void;
  loading: boolean;
  error: string | null;
  submitLabel: string;
}) {
  const [name, setName] = useState(initialName);
  const [catalogKey, setCatalogKey] = useState(initialKey);
  const [intervalDays, setIntervalDays] = useState(
    initialIntervalDays?.toString() ?? "",
  );
  const [intervalDistance, setIntervalDistance] = useState(
    initialIntervalDistance?.toString() ?? "",
  );
  const [fuelTypes, setFuelTypes] = useState<FuelType[]>(initialFuelTypes);
  const [sortOrder, setSortOrder] = useState(initialSortOrder.toString());
  const [enabled, setEnabled] = useState(initialEnabled);
  const [errors, setErrors] = useState<{
    name?: string;
    catalog_key?: string;
    fuel_types?: string;
  }>({});

  function validate() {
    const e: typeof errors = {};
    if (!name.trim()) e.name = "Name is required.";
    if (!catalogKey.trim()) e.catalog_key = "Key is required.";
    if (fuelTypes.length === 0) e.fuel_types = "Select at least one fuel type.";
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  function handleSubmit() {
    if (!validate()) return;
    onSubmit({
      catalog_key: catalogKey.trim(),
      name: name.trim(),
      interval_days: intervalDays ? parseInt(intervalDays, 10) : null,
      interval_distance: intervalDistance
        ? parseFloat(intervalDistance)
        : null,
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
    <div className="flex flex-col gap-4">
      <Input
        label="Name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        error={errors.name}
        placeholder="e.g. Oil Change"
        maxLength={80}
      />
      <Input
        label="Catalog Key"
        value={catalogKey}
        onChange={(e) => setCatalogKey(e.target.value)}
        error={errors.catalog_key}
        placeholder="e.g. oil_change"
        maxLength={50}
        disabled={keyDisabled}
      />
      <div className="grid grid-cols-2 gap-4">
        <Input
          label="Interval (days)"
          type="number"
          value={intervalDays}
          onChange={(e) => setIntervalDays(e.target.value)}
          placeholder="optional"
          min={1}
        />
        <Input
          label="Interval (miles)"
          type="number"
          value={intervalDistance}
          onChange={(e) => setIntervalDistance(e.target.value)}
          placeholder="optional"
          min={1}
        />
      </div>
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
      <div className="flex justify-end">
        <Button onClick={handleSubmit} disabled={loading}>
          {loading ? "Saving..." : submitLabel}
        </Button>
      </div>
    </div>
  );
}

function CreateCatalogDialog({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const create = useCreateCatalogItem();

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Add catalog item"
      confirmLabel="Create"
      loading={create.isPending}
      onSubmit={() => {}}
    >
      <CatalogForm
        initialName=""
        initialKey=""
        initialIntervalDays={null}
        initialIntervalDistance={null}
        initialFuelTypes={["petrol", "electric", "hybrid_plugin"]}
        initialSortOrder={0}
        initialEnabled
        onSubmit={(data) => {
          create.mutate(data, { onSuccess: onClose });
        }}
        loading={create.isPending}
        error={create.isError ? (create.error as Error)?.message ?? "Failed to create." : null}
        submitLabel="Create"
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

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Edit catalog item"
      confirmLabel="Save"
      loading={update.isPending}
      onSubmit={() => {}}
    >
      <CatalogForm
        initialName={item.name}
        initialKey={item.catalog_key}
        initialIntervalDays={item.interval_days}
        initialIntervalDistance={item.interval_distance}
        initialFuelTypes={item.fuel_types}
        initialSortOrder={item.sort_order}
        initialEnabled={item.enabled}
        keyDisabled
        onSubmit={(data) => {
          update.mutate(
            { id: item.id, ...data },
            { onSuccess: onClose },
          );
        }}
        loading={update.isPending}
        error={update.isError ? (update.error as Error)?.message ?? "Failed to update." : null}
        submitLabel="Save"
      />
      <div className="mt-4 border-t border-line-subtle pt-4">
        <Button
          variant="destructive"
          size="sm"
          onClick={() => {
            if (confirm("Delete this catalog item?")) {
              remove.mutate(item.id, { onSuccess: onClose });
            }
          }}
        >
          Delete item
        </Button>
      </div>
    </Modal>
  );
}
