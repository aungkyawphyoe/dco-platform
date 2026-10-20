"use client";

import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useMembers, useVehicles } from "@/lib/api/hooks";
import { apiGet, apiPost } from "@/lib/api/client";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Button } from "@dco/ui/components/button";
import { Badge } from "@dco/ui/components/badge";
import { EmptyState } from "@dco/ui/components/empty-state";
import { Skeleton } from "@dco/ui/components/skeleton";
import { SectionHeading } from "@dco/ui/components/section-heading";
import { DataPlate } from "@dco/ui/components/data-plate";
import { formatDateTime } from "@dco/ui/lib/format";

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
    <div key={key}><dt className="text-xs text-ink-caption">{labels[key]}</dt><dd className="mt-0.5">{Array.isArray(value)
      ? value.map((item, index) => <div key={index}>{item && typeof item === "object" ? <Fields record={item as Record<string, unknown>} /> : String(item)}</div>)
      : value == null ? "—" : String(value)}</dd></div>)}</dl>;
}

function titleize(value: string) {
  const words = value.replaceAll("_", " ");
  return words.charAt(0).toUpperCase() + words.slice(1);
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

  if (role !== "org_admin") {
    return (
      <EmptyState
        title="Fleet Admin access required"
        description="Only the Fleet Admin can decide pending submissions."
      />
    );
  }

  const items = reviews.data?.items ?? [];
  const pending = items.filter((r) => r.status === "pending").length;

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Submission review"
        meta={
          items.length
            ? `${pending} waiting for a decision`
            : "Offline logs and conflicting corrections arrive here"
        }
      />

      {error || reviews.error ? (
        <Card className="p-4 text-sm text-danger">
          {error ?? reviews.error?.message}
        </Card>
      ) : null}

      {reviews.isLoading ? (
        <>
          <Skeleton className="h-40 w-full" />
          <Skeleton className="h-40 w-full" />
        </>
      ) : items.length === 0 ? (
        <Card>
          <EmptyState
            title="Nothing to review"
            description="Logs recorded offline, or corrections that conflict with newer records, appear here for a decision."
          />
        </Card>
      ) : (
        items.map((review) => {
          const vehicleName =
            vehicles?.items.find((v) => v.id === review.vehicle_id)?.name ?? "Former fleet vehicle";
          const submitter =
            members?.items.find((m) => m.user_id === review.submitted_by)?.display_name ??
            "Former fleet member";
          return (
            <Card key={review.id}>
              <SectionHeading title={titleize(review.operation.entity_type)}>
                <div className="flex items-center gap-2">
                  <span className="text-xs text-ink-caption">
                    {titleize(review.operation.op)}
                  </span>
                  <Badge tone={review.status === "pending" ? "warning" : "neutral"}>
                    {review.status}
                  </Badge>
                </div>
              </SectionHeading>

              <div className="flex flex-col gap-5 p-5">
                <DataPlate
                  className=""
                  fields={[
                    { label: "Vehicle", value: vehicleName },
                    { label: "Submitted by", value: submitter },
                    {
                      label: "Received",
                      value: formatDateTime(review.created_at),
                      mono: true,
                    },
                  ]}
                />

                <p className="max-w-2xl text-sm text-ink-muted">
                  {titleize(review.reason)}.
                </p>

                <div>
                  <p className="text-xs font-medium text-ink">Proposed change</p>
                  <div className="mt-2 rounded-lg border border-line-subtle bg-panel p-4">
                    <Fields record={review.operation.payload} />
                  </div>
                </div>

                {comparison?.id === review.id ? (
                  <div>
                    <p className="text-xs font-medium text-ink">Current record</p>
                    <div className="mt-2 rounded-lg border border-line-subtle bg-panel p-4">
                      {comparison.record ? (
                        <Fields record={comparison.record} />
                      ) : (
                        <p className="text-sm text-ink-caption">This is a new record.</p>
                      )}
                    </div>
                  </div>
                ) : null}

                {review.status === "pending" ? (
                  <div className="flex flex-wrap gap-3">
                    {comparison?.id === review.id ? (
                      <Button disabled={busy !== null} onClick={() => void decide(review, "accept")}>
                        Accept {review.operation.op === "delete" ? "deletion" : "submission"}
                      </Button>
                    ) : (
                      <Button
                        variant="secondary"
                        disabled={busy !== null}
                        onClick={() => void inspect(review)}
                      >
                        Compare with current record
                      </Button>
                    )}
                    <Button
                      variant="destructive"
                      disabled={busy !== null}
                      onClick={() => void decide(review, "reject")}
                    >
                      Reject
                    </Button>
                  </div>
                ) : null}
              </div>
            </Card>
          );
        })
      )}
    </div>
  );
}
