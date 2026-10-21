"use client";

import { useRef, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Button } from "@dco/ui/components/button";
import { Card } from "@dco/ui/components/card";
import { Input } from "@dco/ui/components/input";
import { Modal } from "@dco/ui/components/modal";
import { Select } from "@dco/ui/components/select";
import { SectionHeading } from "@dco/ui/components/section-heading";
import { apiDownload, apiGet, apiRequest } from "@/lib/api/client";
import { parseApiError } from "@/lib/api/errors";

type VehicleDocument = {
  id: string; revision: number; name: string; category: string;
  notes: string | null; expires_on: string | null; media_id: string | null;
  links: { kind: string; record_id: string }[];
};
type Draft = { id: string; mediaId?: string; name: string; category: string; notes: string; expiry: string; file?: File; existing?: VehicleDocument };
const categories = ["insurance", "registration", "invoice", "warranty", "receipt", "other"].map(value => ({ value, label: value[0].toUpperCase() + value.slice(1) }));
const mib = (bytes: number) => `${(bytes / 1048576).toFixed(1)} MiB`;

export function VehicleDocuments({ orgId, vehicleId }: { orgId: string; vehicleId: string }) {
  const client = useQueryClient();
  const base = `/organizations/${orgId}/records`;
  const key = ["vehicle-documents", orgId, vehicleId];
  const docs = useQuery({ queryKey: key, queryFn: () => apiGet<{ items: VehicleDocument[] }>(`${base}/vehicles/${vehicleId}/documents`) });
  const usage = useQuery({ queryKey: ["document-storage", orgId], queryFn: () => apiGet<{ used_bytes: number; limit_bytes: number }>(`/organizations/${orgId}/storage`) });
  const [draft, setDraft] = useState<Draft | null>(null);
  const [deleting, setDeleting] = useState<VehicleDocument | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inFlight = useRef(false);
  async function refresh() {
    await Promise.all([client.invalidateQueries({ queryKey: key }), client.invalidateQueries({ queryKey: ["document-storage", orgId] })]);
  }
  async function run(action: () => Promise<void>) {
    if (inFlight.current) return;
    inFlight.current = true;
    setBusy(true); setError(null);
    try { await action(); } catch (e) { setError(e instanceof Error ? e.message : "Could not complete the document action."); }
    finally { inFlight.current = false; setBusy(false); }
  }
  async function save() {
    if (!draft) return;
    const current = draft;
    await run(async () => {
      if (!current.name.trim()) throw new Error("Enter a document name.");
      let mediaId = current.mediaId;
      if (!current.existing && !mediaId) {
        if (!current.file) throw new Error("Choose an image or PDF.");
        if (current.file.size > 15 * 1048576) throw new Error("Choose a file no larger than 15 MiB.");
        const data = new FormData();
        data.append("id", current.id); data.append("purpose", "document"); data.append("vehicle_id", vehicleId);
        data.append("file", current.file);
        const uploaded = await apiRequest("/media", { method: "POST", body: data });
        if (!uploaded.ok) throw await parseApiError(uploaded);
        mediaId = (await uploaded.json() as { id: string }).id;
        setDraft(value => value ? { ...value, mediaId } : value);
      }
      const response = await apiRequest(current.existing ? `${base}/documents/${current.id}` : `${base}/vehicles/${vehicleId}/documents`, {
        method: current.existing ? "PATCH" : "POST",
        headers: current.existing ? { "If-Match": String(current.existing.revision) } : {},
        body: JSON.stringify({ ...(current.existing ? {} : { id: current.id, media_id: mediaId }), name: current.name.trim(), category: current.category, notes: current.notes.trim() || null, expires_on: current.expiry || null }),
      });
      if (!response.ok) throw await parseApiError(response);
      setDraft(null); await refresh();
    });
  }
  async function download(doc: VehicleDocument) {
    await run(async () => {
      const blob = await apiDownload(`/organizations/${orgId}/media/${doc.media_id}/content`);
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement("a"); anchor.href = url;
      const extension = ({ "application/pdf": "pdf", "image/jpeg": "jpg", "image/png": "png", "image/heic": "heic" } as Record<string, string>)[blob.type];
      anchor.download = extension ? `${doc.name}.${extension}` : doc.name;
      anchor.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
    });
  }
  return <Card>
    <SectionHeading title="Documents" count={docs.data?.items.length}>
      <Button size="sm" disabled={busy} onClick={() => { setError(null); setDraft({ id: crypto.randomUUID(), name: "", category: "other", notes: "", expiry: "" }); }}>Add document</Button>
    </SectionHeading>
    <div className="space-y-4 p-5">
      {usage.data && <p className="text-sm text-ink-caption">Organization storage: {mib(usage.data.used_bytes)} of {mib(usage.data.limit_bytes)} used. Shared across all vehicles.</p>}
      {usage.error && <p role="alert" className="text-danger">Storage usage could not be loaded.</p>}
      {docs.isLoading && <p>Loading documents…</p>}
      {docs.error && <p role="alert" className="text-danger">{docs.error.message} <button onClick={() => void docs.refetch()}>Retry</button></p>}
      {docs.data?.items.length === 0 && <p className="text-sm text-ink-caption">No documents yet. Add insurance, registration, invoices, or other vehicle files.</p>}
      <ul className="divide-y divide-line-subtle">{docs.data?.items.map(doc => <li key={doc.id} className="flex flex-wrap items-center justify-between gap-3 py-3">
        <div><p className="font-medium text-ink">{doc.name}</p><p className="text-xs text-ink-caption">{categories.find(c => c.value === doc.category)?.label}{doc.expires_on ? ` · Expires ${doc.expires_on}` : ""}{doc.links.length ? ` · Attached to ${doc.links.length} log(s)` : ""}</p>{doc.notes && <p className="text-sm text-ink-muted">{doc.notes}</p>}</div>
        <div className="flex gap-2">
          <Button size="sm" variant="secondary" disabled={busy || !doc.media_id} onClick={() => void download(doc)}>Download</Button>
          <Button size="sm" variant="secondary" disabled={busy} onClick={() => { setError(null); setDraft({ id: doc.id, existing: doc, name: doc.name, category: doc.category, notes: doc.notes ?? "", expiry: doc.expires_on ?? "" }); }}>Edit</Button>
          <Button size="sm" variant="destructive" disabled={busy} onClick={() => { setError(null); setDeleting(doc); }}>Delete</Button>
        </div>
      </li>)}</ul>
      {error && !draft && !deleting && <p role="alert" className="text-danger">{error}</p>}
    </div>
    <Modal open={!!draft} title={draft?.existing ? "Edit document" : "Add document"} onClose={() => { if (!busy) setDraft(null); }} confirmLabel="Save document" loading={busy} onSubmit={() => void save()}>
      {draft && <div className="space-y-4">
        <Input label="Name" maxLength={120} value={draft.name} disabled={busy} onChange={e => setDraft({ ...draft, name: e.target.value })} />
        <Select label="Category" options={categories} value={draft.category} disabled={busy} onChange={category => setDraft({ ...draft, category })} />
        <Input label="Expiry date (optional)" type="date" value={draft.expiry} disabled={busy} onChange={e => setDraft({ ...draft, expiry: e.target.value })} />
        <Input label="Notes (optional)" value={draft.notes} disabled={busy} onChange={e => setDraft({ ...draft, notes: e.target.value })} />
        {!draft.existing && <Input label="Image or PDF (up to 15 MiB)" type="file" accept=".jpg,.jpeg,.png,.heic,.pdf" disabled={busy || !!draft.mediaId} onChange={e => setDraft({ ...draft, file: e.target.files?.[0] })} />}
        {draft.mediaId && <p>File uploaded. Save to finish adding the document.</p>}
        {error && <p role="alert" className="text-danger">{error}</p>}
      </div>}
    </Modal>
    <Modal open={!!deleting} title="Permanently delete document?" destructive confirmLabel="Delete document" loading={busy} onClose={() => { if (!busy) setDeleting(null); }} onSubmit={() => void run(async () => {
      if (!deleting) return;
      const response = await apiRequest(`${base}/documents/${deleting.id}`, { method: "DELETE", headers: { "If-Match": String(deleting.revision) } });
      if (!response.ok) throw await parseApiError(response);
      setDeleting(null); await refresh();
    })}>
      <p>Delete “{deleting?.name}” and its file permanently? The following attachments will be removed; the logs remain.</p>
      <ul className="mt-3 break-all">{deleting?.links.map(link => <li key={`${link.kind}:${link.record_id}`}>{link.kind === "fuel_log" ? "Fuel log" : "Service"}: {link.record_id}</li>)}</ul>
      {error && <p role="alert" className="mt-3 text-danger">{error}</p>}
    </Modal>
  </Card>;
}
