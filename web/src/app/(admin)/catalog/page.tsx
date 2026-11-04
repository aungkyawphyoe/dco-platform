"use client";

import { useState } from "react";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Button } from "@dco/ui/components/button";
import { Input } from "@dco/ui/components/input";
import { Modal } from "@dco/ui/components/modal";
import { EmptyState } from "@dco/ui/components/empty-state";
import { SkeletonTable } from "@dco/ui/components/skeleton";
import { Badge } from "@dco/ui/components/badge";
import { Table, TableHead, TableBody, TableRow, TableHeadCell, TableCell } from "@dco/ui/components/table";
import { useCatalogItems, useCreateCatalogItem, useUpdateCatalogItem, useDeleteCatalogItem } from "@/lib/api/hooks";

type CatalogItem = { id: string; name: string; enabled: boolean };

export default function CatalogPage() {
  const { data, isLoading, error } = useCatalogItems();
  const [editing, setEditing] = useState<CatalogItem | "new" | null>(null);
  const items = data?.items ?? [];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Maintenance Catalog" description="Manage suggested service names for all vehicles"
        actions={<Button size="sm" onClick={() => setEditing("new")}>Add item</Button>} />
      {error ? <Card className="p-6"><p role="alert">Failed to load catalog. Please try again.</p></Card>
        : isLoading ? <Card className="p-5"><SkeletonTable rows={5} cols={3} /></Card>
        : items.length === 0 ? <Card><EmptyState title="No catalog items" description="Add your first suggested service name."
          action={<Button onClick={() => setEditing("new")}>Add item</Button>} /></Card>
        : <Card><Table>
          <TableHead><TableRow><TableHeadCell>Name</TableHeadCell><TableHeadCell>Status</TableHeadCell><TableHeadCell>Actions</TableHeadCell></TableRow></TableHead>
          <TableBody>{items.map((item) => <TableRow key={item.id}>
            <TableCell>{item.name}</TableCell>
            <TableCell><Badge tone={item.enabled ? "success" : "neutral"}>{item.enabled ? "Active" : "Disabled"}</Badge></TableCell>
            <TableCell><Button variant="secondary" size="sm" onClick={() => setEditing(item)}>Edit</Button></TableCell>
          </TableRow>)}</TableBody>
        </Table></Card>}
      {editing && <CatalogDialog key={editing === "new" ? "new" : editing.id}
        item={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
    </div>
  );
}

function CatalogDialog({ item, onClose }: { item: CatalogItem | null; onClose: () => void }) {
  const create = useCreateCatalogItem();
  const update = useUpdateCatalogItem();
  const remove = useDeleteCatalogItem();
  const [name, setName] = useState(item?.name ?? "");
  const [enabled, setEnabled] = useState(item?.enabled ?? true);
  const [validation, setValidation] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const pending = create.isPending || update.isPending || remove.isPending;
  const mutationError = create.error || update.error || remove.error;

  function save() {
    const trimmed = name.trim();
    if (!trimmed || trimmed.length > 80) {
      setValidation("Enter a service name of 1–80 characters.");
      return;
    }
    const body = { name: trimmed, enabled };
    if (item) update.mutate({ id: item.id, ...body }, { onSuccess: onClose });
    else create.mutate(body, { onSuccess: onClose });
  }

  return <>
    <Modal open onClose={onClose} title={item ? "Edit catalog item" : "Add catalog item"}
      confirmLabel={item ? "Save" : "Create"} loading={pending} onSubmit={save}>
      <form className="flex flex-col gap-4" onSubmit={(event) => { event.preventDefault(); save(); }}>
        <Input label="Service name" value={name} onChange={(event) => setName(event.target.value)}
          maxLength={80} placeholder="e.g. Oil Change" error={validation ?? undefined} />
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={enabled}
          onChange={(event) => setEnabled(event.target.checked)} />Enabled</label>
        {mutationError && <p className="text-sm text-danger" role="alert">{mutationError.message}</p>}
        {item && <Button type="button" variant="destructive" disabled={pending} onClick={() => setConfirmDelete(true)}>Delete item</Button>}
      </form>
    </Modal>
    {confirmDelete && item && <Modal open onClose={() => setConfirmDelete(false)} title="Delete catalog item"
      confirmLabel="Delete" destructive loading={remove.isPending}
      onSubmit={() => remove.mutate(item.id, { onSuccess: onClose })}>
      <p>Remove {item.name} from suggested services? Existing reminders and service history will be preserved.</p>
    </Modal>}
  </>;
}
