"use client";

import { useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Button } from "@dco/ui/components/button";
import { Card } from "@dco/ui/components/card";
import { Input } from "@dco/ui/components/input";
import { PageHeader } from "@dco/ui/components/page-header";
import { Select } from "@dco/ui/components/select";
import { apiGet, apiPost, apiPut } from "@/lib/api/client";
import { useMembers, useVehicles } from "@/lib/api/hooks";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";

type Agreement = {
  id: string;
  kind: "insurance_policy" | "maintenance_agreement";
  responsibleMemberId: string | null;
  archivedAt: string | null;
};
type Term = {
  id: string;
  termNumber: number;
  provider: string;
  startsOn: string;
  endsOn: string;
  reminderLeadDays: number;
  documentId: string | null;
  vehicleIds: string[];
};
type Notice = { termId: string; endsOn: string; attemptedAt: string; sentAt: string | null };
type Mode = "create" | "edit" | "renew" | "owner" | "archive";
const kinds = [
  { value: "insurance_policy", label: "Insurance policy" },
  { value: "maintenance_agreement", label: "Maintenance agreement" },
];
const kindLabel = (kind: Agreement["kind"]) => kinds.find(option => option.value === kind)?.label ?? kind;
const errorText = (error: unknown) => error instanceof Error ? error.message : "The request failed.";

export default function AgreementsPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  if (!orgId || (role !== "org_admin" && role !== "org_manager")) {
    return <PageHeader title="Agreements" description="Fleet admin or manager access is required." />;
  }
  return <Agreements key={orgId} orgId={orgId} admin={role === "org_admin"} />;
}

function Agreements({ orgId, admin }: { orgId: string; admin: boolean }) {
  const base = `/organizations/${orgId}/agreements`;
  const cache = useQueryClient();
  const [selected, setSelected] = useState("");
  const [mode, setMode] = useState<Mode | null>(null);
  const list = useQuery({ queryKey: [base], queryFn: () => apiGet<(Agreement & { currentProvider: string | null })[]>(base) });
  const detail = useQuery({
    queryKey: [base, selected],
    queryFn: () => apiGet<Agreement & { terms: Term[] }>(`${base}/${selected}`),
    enabled: Boolean(selected),
  });
  const notices = useQuery({
    queryKey: [base, selected, "deliveries"],
    queryFn: () => apiGet<Notice[]>(`${base}/${selected}/reminder-deliveries`),
    enabled: admin && Boolean(selected),
  });
  const settings = useQuery({
    queryKey: [base, "timezone"],
    queryFn: () => apiGet<{ timezone: string }>(`/organizations/${orgId}/analytics/settings`),
  });
  const members = useMembers(orgId);
  const vehicles = useVehicles(orgId);
  const agreement = detail.data;
  const current = agreement?.terms[0];
  const today = settings.data && new Intl.DateTimeFormat("en-CA", {
    timeZone: settings.data.timezone, year: "numeric", month: "2-digit", day: "2-digit",
  }).format(new Date());
  const owner = members.data?.items.find(member => member.member_id === agreement?.responsibleMemberId);
  const formOptions = mode && (mode === "create" || agreement) && {
    mode, base, orgId,
    agreement: mode === "create" ? undefined : agreement,
    current: mode === "create" ? undefined : current,
    onSave: async (id: string) => {
      setSelected(id);
      setMode(null);
      await cache.invalidateQueries({ queryKey: [base] });
    },
  };

  return <div className="flex flex-col gap-6">
    <PageHeader title="Agreements" description="Track insurance policies and maintenance agreements." actions={
      <Button onClick={() => setMode("create")}>New agreement</Button>
    } />
    {list.isPending && <p role="status">Loading agreements…</p>}
    {list.isError && <p role="alert">{errorText(list.error)} <Button onClick={() => void list.refetch()}>Retry</Button></p>}
    {list.data?.length === 0 && <Card><p>No agreements yet. Create one to track its expiry and renewal.</p></Card>}
    {Boolean(list.data?.length) && <Select label="Agreement" placeholder="Choose an agreement" value={selected}
      options={list.data?.map(item => ({
        value: item.id,
        label: `${item.currentProvider ?? kindLabel(item.kind)} · ${item.id.slice(0, 8)}${item.archivedAt ? " (archived)" : ""}`,
      })) ?? []} onChange={id => { setSelected(id); setMode(null); }} />}
    {selected && detail.isPending && <p role="status">Loading agreement…</p>}
    {detail.isError && <p role="alert">{errorText(detail.error)} <Button onClick={() => void detail.refetch()}>Retry</Button></p>}
    {formOptions && <AgreementForm key={`${mode}:${selected}`} {...formOptions} onCancel={() => setMode(null)} />}
    {agreement && <Card className="flex flex-col gap-4">
      <h2 className="text-lg font-semibold">{current?.provider ?? kindLabel(agreement.kind)}</h2>
      <p>{kindLabel(agreement.kind)} · {agreement.archivedAt ? "Archived" : current && today ? termStatus(current, today) : "Status unavailable"}</p>
      <p>Responsible member: {members.isError ? "Unavailable" : owner ? `${owner.display_name || owner.email}${owner.status === "active" ? "" : " (inactive)"}` : members.isPending ? "Loading…" : "Unassigned"}</p>
      {!agreement.archivedAt && <div className="flex flex-wrap gap-2">
        {current && <><Button variant="secondary" onClick={() => setMode("edit")}>Edit current term</Button>
          <Button onClick={() => setMode("renew")}>Renew</Button></>}
        {admin && <Button variant="secondary" onClick={() => setMode("owner")}>Reassign owner</Button>}
        <Button variant="destructive" onClick={() => setMode("archive")}>Archive</Button>
      </div>}
      <h3 className="font-semibold">Term history</h3>
      <ul className="flex flex-col gap-3">
        {agreement.terms.map(term => <li key={term.id} className="border-t border-line-strong pt-3">
          <p>Term {term.termNumber} · {term.provider} · {term.startsOn} to {term.endsOn}</p>
          <p>Reminder lead time: {term.reminderLeadDays} days</p>
          <p>Vehicles: {term.vehicleIds.map(id => vehicles.data?.items.find(vehicle => vehicle.id === id)?.name ?? id).join(", ")}</p>
          {term.documentId && <p>Linked document: {term.documentId}</p>}
        </li>)}
      </ul>
      {admin && <section>
        <h3 className="font-semibold">Reminder delivery</h3>
        {notices.isPending && <p role="status">Loading delivery history…</p>}
        {notices.isError && <p role="alert">{errorText(notices.error)}</p>}
        {notices.data?.length === 0 && <p>No delivery attempts yet.</p>}
        <ul>{notices.data?.map(notice => <li key={`${notice.termId}:${notice.endsOn}`}>
          {notice.sentAt ? "Sent" : "Delivery failed"} · expiry {notice.endsOn} · {new Date(notice.attemptedAt).toLocaleString()}
        </li>)}</ul>
      </section>}
    </Card>}
  </div>;
}

