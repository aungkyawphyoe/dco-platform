"use client";

import { useId, useState } from "react";
import { Button } from "@dco/ui/components/button";
import { Card } from "@dco/ui/components/card";
import { Input } from "@dco/ui/components/input";
import { useSaveReminder, useServiceCatalog, type SuggestedService } from "@/lib/api/hooks";
import { ServiceDialog } from "@/components/maintenance/service-dialog";
import type { VehiclePlanItem } from "@/lib/api/types";

type Selection = { suggestion?: SuggestedService; existing?: VehiclePlanItem };

export function ReminderSetup({ orgId, vehicleId, items, canManage }: {
  orgId: string | null;
  vehicleId: string;
  items: VehiclePlanItem[];
  canManage: boolean;
}) {
  const catalog = useServiceCatalog(orgId);
  const [search, setSearch] = useState("");
  const [picking, setPicking] = useState(false);
  const [selection, setSelection] = useState<Selection | null>(null);
  return (
    <Card className="p-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 className="font-display text-lg font-semibold">Maintenance reminders</h2>
        {canManage && <div className="flex flex-wrap gap-2">
          <Button variant="secondary" onClick={() => setSelection({})}>Create custom service item</Button>
          <Button onClick={() => { setSearch(""); setPicking(true); }}>Add suggested item</Button>
        </div>}
      </div>
      {items.length === 0 && <p className="mt-4 text-sm text-ink-caption">Add the services this vehicle needs and set their next due targets.</p>}
      <ul className="mt-4 divide-y divide-line-subtle">
        {items.map(item => (
          <li key={item.id} className="flex items-center justify-between gap-4 py-3">
            <div>
              <p className="font-medium">{item.name}{!item.enabled && " (disabled)"}</p>
              <p className="text-sm text-ink-caption">
                {[item.next_due_on, item.next_due_mileage != null ? `${item.next_due_mileage.toLocaleString(undefined, { maximumFractionDigits: 0 })} km` : null].filter(Boolean).join(" or ")}
              </p>
            </div>
            {canManage && <Button variant="secondary" onClick={() => setSelection({ existing: item })}>Edit</Button>}
          </li>
        ))}
      </ul>
      {picking && <ServiceDialog title="Add suggested item" description="Choose a service, then set the due targets for this vehicle." onClose={() => setPicking(false)} footer={<Button variant="secondary" onClick={() => setPicking(false)}>Cancel</Button>}>
        <Input autoFocus label="Search services" type="search" value={search} onChange={event => setSearch(event.target.value)} />
        {catalog.isLoading && <p>Loading services…</p>}
        {catalog.error && <p role="alert">Could not load services. <button onClick={() => catalog.refetch()}>Retry</button></p>}
        <ul className="mt-4 divide-y divide-line overflow-hidden rounded-md border border-line">
          {catalog.data?.items.filter(item => item.name.toLowerCase().includes(search.trim().toLowerCase())).map(suggestion => (
            <li key={suggestion.catalog_key}>
              <button className="flex w-full items-center justify-between gap-4 px-4 py-3 text-left hover:bg-skeleton focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-focus"
                onClick={() => {
                  const existing = items.find(item => item.enabled && item.catalog_key === suggestion.catalog_key);
                  setPicking(false);
                  setSelection({ suggestion, existing });
                }}>
                  <span className="flex items-center gap-2 font-medium">
                    {suggestion.name}
                    {items.some(item => item.enabled && item.catalog_key === suggestion.catalog_key) && (
                      <svg role="img" aria-label="Already set up" viewBox="0 0 24 24" className="h-5 w-5 shrink-0 text-success" fill="currentColor">
                        <path fillRule="evenodd" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm4.7 6.3a1 1 0 0 1 0 1.4l-5 5a1 1 0 0 1-1.4 0l-3-3a1 1 0 1 1 1.4-1.4l2.3 2.3 4.3-4.3a1 1 0 0 1 1.4 0Z" clipRule="evenodd" />
                      </svg>
                    )}
                  </span>
                  <span className="shrink-0 text-xs text-ink-caption">{items.some(item => item.enabled && item.catalog_key === suggestion.catalog_key) ? "Edit reminder" : "Set reminder"}</span>
                </button>
            </li>
          ))}
        </ul>
        {catalog.data && !catalog.data.items.some(item => item.name.toLowerCase().includes(search.trim().toLowerCase())) && <p className="mt-4 text-sm text-ink-caption">No services match your search. Try another name or create a custom service item.</p>}
      </ServiceDialog>}
      {selection && <ReminderForm key={selection.existing?.id ?? selection.suggestion?.catalog_key ?? "custom"}
        orgId={orgId} vehicleId={vehicleId} selection={selection} onClose={() => setSelection(null)} />}
    </Card>
  );
}

