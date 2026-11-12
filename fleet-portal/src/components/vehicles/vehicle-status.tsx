"use client";

import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { Button } from "@dco/ui/components/button";
import { Select } from "@dco/ui/components/select";
import { useUpdateVehicleStatus } from "@/lib/api/hooks";
import { lifecycleTransitions, type FleetVehicle } from "@/lib/api/types";

const descriptions: Record<string, string> = {
  inventory: "In showroom stock and not yet marked as listed for sale.",
  listed: "Offered for sale. Marking a vehicle as listed does not publish an advertisement.",
  reserved: "Held for a prospective buyer. Ownership stays with the showroom until handover is complete.",
  sold: "Handover is complete and ownership has moved to the buyer. The showroom retains its historical records. Contact platform support to correct a mistaken handover.",
  available: "Available for the next assignment or rental. Check the vehicle’s condition and maintenance before use.",
  leased: "Leased out and not available for another lease.",
  maintenance: "Undergoing maintenance. Review outstanding repairs before returning the vehicle to service.",
  rented: "Rented to a customer and not yet marked as returned.",
  return: "Returned and awaiting the inspection stage.",
  inspection: "In the inspection stage before being marked available again.",
  in_service: "Active in normal operations.",
  retired: "Removed from active operations. This is a final status with no further lifecycle transitions.",
};
const label = (status: string) => status.replaceAll("_", " ").replace(/^./, (s) => s.toUpperCase());

export function VehicleStatus({ vehicle, orgId, canManage }: {
  vehicle: FleetVehicle; orgId: string | null; canManage: boolean;
}) {
  const [selected, setSelected] = useState("");
  const [reviewedStatus, setReviewedStatus] = useState(vehicle.status);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const mutation = useUpdateVehicleStatus(orgId);
  const queries = useQueryClient();
  const states = lifecycleTransitions[vehicle.lifecycle_template] ?? {};
  const next = (states[vehicle.status] ?? []).filter((status) => status !== "sold");

  async function save() {
    if (!selected || mutation.isPending || reviewedStatus !== vehicle.status) return;
    setError(null);
    setSaved(false);
    try {
      await mutation.mutateAsync({ vehicleId: vehicle.id, status: selected, expectedStatus: reviewedStatus });
      setSelected("");
      setSaved(true);
    } catch (cause) {
      setSelected("");
      setError(cause instanceof Error ? cause.message : "Could not save status. Refresh and choose a status again.");
      await queries.invalidateQueries({ queryKey: ["fleet", "vehicles", orgId] });
    }
  }

  return (
    <section aria-labelledby="vehicle-status-title" className="rounded-lg border border-line-subtle bg-panel p-5">
      <h2 id="vehicle-status-title" className="font-display text-base font-semibold text-ink">Vehicle status</h2>
      <p className="mt-3 text-sm font-medium text-ink">{label(vehicle.status)}</p>
      <p className="mt-1 max-w-2xl text-sm text-ink-caption">{descriptions[vehicle.status] ?? "Review this vehicle’s lifecycle before making changes."}</p>
      {canManage && next.length > 0 && (
        <div className="mt-4 max-w-xl">
          <div className="flex flex-wrap items-end gap-3">
            <Select label="Change status" placeholder="Choose next status" value={selected}
              options={next.map((status) => ({ value: status, label: label(status) }))}
              onChange={(value) => { setSelected(value); setReviewedStatus(vehicle.status); setError(null); setSaved(false); }}
              disabled={mutation.isPending} className="w-full sm:w-64" />
            <Button onClick={() => void save()} disabled={!selected || mutation.isPending || reviewedStatus !== vehicle.status}>
              {mutation.isPending ? "Saving…" : "Save status"}
            </Button>
          </div>
          {selected && <p className="mt-2 text-sm text-ink-caption">{descriptions[selected]}</p>}
        </div>
      )}
      {vehicle.lifecycle_template === "showroom" && vehicle.status === "reserved" && (
        <p className="mt-3 text-sm text-ink-caption">Sold is set only when the buyer handover below is completed. Preparing or cancelling a draft does not change ownership.</p>
      )}
      {selected && reviewedStatus !== vehicle.status && <p role="alert" className="mt-3 text-sm text-ink-caption">Vehicle status changed. Choose the next status again before saving.</p>}
      {error && <p role="alert" className="mt-3 text-sm text-red-500">{error}</p>}
      {saved && <p role="status" className="mt-3 text-sm text-ink-caption">Status saved.</p>}
      <details className="mt-4 border-t border-line-subtle pt-3">
        <summary className="cursor-pointer text-sm font-medium text-ink">What each status means</summary>
        <dl className="mt-3 grid gap-3 sm:grid-cols-[8rem_1fr]">
          {Object.keys(states).map((status) => (
            <div key={status} className="contents">
              <dt className="text-sm font-medium text-ink">{label(status)}</dt>
              <dd className="max-w-2xl text-sm text-ink-caption">{descriptions[status]}</dd>
            </div>
          ))}
        </dl>
      </details>
    </section>
  );
}
