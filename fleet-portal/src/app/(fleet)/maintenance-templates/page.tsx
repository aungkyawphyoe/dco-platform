"use client";

import { useId, useState } from "react";
import Link from "next/link";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Button } from "@dco/ui/components/button";
import { Input } from "@dco/ui/components/input";
import { ServiceDialog } from "@/components/maintenance/service-dialog";
import { useCreateServiceCatalogItem, useServiceCatalog } from "@/lib/api/hooks";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";

export default function MaintenanceCatalogPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const catalog = useServiceCatalog(orgId);
  const [search, setSearch] = useState("");
  const [adding, setAdding] = useState(false);
  const items = catalog.data?.items.filter(item => item.name.toLowerCase().includes(search.trim().toLowerCase())) ?? [];
  const canManage = role === "org_admin" || role === "org_manager";
  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Maintenance catalog" description="Services available when setting up vehicle reminders. Set due targets on each vehicle."
        actions={canManage && <Button onClick={() => setAdding(true)}>Add custom item</Button>} />
      <Card className="overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-4 border-b border-line bg-panel px-5 py-4">
          <h2 className="font-display text-lg font-semibold">Service items <span className="ml-2 font-sans text-sm font-normal text-ink-caption">{catalog.data?.items.length ?? ""}</span></h2>
          <div className="w-full sm:w-72"><Input label="Search services" type="search" value={search} onChange={event => setSearch(event.target.value)} /></div>
        </div>
        {catalog.isLoading && <p className="p-5 text-sm text-ink-caption">Loading services…</p>}
        {catalog.error && <p role="alert" className="p-5 text-sm text-danger">Could not load services. <button className="underline" onClick={() => catalog.refetch()}>Retry</button></p>}
        {!catalog.isLoading && !catalog.error && <>
          <ul className="divide-y divide-line">
            {items.map(item => <li className="flex items-center justify-between gap-4 px-5 py-4 hover:bg-skeleton/50" key={item.catalog_key}>
              <span className="font-medium">{item.name}</span>
              <span className={`shrink-0 rounded-md border px-2 py-1 text-xs ${item.source === "org" ? "border-line-strong text-ink" : "border-line text-ink-caption"}`}>{item.source === "org" ? "Custom" : "Suggested"}</span>
            </li>)}
          </ul>
          {items.length === 0 && <p className="p-5 text-sm text-ink-caption">{search ? "No services match your search. Try another name." : "No service items yet. Add a custom item to get started."}</p>}
        </>}
        <div className="border-t border-line bg-panel px-5 py-4 text-sm text-ink-caption">
          Custom items are shared across your fleet. <Link href="/vehicles" className="text-link underline underline-offset-4">Set up reminders on a vehicle</Link>
        </div>
      </Card>
      {adding && <CreateCatalogItem orgId={orgId} onClose={() => setAdding(false)} />}
    </div>
  );
}

function CreateCatalogItem({ orgId, onClose }: { orgId: string | null; onClose: () => void }) {
  const formId = useId();
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const create = useCreateServiceCatalogItem(orgId);
  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!name.trim()) { setError("Enter a service name."); return; }
    setError(null);
    try { await create.mutateAsync(name.trim()); onClose(); }
    catch (failure) { setError(failure instanceof Error ? failure.message : "Could not add item. Please retry."); }
  }
  return <ServiceDialog title="Add custom item" description="Add a service name for your fleet. Due dates and intervals are set separately on each vehicle."
    onClose={onClose} busy={create.isPending} footer={<>
      <Button variant="secondary" disabled={create.isPending} onClick={onClose}>Cancel</Button>
      <Button type="submit" form={formId} disabled={create.isPending}>{create.isPending ? "Adding…" : "Add custom item"}</Button>
    </>}>
    <form id={formId} onSubmit={submit} className="flex flex-col gap-4">
      <Input autoFocus label="Service name" placeholder="e.g. Hydraulic fluid change" required maxLength={80} value={name} onChange={event => setName(event.target.value)} />
      {error && <p role="alert" className="text-sm text-danger">{error}</p>}
    </form>
  </ServiceDialog>;
}
