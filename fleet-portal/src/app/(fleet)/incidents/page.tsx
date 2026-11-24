"use client";

import { useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Card } from "@dco/ui/components/card";
import { Button } from "@dco/ui/components/button";
import { Input } from "@dco/ui/components/input";
import { PageHeader } from "@dco/ui/components/page-header";
import { Select } from "@dco/ui/components/select";
import { apiDownload, apiGet, apiPatch, apiPost, apiPut, apiRequest } from "@/lib/api/client";
import { parseApiError } from "@/lib/api/errors";
import type { components, paths } from "@/lib/api/schema";
import { useVehicles, useMembers } from "@/lib/api/hooks";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";

const categories = ["accident", "breakdown", "damage", "other"];
const readable = (value: string) => value.replaceAll("_", " ");
const message = (error: unknown) => error instanceof Error ? error.message : "Request failed.";
type Incident = components["schemas"]["FleetIncident"];
type Detail = paths["/organizations/{id}/incidents/{incidentId}"]["get"]["responses"][200]["content"]["application/json"];
type Repair = Detail["repairs"][number];
const options = (values: string[]) => values.map(value => ({ value, label: readable(value) }));
const localInput = (date: Date) => new Date(date.getTime() - date.getTimezoneOffset() * 60_000).toISOString().slice(0, 16);

export default function IncidentsPage() {
  const org = useOrgId();
  const role = useOrgRole();
  if (!org || !role || !["org_admin", "org_manager", "org_mechanic"].includes(role)) {
    return <PageHeader title="Incidents" description="Fleet staff access is required." />;
  }
  return <Incidents key={org} org={org} manage={role !== "org_mechanic"} />;
}

function Incidents({ org, manage }: { org: string; manage: boolean }) {
  const base = `/organizations/${org}/incidents`;
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState("");
  const [editing, setEditing] = useState<"new" | "edit" | null>(null);
  const cache = useQueryClient();
  const refresh = () => cache.invalidateQueries({ queryKey: [base] });
  const list = useQuery({ queryKey: [base, "list", page], queryFn: () => apiGet<{ items: Incident[]; hasMore: boolean }>(`${base}?page=${page}`) });
  const detail = useQuery({ queryKey: [base, selected], queryFn: () => apiGet<Detail>(`${base}/${selected}`), enabled: !!selected });
  const vehicles = useVehicles(org);
  const members = useMembers(org, manage);
  const vehicleName = (id: string) => vehicles.data?.items.find(v => v.id === id)?.name ?? id;
  const person = (id: string | null) => {
    const member = members.data?.items.find(m => m.user_id === id);
    return member?.display_name || member?.email || id || "Unconfirmed";
  };
  const incident = detail.data;

  return <div className="flex flex-col gap-5">
    <PageHeader title="Incidents" description="Review vehicle incidents and the work orders they generate."
      actions={manage ? <Button onClick={() => setEditing("new")}>Report incident</Button> : undefined} />
    {list.isPending && <p role="status">Loading incidents…</p>}
    {list.isError && <p role="alert">{message(list.error)} <Button onClick={() => void list.refetch()}>Retry</Button></p>}
    {list.data?.items.length === 0 && <Card>No incidents to show.</Card>}
    <ul className="flex flex-col gap-2">{list.data?.items.map(item => <li key={item.id}>
      <Button aria-pressed={selected === item.id} variant={selected === item.id ? "primary" : "secondary"} onClick={() => { setSelected(item.id); setEditing(null); }}>
        {vehicleName(item.vehicleId)} · {readable(item.category)} · {new Date(item.eventAt).toLocaleString()} · {item.closedAt ? "Closed" : "Open"}
      </Button>
    </li>)}</ul>
    {(page > 1 || list.data?.hasMore) && <div className="flex gap-2">
      <Button variant="secondary" disabled={page === 1} onClick={() => setPage(page - 1)}>Previous</Button>
      <Button variant="secondary" disabled={!list.data?.hasMore} onClick={() => setPage(page + 1)}>Next</Button>
    </div>}
    {editing && <IncidentForm key={editing === "new" ? "new" : selected} base={base} org={org}
      incident={editing === "edit" ? incident : undefined}
      onCancel={() => setEditing(null)} onSave={async id => {
        setSelected(id); setPage(1); setEditing(null); await refresh();
      }} />}
    {selected && detail.isPending && <p role="status">Loading incident…</p>}
    {detail.isError && <p role="alert">{message(detail.error)}</p>}
    {incident && <Card className="flex flex-col gap-4">
      <h2 className="text-xl font-semibold">{vehicleName(incident.vehicleId)} · {readable(incident.category)}</h2>
      <p>{new Date(incident.eventAt).toLocaleString()} · {incident.closedAt ? "Closed" : "Open"}</p>
      <p className="whitespace-pre-wrap">{incident.description}</p>
      {manage && <p>Driver at event: {person(incident.driverAtEventId)}</p>}
      {incident.closedAt && <p>Reviewed {new Date(incident.closedAt).toLocaleString()}{manage && incident.closedBy ? ` by ${person(incident.closedBy)}` : ""}{incident.reviewNote ? ` · ${incident.reviewNote}` : ""}</p>}
      <div className="flex flex-wrap gap-2">{incident.photoIds.map((id, index) => <IncidentPhoto key={id} path={`${base}/${incident.id}/photos/${id}`} number={index + 1} />)}</div>
      <h3 className="font-semibold">Linked work orders</h3>
      {incident.repairs.length === 0 ? <p>No linked work orders.</p> : <ul className="list-disc pl-5">
        {incident.repairs.map(repair => <li key={repair.id}><a className="underline" href={`/work-orders#order-${repair.id}`}>{repair.description}</a> · {readable(repair.status)}</li>)}
      </ul>}
      {manage && <IncidentActions key={incident.id} org={org} path={`${base}/${incident.id}`} incident={incident}
        refresh={refresh} edit={() => setEditing("edit")} />}
    </Card>}
  </div>;
}

