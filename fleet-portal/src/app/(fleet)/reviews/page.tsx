"use client";

import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useMembers, useVehicles } from "@/lib/api/hooks";
import { apiGet, apiPost } from "@/lib/api/client";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";
import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { EmptyState } from "@/components/ui/empty-state";

interface Review {
  id: string;
  vehicle_id: string;
  submitted_by: string;
  reason: string;
  status: string;
  created_at: string;
  operation: { entity_type: string; entity_id: string; op: string; payload: Record<string, unknown> };
}
const resources: Record<string, string> = { expense: "expenses", service_record: "service-records", fuel_log: "fuel-logs", document: "documents", part: "parts" };

const labels: Record<string, string> = {
  name: "Name", category: "Category", amount: "Amount", cost: "Cost", total_cost: "Total cost",
  incurred_on: "Date", serviced_on: "Service date", logged_on: "Fuel date", odometer: "Odometer",
  workshop_name: "Workshop", notes: "Notes", fuel_type_name: "Fuel type", unit: "Unit",
  items: "Services", parts: "Parts", line_cost: "Cost", brand: "Brand", part_number: "Part number", expires_on: "Expires",
};
function Fields({ record }: { record: Record<string, unknown> }) {
  return <dl className="grid grid-cols-2 gap-3 text-sm">{Object.entries(record).filter(([key]) => labels[key]).map(([key, value]) =>
    <div key={key}><dt className="text-ink-caption">{labels[key]}</dt><dd>{Array.isArray(value)
      ? value.map((item, index) => <div key={index}>{item && typeof item === "object" ? <Fields record={item as Record<string, unknown>} /> : String(item)}</div>)
      : value == null ? "—" : String(value)}</dd></div>)}</dl>;
}

export default function ReviewsPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const client = useQueryClient();
  const { data: vehicles } = useVehicles(orgId);
  const { data: members } = useMembers(orgId);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [comparison, setComparison] = useState<{ id: string; record: Record<string, unknown> | null } | null>(null);
  const reviews = useQuery({ queryKey: ["reviews", orgId], enabled: !!orgId && role === "org_admin",
    queryFn: () => apiGet<{ items: Review[] }>(`/organizations/${orgId}/reviews`) });

  async function inspect(review: Review) {
    setBusy(review.id); setError(null);
    try {
      const records = await apiGet<{ items: Record<string, unknown>[] }>(`/organizations/${orgId}/records/vehicles/${review.vehicle_id}/${resources[review.operation.entity_type]}`);
      setComparison({ id: review.id, record: records.items.find(row => row.id === review.operation.entity_id) ?? null });
    } catch (err) { setError(err instanceof Error ? err.message : "Unable to load current record"); }
    finally { setBusy(null); }
  }

  async function decide(review: Review, decision: "accept" | "reject") {
    setBusy(review.id); setError(null);
    try {
      await apiPost(`/organizations/${orgId}/reviews/${review.id}/decision`, { decision,
        ...(decision === "accept" ? { expected_revision: comparison?.record?.revision ?? null } : {}) });
      setComparison(null);
      await client.invalidateQueries({ queryKey: ["reviews", orgId] });
    } catch (err) { setError(err instanceof Error ? err.message : "Unable to save decision"); }
    finally { setBusy(null); }
  }

  if (role !== "org_admin") return <EmptyState title="Fleet Admin access required" description="Only the Fleet Admin can decide pending submissions." />;
  return <div className="flex flex-col gap-6">
    <PageHeader title="Submission review" description="Review offline logs received after access changed, or corrections that conflict with newer records." />
    {error || reviews.error ? <p role="alert" className="text-danger">{error ?? reviews.error?.message}</p> : null}
    {reviews.isLoading ? <p>Loading submissions…</p> : null}
    {reviews.data?.items.length === 0 ? <EmptyState title="No submissions to review" description="Submissions needing a decision will appear here." /> : null}
    {reviews.data?.items.map(review => <Card key={review.id}>
      <div className="flex flex-col gap-4 p-5">
        <div className="flex items-center justify-between"><h2 className="font-display text-lg">{review.operation.entity_type.replaceAll("_", " ")}</h2><Badge tone={review.status === "pending" ? "warning" : "neutral"}>{review.status}</Badge></div>
        <p className="text-sm text-ink-caption">{review.reason.replaceAll("_", " ")} · {new Date(review.created_at).toLocaleString()}</p>
        <p className="text-sm">Vehicle: {vehicles?.items.find(v => v.id === review.vehicle_id)?.name ?? "Former fleet vehicle"} · Submitted by: {members?.items.find(m => m.user_id === review.submitted_by)?.display_name ?? "Former fleet member"}</p>
        <Fields record={review.operation.payload} />
        {comparison?.id === review.id ? <div className="rounded border border-line-subtle p-3"><h3 className="font-semibold">Current record</h3>{comparison.record ? <Fields record={comparison.record} /> : <p>This is a new record.</p>}</div> : null}
        {review.status === "pending" ? <div className="flex gap-3">
          {comparison?.id === review.id ? <Button disabled={busy !== null} onClick={() => void decide(review, "accept")}>Accept {review.operation.op === "delete" ? "deletion" : "submission"}</Button> : <Button disabled={busy !== null} onClick={() => void inspect(review)}>Compare before accepting</Button>}
          <Button variant="destructive" disabled={busy !== null} onClick={() => void decide(review, "reject")}>Reject</Button>
        </div> : null}
      </div>
    </Card>)}
  </div>;
}