function ReminderForm({ orgId, vehicleId, selection, onClose }: {
  orgId: string | null;
  vehicleId: string;
  selection: Selection;
  onClose: () => void;
}) {
  const formId = useId();
  const item = selection.existing;
  const [id] = useState(() => item?.id ?? crypto.randomUUID());
  const [name, setName] = useState(item?.name ?? selection.suggestion?.name ?? "");
  const [date, setDate] = useState(item?.next_due_on ?? "");
  const [mileage, setMileage] = useState(item?.next_due_mileage?.toFixed(0) ?? "");
  const [days, setDays] = useState(item?.time_count?.toString() ?? item?.interval_days?.toString() ?? "");
  const [timeUnit, setTimeUnit] = useState<"days" | "months" | "years">(item?.time_unit ?? (item?.interval_days ? "days" : "months"));
  const [recurring, setRecurring] = useState(item ? Boolean(item.time_count || item.interval_days || item.interval_distance) : true);
  const [notes, setNotes] = useState(item?.notes ?? "");
  const [distance, setDistance] = useState(item?.interval_distance?.toFixed(0) ?? "");
  const [enabled, setEnabled] = useState(item?.enabled ?? true);
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const save = useSaveReminder(orgId, vehicleId);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    const errors: Record<string, string> = {};
    if (!date && !mileage) {
      errors.date = errors.mileage = "Enter a due date or odometer reading.";
    }
    if (recurring && date && (!days.trim() || Number(days) < 1)) {
      errors.days = "Enter a repeat time of at least 1 month.";
    }
    if (recurring && mileage && (!distance.trim() || Number(distance) <= 0)) {
      errors.distance = "Enter a repeat distance greater than zero.";
    }
    setFieldErrors(errors);
    if (Object.keys(errors).length) return;
    setError(null);
    try {
      await save.mutateAsync({ editing: Boolean(item), body: {
        id, name: name.trim(), catalog_key: item?.catalog_key ?? selection.suggestion?.catalog_key ?? null,
        next_due_on: date || null, next_due_mileage: mileage ? Number(mileage) : null,
        time_count: recurring && date && days ? Number(days) : null, time_unit: recurring && date && days ? timeUnit : null,
        warning_days: date ? item?.warning_days ?? 30 : null,
        warning_distance: mileage ? item?.warning_distance ?? 500 : null,
        interval_days: null, interval_distance: recurring && mileage && distance ? Number(distance) : null, enabled, notes: notes.trim() || null,
      }});
      onClose();
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : "Could not save reminder. Please retry.");
    }
  }

  return <ServiceDialog title={item ? "Edit reminder" : "Create reminder"} description="Set a due date, an odometer target, or both. Repeat intervals are optional."
    onClose={onClose} busy={save.isPending} footer={<>
      <Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button>
      <Button type="submit" form={formId} disabled={save.isPending}>{save.isPending ? "Saving…" : "Save reminder"}</Button>
    </>}>
    <form id={formId} onSubmit={submit} className="flex flex-col gap-4">
      <Input label="Service name" required maxLength={80} value={name} onChange={event => setName(event.target.value)} />
      <div className="grid gap-4 sm:grid-cols-2">
        <Input label="Next due date" type="date" error={fieldErrors.date} value={date} onChange={event => { setDate(event.target.value); setFieldErrors({}); }} />
        <Input label="Next due odometer (km)" type="number" min={0} step={1} error={fieldErrors.mileage} value={mileage} onChange={event => { setMileage(event.target.value); setFieldErrors({}); }} />
      </div>
      <label className="flex items-center gap-2"><input type="checkbox" checked={recurring} onChange={event => setRecurring(event.target.checked)} />Recurring</label>
      {recurring && (date || mileage) && <div className="grid gap-4 sm:grid-cols-2">
        {date && <div className="grid grid-cols-2 items-end gap-3">
          <Input label="Repeat every" type="number" min={1} step={1} error={fieldErrors.days} value={days} onChange={event => { setDays(event.target.value); setFieldErrors(previous => ({ ...previous, days: "" })); }} />
          <label className="flex flex-col gap-1.5 text-xs font-medium text-ink-caption">Time unit
            <select className="h-11 rounded-md border border-line-strong bg-field px-3 text-sm text-ink focus-visible:outline-2 focus-visible:outline-focus" value={timeUnit} onChange={event => setTimeUnit(event.target.value as typeof timeUnit)}>
              {timeUnit === "days" && <option value="days" disabled>Days (existing)</option>}
              <option value="months">Months</option><option value="years">Years</option>
            </select>
          </label>
        </div>}
        {mileage && <Input label="Repeat distance (km)" type="number" min={1} step={1} error={fieldErrors.distance} value={distance} onChange={event => { setDistance(event.target.value); setFieldErrors(previous => ({ ...previous, distance: "" })); }} />}
      </div>}
      <label className="flex flex-col gap-1.5 text-xs font-medium text-ink-caption">Note
        <textarea className="min-h-24 rounded-md border border-line-strong bg-field p-3 text-sm text-ink focus-visible:outline-2 focus-visible:outline-focus" rows={3} maxLength={4000} value={notes} onChange={event => setNotes(event.target.value)} />
      </label>
      <label className="flex items-center gap-2"><input type="checkbox" checked={enabled} onChange={event => setEnabled(event.target.checked)} />Active</label>
      {error && <p role="alert" className="text-danger">{error}</p>}
    </form>
  </ServiceDialog>;
}