function termStatus(term: Term, today: string) {
  if (today < term.startsOn) return "Upcoming";
  if (today > term.endsOn) return "Expired";
  const remaining = (Date.parse(term.endsOn) - Date.parse(today)) / 86_400_000;
  return remaining <= term.reminderLeadDays ? "Renewal due" : "Active";
}

function AgreementForm({ mode, base, agreement, current, orgId, onSave, onCancel }: {
  mode: Mode;
  base: string;
  agreement?: Agreement;
  current?: Term;
  orgId: string;
  onSave: (id: string) => Promise<void>;
  onCancel: () => void;
}) {
  const [kind, setKind] = useState(kinds[0].value);
  const [memberId, setMemberId] = useState(agreement?.responsibleMemberId ?? "");
  const [provider, setProvider] = useState(current?.provider ?? "");
  const [startsOn, setStartsOn] = useState(mode === "edit" ? current?.startsOn ?? "" : "");
  const [endsOn, setEndsOn] = useState(mode === "edit" ? current?.endsOn ?? "" : "");
  const [leadDays, setLeadDays] = useState(String(current?.reminderLeadDays ?? ""));
  const [vehicleIds, setVehicleIds] = useState(current?.vehicleIds ?? []);
  const [documentVehicle, setDocumentVehicle] = useState("");
  const [documentId, setDocumentId] = useState(mode === "edit" ? current?.documentId ?? "" : "");
  const members = useMembers(orgId);
  const vehicles = useVehicles(orgId);
  const writesTerm = mode === "create" || mode === "edit" || mode === "renew";
  const documents = useQuery({
    queryKey: [base, "vehicle-documents", documentVehicle],
    queryFn: () => apiGet<{ id: string; name: string }[]>(`${base}/vehicle-documents/${documentVehicle}`),
    enabled: writesTerm && Boolean(documentVehicle),
  });
  const mutation = useMutation({
    mutationFn: async () => {
      const term = {
        provider, starts_on: startsOn, ends_on: endsOn, reminder_lead_days: Number(leadDays),
        vehicle_ids: vehicleIds, document_id: documentId || undefined,
      };
      if (mode === "create") {
        return (await apiPost<Agreement>(base, { ...term, kind, responsible_member_id: memberId })).id;
      }
      if (!agreement) throw new Error("Choose an agreement.");
      const path = `${base}/${agreement.id}`;
      if (mode === "owner") await apiPut(`${path}/responsible-member`, { responsible_member_id: memberId });
      else if (mode === "archive") await apiPost(`${path}/archive`);
      else {
        const body = { ...term, expected_term_number: current?.termNumber };
        if (mode === "edit") await apiPut(`${path}/current-term`, body);
        else await apiPost(`${path}/renewals`, body);
      }
      return agreement.id;
    },
    onSuccess: onSave,
  });
  const title = { create: "New agreement", edit: "Edit current term", renew: "Renew agreement", owner: "Reassign owner", archive: "Archive agreement" }[mode];
  const needsMember = mode === "create" || mode === "owner";
  const activeMembers = members.data?.items.filter(member => member.status === "active") ?? [];
  const coveredVehicles = vehicles.data?.items.filter(vehicle => vehicleIds.includes(vehicle.id)) ?? [];
  const selectedDocument = documents.data?.find(document => document.id === documentId);
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    mutation.mutate();
  }

  return <Card>
    <form onSubmit={submit} className="flex flex-col gap-4">
      <h2 className="text-lg font-semibold">{title}</h2>
      {mode === "create" && <Select options={kinds} label="Agreement type" value={kind} onChange={setKind} />}
      {needsMember && <>
        <Select label="Responsible member" placeholder="Choose an active member" value={memberId}
          options={activeMembers.map(member => ({ value: member.member_id, label: member.display_name || member.email }))}
          onChange={setMemberId} />
        {members.isError && <p role="alert">{errorText(members.error)}</p>}
      </>}
      {writesTerm && <>
        <Input label="Provider" value={provider} onChange={e => setProvider(e.target.value)} required maxLength={200} />
        <div className="grid gap-4 sm:grid-cols-2">
          <Input type="date" label="Start date" value={startsOn} onChange={e => setStartsOn(e.target.value)} required />
          <Input type="date" label="Expiry date" value={endsOn} min={startsOn || undefined} onChange={e => setEndsOn(e.target.value)} required />
        </div>
        <Input type="number" label="Reminder lead time in days" min={1} max={2147483647} step={1}
          value={leadDays} onChange={e => setLeadDays(e.target.value)} required />
        <div className="flex flex-wrap gap-2">{[30, 60, 90].map(days => <Button key={days} type="button"
          variant="secondary" size="sm" aria-pressed={leadDays === String(days)} onClick={() => setLeadDays(String(days))}>{days} days</Button>)}</div>
        <fieldset className="flex max-h-56 flex-col gap-2 overflow-auto">
          <legend className="font-semibold">Covered vehicles</legend>
          {vehicles.isPending && <p role="status">Loading vehicles…</p>}
          {vehicles.isError && <p role="alert">{errorText(vehicles.error)}</p>}
          {vehicles.data?.items.map(vehicle => <label key={vehicle.id} className="flex items-center gap-2">
            <input type="checkbox" checked={vehicleIds.includes(vehicle.id)} onChange={e => {
              setVehicleIds(e.target.checked ? [...vehicleIds, vehicle.id] : vehicleIds.filter(id => id !== vehicle.id));
              if (!e.target.checked) {
                setDocumentId("");
                if (documentVehicle === vehicle.id) setDocumentVehicle("");
              }
            }} />
            {vehicle.name} · {vehicle.license_plate}
          </label>)}
          {vehicleIds.filter(id => !vehicles.isPending && !vehicles.isError && !vehicles.data?.items.some(vehicle => vehicle.id === id)).map(id =>
            <label key={id} className="flex items-center gap-2"><input type="checkbox" checked
              onChange={() => { setVehicleIds(vehicleIds.filter(value => value !== id)); setDocumentId(""); }} />
              Vehicle no longer in fleet ({id.slice(0, 8)})
            </label>)}
        </fieldset>
        {coveredVehicles.length > 0 && <Select label="Vehicle for document lookup" value={documentVehicle}
          placeholder="Choose a covered vehicle" options={coveredVehicles.map(vehicle => ({ value: vehicle.id, label: vehicle.name }))}
          onChange={setDocumentVehicle} />}
        {documentVehicle && <>
          <Select label="Existing vehicle document" value={selectedDocument ? documentId : ""}
            placeholder={documents.isPending ? "Loading documents…" : "Choose a document"}
            options={documents.data?.map(document => ({ value: document.id, label: document.name })) ?? []}
            onChange={setDocumentId} />
          {documents.isError && <p role="alert">{errorText(documents.error)}</p>}
        </>}
        {documentId && <p>Attachment selected {selectedDocument?.name ?? documentId} <Button type="button" variant="ghost" onClick={() => setDocumentId("")}>Remove</Button></p>}
      </>}
      {mode === "archive" && <p>Archive this agreement and retain its term history. Renewal reminders stop.</p>}
      {mutation.isError && <p role="alert">{errorText(mutation.error)}</p>}
      <div className="flex gap-2">
        <Button type="submit" variant={mode === "archive" ? "destructive" : "primary"}
          disabled={mutation.isPending || (needsMember && !activeMembers.some(member => member.member_id === memberId)) || (writesTerm && !coveredVehicles.length)}>
          {mutation.isPending ? "Saving…" : mode === "archive" ? "Archive agreement" : "Save"}
        </Button>
        <Button type="button" variant="secondary" disabled={mutation.isPending} onClick={onCancel}>Cancel</Button>
      </div>
    </form>
  </Card>;
}