function IncidentPhoto({ path, number }: { path: string; number: number }) {
  const download = useMutation({ mutationFn: async () => {
    const blob = await apiDownload(path);
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `incident-photo-${number}.${blob.type === "image/png" ? "png" : blob.type === "image/heic" ? "heic" : "jpg"}`;
    anchor.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  } });
  return <div><Button variant="secondary" disabled={download.isPending} onClick={() => download.mutate()}>Download photo {number}</Button>
    {download.isError && <p role="alert">{message(download.error)}</p>}</div>;
}

function IncidentForm({ base, org, incident, onSave, onCancel }: {
  base: string; org: string; incident?: Incident; onSave: (id: string) => Promise<void>; onCancel: () => void;
}) {
  const vehicles = useVehicles(org);
  const members = useMembers(org);
  const [vehicle, setVehicle] = useState(incident?.vehicleId ?? "");
  const [time, setTime] = useState(() => localInput(incident ? new Date(incident.eventAt) : new Date()));
  const [category, setCategory] = useState(incident?.category ?? categories[0]);
  const [description, setDescription] = useState(incident?.description ?? "");
  const [driver, setDriver] = useState(incident?.driverAtEventId ?? "");
  const [photos, setPhotos] = useState<{ file: File; id: string }[]>([]);
  const [id] = useState(() => crypto.randomUUID());
  const validTime = Boolean(time && Number.isFinite(Date.parse(time)));
  const suggestions = useQuery({
    queryKey: [base, "driver-suggestions", vehicle, time],
    queryFn: () => apiGet<{ id: string; name: string | null }[]>(`${base}/driver-suggestions?${new URLSearchParams({ vehicle_id: vehicle, event_at: new Date(time).toISOString() })}`),
    enabled: !!vehicle && validTime,
  });
  const save = useMutation({
    mutationFn: async () => {
      const fields = { category, description, event_at: incident && time === localInput(new Date(incident.eventAt)) ? undefined : new Date(time).toISOString(), driver_at_event_id: driver || (incident ? null : undefined) };
      if (incident) return apiPatch<Incident>(`${base}/${incident.id}`, fields);
      for (const photo of photos) {
        const form = new FormData();
        form.append("id", photo.id);
        form.append("purpose", "incident_photo");
        form.append("vehicle_id", vehicle);
        form.append("file", photo.file);
        const response = await apiRequest("/media", { method: "POST", body: form });
        if (!response.ok) throw await parseApiError(response);
      }
      return apiPost<Incident>(base, { ...fields, id, vehicle_id: vehicle, photo_ids: photos.map(photo => photo.id) });
    },
    onSuccess: data => onSave(data.id),
  });
  function submit(e: FormEvent<HTMLFormElement>) { e.preventDefault(); save.mutate(); }
  const suggested = suggestions.data ?? [];
  const knownDrivers = members.data?.items.filter(member => member.role === "org_driver") ?? [];
  const driverOptions = [...new Set([...suggested.map(item => item.id), ...knownDrivers.map(item => item.user_id), ...(driver ? [driver] : [])])]
    .map(value => {
      const suggestion = suggested.find(item => item.id === value);
      const member = knownDrivers.find(item => item.user_id === value);
      return { value, label: `${suggestion?.name || member?.display_name || member?.email || value}${suggestion ? " (assigned at event)" : ""}` };
    });
  return <Card><form onSubmit={submit} className="flex flex-col gap-3">
    <h2 className="text-lg font-semibold">{incident ? "Edit incident" : "Report incident"}</h2>
    {!incident && <Select label="Vehicle" value={vehicle} onChange={value => { setVehicle(value); setDriver(""); setPhotos([]); }}
      placeholder="Choose a vehicle" options={vehicles.data?.items.map(v => ({ value: v.id, label: `${v.name} · ${v.license_plate}` })) ?? []} />}
    {!incident && vehicles.isError && <p role="alert">{message(vehicles.error)}</p>}
    <Select label="Category" value={category} onChange={setCategory} options={options(categories)} />
    <Input label="Event time (local)" type="datetime-local" required value={time} onChange={e => setTime(e.target.value)} />
    <label className="flex flex-col gap-1">Description<textarea className="rounded border border-line-strong bg-field p-2" required maxLength={2000} value={description} onChange={e => setDescription(e.target.value)} /></label>
    <Select label="Driver at event" value={driver} onChange={setDriver} placeholder="Unconfirmed" options={driverOptions} />
    {suggestions.isError && <p role="alert">{message(suggestions.error)}</p>}
    {!incident && <Input key={vehicle} type="file" label="Photos (up to five)" accept="image/jpeg,image/png,image/heic" multiple
      onChange={e => setPhotos(Array.from(e.target.files ?? []).map(file => ({ file, id: crypto.randomUUID() })))} />}
    {photos.length > 5 && <p role="alert">Choose at most five photos.</p>}
    {save.isError && <p role="alert">{message(save.error)}</p>}
    <div className="flex gap-2"><Button type="submit" disabled={save.isPending || !vehicle || !validTime || !description.trim() || photos.length > 5}>
      {save.isPending ? "Saving…" : "Save incident"}
    </Button><Button type="button" variant="secondary" disabled={save.isPending} onClick={onCancel}>Cancel</Button></div>
  </form></Card>;
}

