"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import { Button } from "@dco/ui/components/button";
import { Card } from "@dco/ui/components/card";
import { Input } from "@dco/ui/components/input";
import { useSaveReminder, useServiceCatalog, type SuggestedService } from "@/lib/api/hooks";
import type { VehiclePlanItem } from "@/lib/api/types";

function BottomSheet({ title, onClose, children }: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => { dialog.current?.showModal(); }, []);
  return (
    <dialog ref={dialog} onCancel={onClose} aria-label={title}
      className="fixed inset-x-0 bottom-0 top-auto m-0 max-h-[90dvh] w-full max-w-none overflow-y-auto rounded-t-xl bg-card p-6 text-ink shadow-xl backdrop:bg-black/50">
      <div className="mx-auto max-w-2xl">
        <div className="mb-5 flex items-center justify-between gap-4">
          <h2 className="font-display text-xl font-semibold">{title}</h2>
          <Button variant="secondary" onClick={onClose}>Close</Button>
        </div>
        {children}
      </div>
    </dialog>
  );
}

type Selection = { suggestion?: SuggestedService; existing?: VehiclePlanItem };

export function ReminderSetup({ orgId, vehicleId, items, canManage }: {
  orgId: string | null;
  vehicleId: string;
  items: VehiclePlanItem[];
  canManage: boolean;
}) {
  const catalog = useServiceCatalog(orgId);
  const [picking, setPicking] = useState(false);
  const [selection, setSelection] = useState<Selection | null>(null);
  return (
    <Card className="p-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 className="font-display text-lg font-semibold">Maintenance reminders</h2>
        {canManage && <div className="flex flex-wrap gap-2">
          <Button variant="secondary" onClick={() => setSelection({})}>Create custom service item</Button>
          <Button onClick={() => setPicking(true)}>Add suggested item</Button>
        </div>}
      </div>
      {items.length === 0 && <p className="mt-4 text-sm text-ink-caption">Add the services this vehicle needs and set their next due targets.</p>}
      <ul className="mt-4 divide-y divide-line-subtle">
        {items.map(item => (
          <li key={item.id} className="flex items-center justify-between gap-4 py-3">
            <div>
              <p className="font-medium">{item.name}{!item.enabled && " (disabled)"}</p>
              <p className="text-sm text-ink-caption">
                {[item.next_due_on, item.next_due_mileage != null ? `${item.next_due_mileage.toLocaleString()} km` : null].filter(Boolean).join(" or ")}
              </p>
            </div>
            {canManage && <Button variant="secondary" onClick={() => setSelection({ existing: item })}>Edit</Button>}
          </li>
        ))}
      </ul>
      {picking && <BottomSheet title="Add suggested item" onClose={() => setPicking(false)}>
        {catalog.isLoading && <p>Loading services…</p>}
        {catalog.error && <p role="alert">Could not load services. <button onClick={() => catalog.refetch()}>Retry</button></p>}
        <ul className="divide-y divide-line-subtle">
          {catalog.data?.items.map(suggestion => (
            <li key={suggestion.catalog_key}>
              <button className="w-full rounded-md p-3 text-left hover:bg-skeleton focus-visible:outline focus-visible:outline-2"
                onClick={() => {
                  const existing = items.find(item => item.enabled && item.catalog_key === suggestion.catalog_key);
                  setPicking(false);
                  setSelection({ suggestion, existing });
                }}>{suggestion.name}</button>
            </li>
          ))}
        </ul>
      </BottomSheet>}
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
  const item = selection.existing;
  const [id] = useState(() => item?.id ?? crypto.randomUUID());
  const [name, setName] = useState(item?.name ?? selection.suggestion?.name ?? "");
  const [date, setDate] = useState(item?.next_due_on ?? "");
  const [mileage, setMileage] = useState(item?.next_due_mileage?.toString() ?? "");
  const [days, setDays] = useState(item?.time_count?.toString() ?? item?.interval_days?.toString() ?? "");
  const [timeUnit, setTimeUnit] = useState<"days" | "months" | "years">(item?.time_unit ?? "days");
  const [warningDays, setWarningDays] = useState(String(item?.warning_days ?? 30));
  const [warningDistance, setWarningDistance] = useState(String(item?.warning_distance ?? 500));
  const [distance, setDistance] = useState(item?.interval_distance?.toString() ?? "");
  const [enabled, setEnabled] = useState(item?.enabled ?? true);
  const [error, setError] = useState<string | null>(null);
  const save = useSaveReminder(orgId, vehicleId);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if ((!date && !mileage) || (days && !date) || (distance && !mileage)) {
      setError("Set a due target for each repeat interval, and at least one due target.");
      return;
    }
    setError(null);
    try {
      await save.mutateAsync({ editing: Boolean(item), body: {
        id, name: name.trim(), catalog_key: item?.catalog_key ?? selection.suggestion?.catalog_key ?? null,
        next_due_on: date || null, next_due_mileage: mileage ? Number(mileage) : null,
        time_count: days ? Number(days) : null, time_unit: days ? timeUnit : null,
        warning_days: date ? Number(warningDays) : null,
        warning_distance: mileage ? Number(warningDistance) : null,
        interval_days: null, interval_distance: distance ? Number(distance) : null, enabled,
      }});
      onClose();
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : "Could not save reminder. Please retry.");
    }
  }

  return <BottomSheet title={item ? "Edit reminder" : "Create reminder"} onClose={onClose}>
    <form onSubmit={submit} className="flex flex-col gap-4">
      <Input label="Service name" required maxLength={80} value={name} onChange={event => setName(event.target.value)} />
      <div className="grid gap-4 sm:grid-cols-2">
        <Input label="Next due date" type="date" value={date} onChange={event => setDate(event.target.value)} />
        <Input label="Next due odometer (km)" type="number" min={0} step="0.1" value={mileage} onChange={event => setMileage(event.target.value)} />
        <Input label="Repeat every" type="number" min={1} step={1} value={days} onChange={event => setDays(event.target.value)} />
        <label className="flex flex-col gap-2 text-sm">Time unit
          <select className="rounded-md bg-panel p-3" value={timeUnit} onChange={event => setTimeUnit(event.target.value as typeof timeUnit)}>
            <option value="days">Days</option><option value="months">Months</option><option value="years">Years</option>
          </select>
        </label>
        <Input label="Repeat every (km)" type="number" min={0.1} step="0.1" value={distance} onChange={event => setDistance(event.target.value)} />
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        {date && <Input label="Remind days before due" type="number" required min={0} step={1} value={warningDays} onChange={event => setWarningDays(event.target.value)} />}
        {mileage && <Input label="Remind km before due" type="number" required min={0} step="0.1" value={warningDistance} onChange={event => setWarningDistance(event.target.value)} />}
      </div>
      <p className="text-sm text-ink-caption">Leave repeat fields empty for a one-time reminder. Either due target can make the reminder due.</p>
      <label className="flex items-center gap-2"><input type="checkbox" checked={enabled} onChange={event => setEnabled(event.target.checked)} />Enabled</label>
      {error && <p role="alert" className="text-danger">{error}</p>}
      <Button type="submit" disabled={save.isPending}>{save.isPending ? "Saving…" : "Save reminder"}</Button>
    </form>
  </BottomSheet>;
}
