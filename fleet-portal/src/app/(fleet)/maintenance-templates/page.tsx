"use client";

import Link from "next/link";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { useServiceCatalog } from "@/lib/api/hooks";
import { useOrgId } from "@/lib/auth/session-context";

export default function MaintenanceCatalogPage() {
  const orgId = useOrgId();
  const catalog = useServiceCatalog(orgId);
  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Maintenance catalog" description="Choose suggested services when setting up each vehicle’s reminders." />
      <Link href="/vehicles" className="text-sm text-gold hover:underline">Open vehicle inventory to set up reminders</Link>
      <Card className="p-5">
        {catalog.isLoading && <p>Loading services…</p>}
        {catalog.error && <p role="alert">Could not load services. <button onClick={() => catalog.refetch()}>Retry</button></p>}
        <ul className="divide-y divide-line-subtle">
          {catalog.data?.items.map(item => <li className="py-3" key={item.catalog_key}>{item.name}</li>)}
        </ul>
      </Card>
    </div>
  );
}