function IncidentActions({ org, path, incident, refresh, edit }: {
  org: string; path: string; incident: Detail; refresh: () => Promise<void>; edit: () => void;
}) {
  const [note, setNote] = useState("");
  const [repairId, setRepairId] = useState("");
  const [createRepair, setCreateRepair] = useState(false);
  const [newRepairId, setNewRepairId] = useState(() => crypto.randomUUID());
  const [description, setDescription] = useState("");
  const [odometer, setOdometer] = useState("");
  const [issue, setIssue] = useState("other");
  const [urgency, setUrgency] = useState("medium");
  const orders = useQuery({ queryKey: [path, "available-work-orders"],
    queryFn: () => apiGet<{ items: (Repair & { vehicle_id: string })[] }>(`/organizations/${org}/work-orders`), enabled: !incident.closedAt });
  const action = useMutation({
    mutationFn: async (type: "close" | "reopen" | "link" | "create") => {
      if (type === "link") return apiPut(`${path}/work-orders/${repairId}`, {});
      if (type === "create") return apiPost(`${path}/work-orders`, {
        id: newRepairId, description, odometer_km: Number(odometer), issue_type: issue, urgency,
      });
      return apiPost(`${path}/${type}`, type === "close" ? { review_note: note } : {});
    },
    onSuccess: async (_, type) => {
      if (type === "link") setRepairId("");
      if (type === "create") { setCreateRepair(false); setNewRepairId(crypto.randomUUID()); setDescription(""); setOdometer(""); }
      if (type === "close") setNote("");
      await refresh();
    },
  });
  return <div className="flex flex-col gap-3">
    {action.isError && <p role="alert">{message(action.error)}</p>}
    {incident.closedAt ? <Button disabled={action.isPending} onClick={() => action.mutate("reopen")}>Reopen incident</Button> : <>
      <Button variant="secondary" onClick={edit}>Edit incident</Button>
      <div className="flex flex-wrap items-end gap-2">
        <Select label="Existing work order" placeholder="Choose a work order" value={repairId} onChange={setRepairId}
          options={orders.data?.items.filter(order => order.vehicle_id === incident.vehicleId && !incident.repairs.some(linked => linked.id === order.id))
            .map(order => ({ value: order.id, label: order.description })) ?? []} />
        <Button variant="secondary" disabled={action.isPending || !repairId} onClick={() => action.mutate("link")}>Link work order</Button>
        <Button variant="secondary" onClick={() => setCreateRepair(value => !value)}>{createRepair ? "Cancel new work order" : "Create work order"}</Button>
      </div>
      {orders.isError && <p role="alert">{message(orders.error)}</p>}
      {createRepair && <form className="flex flex-col gap-2" onSubmit={e => { e.preventDefault(); action.mutate("create"); }}>
        <Input label="Repair description" value={description} onChange={e => setDescription(e.target.value)} required minLength={10} maxLength={2000} />
        <Input label="Odometer (km)" type="number" required min={0} step={1} value={odometer} onChange={e => setOdometer(e.target.value)} />
        <Select label="Issue type" options={options(["breakdown", "accident", "wear_tear", "scheduled_service", "other"])} value={issue} onChange={setIssue} />
        <Select label="Urgency" options={options(["low", "medium", "high", "critical"])} value={urgency} onChange={setUrgency} />
        <Button type="submit" disabled={action.isPending}>Save work order</Button>
      </form>}
      <Input label="Review note (optional)" value={note} onChange={e => setNote(e.target.value)} maxLength={2000} />
      <Button disabled={action.isPending} onClick={() => action.mutate("close")}>Close incident</Button>
    </>}
  </div>;
}
