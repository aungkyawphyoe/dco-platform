"use client";

import { Input } from "@dco/ui/components/input";
import { useFleetCurrency, type Currency } from "@/lib/api/currency";
import { useState } from "react";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Badge } from "@dco/ui/components/badge";
import { Button } from "@dco/ui/components/button";
import { Modal } from "@dco/ui/components/modal";
import { Select } from "@dco/ui/components/select";
import { EmptyState } from "@dco/ui/components/empty-state";
import { Skeleton } from "@dco/ui/components/skeleton";
import { useMembers, useUpdateWorkOrder, useVehicles, useWorkOrders } from "@/lib/api/hooks";
import type { WorkOrder } from "@/lib/api/types";
import { useOrgId, useOrgRole, useSession } from "@/lib/auth/session-context";
import { formatDateTime } from "@dco/ui/lib/format";

function urgencyTone(urgency: string): "danger" | "warning" | "neutral" {
  if (urgency === "critical" || urgency === "high") return "danger";
  if (urgency === "medium") return "warning";
  return "neutral";
}

function WorkOrderCard({
  order,
  vehicleName,
  action,
}: {
  order: WorkOrder;
  vehicleName: string;
  action?: React.ReactNode;
}) {
  return (
    <article className="rounded-lg border border-line-subtle bg-card p-4">
      <div className="flex items-start justify-between gap-3">
        <p className="font-medium text-ink">{vehicleName}</p>
        <Badge tone={urgencyTone(order.urgency)}>{order.urgency}</Badge>
      </div>
      <p className="mt-2 text-sm capitalize text-ink">{order.issue_type.replaceAll("_", " ")}</p>
      <p className="mt-1 line-clamp-2 text-xs text-ink-caption">{order.description}</p>
      <p className="mt-3 font-mono text-xs text-ink-caption">
        {order.odometer_km.toLocaleString()} km
      </p>
      <p className="text-xs text-ink-faint">
        {order.reported_at ? formatDateTime(order.reported_at) : "Reported"}
      </p>
      {order.completion_cost !== null && order.completion_cost !== undefined && <p className="mt-2 text-sm">Completion cost: {order.completion_cost.toLocaleString(undefined, { maximumFractionDigits: 20 })} {order.currency}</p>}
      {action ? <div className="mt-3">{action}</div> : null}
    </article>
  );
}

function PipelineColumn({
  title,
  accent,
  orders,
  emptyText,
  renderCard,
}: {
  title: string;
  accent: string;
  orders: WorkOrder[];
  emptyText: string;
  renderCard: (order: WorkOrder) => React.ReactNode;
}) {
  return (
    <section className="flex min-w-0 flex-col gap-3">
      <div
        className={`flex items-center justify-between rounded-md border-t-2 bg-panel px-4 py-2.5 ${accent}`}
      >
        <h2 className="font-display text-sm font-semibold text-ink">{title}</h2>
        <Badge tone="neutral">{orders.length}</Badge>
      </div>
      {orders.length === 0 ? (
        <p className="rounded-lg border border-dashed border-line-subtle px-4 py-6 text-center text-xs text-ink-faint">
          {emptyText}
        </p>
      ) : (
        orders.map((order) => <div key={order.id}>{renderCard(order)}</div>)
      )}
    </section>
  );
}

export default function WorkOrdersPage() {
  const orgId = useOrgId();
  const role = useOrgRole();
  const { user } = useSession();
  const canManage = role === "org_admin" || role === "org_manager";

  const { data, isLoading } = useWorkOrders(orgId);
  const { data: members } = useMembers(orgId);
  const { data: vehiclesData } = useVehicles(orgId);
  const updateOrder = useUpdateWorkOrder(orgId);
  const currencyQuery = useFleetCurrency(orgId);
  const currentCurrency = currencyQuery.data ? (currencyQuery.data.enabled ? currencyQuery.data.currency : "MMK") : null;
  const [draftCurrency, setDraftCurrency] = useState<Currency | null>(null);
  const [cost, setCost] = useState("");
  const [error, setError] = useState<string | null>(null);

  const [advance, setAdvance] = useState<{ id: string; next: string; assign?: boolean } | null>(
    null,
  );
  const [assignee, setAssignee] = useState("");
  const [notes, setNotes] = useState("");

  const orders = data?.items ?? [];
  const vehicles = vehiclesData?.items ?? [];
  const mechanics =
    members?.items.filter((m) => ["org_manager", "org_mechanic"].includes(m.role)) ?? [];

  function nextStatus(status: string): string | null {
    if (status === "reported") return "in_progress";
    if (status === "in_progress") return "completed";
    return null;
  }

  const byStage = (stage: string) => orders.filter((o) => o.status === stage);
  const reported = byStage("reported");
  const inProgress = byStage("in_progress");
  const completed = byStage("completed");
  const openCount = reported.length + inProgress.length;
  const criticalOpen = orders.filter(
    (o) =>
      o.status !== "completed" && (o.urgency === "critical" || o.urgency === "high"),
  ).length;

  const vehicleName = (id: string) => vehicles.find((v) => v.id === id)?.name ?? id.slice(0, 8);

  async function onAdvance() {
    if (!advance) return;
    setError(null);
    if (advance.next === "completed") {
      if (!draftCurrency || currencyQuery.isError || draftCurrency !== currentCurrency) {
        setError("Fleet currency is unavailable or has changed. Confirm the current currency and re-enter the cost.");
        return;
      }
      const pattern = draftCurrency === "MMK" ? /^\d+$/ : /^\d+(?:\.\d{1,2})?$/;
      if (!pattern.test(cost) || !Number.isFinite(Number(cost))) {
        setError(draftCurrency === "MMK" ? "Enter a non-negative whole MMK amount." : "Enter a non-negative amount with at most two decimal places.");
        return;
      }
    }
    try {
      await updateOrder.mutateAsync({
        id: advance.id,
        status: advance.next,
        ...(advance.assign && assignee ? { assigned_to: assignee } : {}),
        ...(advance.next === "completed" ? { completion_cost: Number(cost), currency: draftCurrency!, resolution_notes: notes || null } : {}),
      });
      setAdvance(null);
      setAssignee("");
      setNotes("");
      setCost("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to update work order.");
      await currencyQuery.refetch();
    }
  }

  function actionFor(order: WorkOrder) {
    const next = nextStatus(order.status);
    if (!canManage || !next) return undefined;
    return (
      <Button
        size="sm"
        variant={next === "in_progress" ? "primary" : "secondary"}
        className="w-full"
        onClick={() => {
          setCost(""); setNotes(""); setAssignee(""); setError(null); setDraftCurrency(currentCurrency);
          setAdvance({ id: order.id, next, assign: next === "in_progress" });
        }}
      >
        {next === "in_progress" ? "Start work" : "Mark completed"}
      </Button>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Work Orders"
        meta={
          orders.length === 0
            ? undefined
            : `${openCount} open, ${criticalOpen} critical or high`
        }
      />

      {isLoading ? (
        <div className="grid grid-cols-1 gap-5 lg:grid-cols-3">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-40 w-full" />
          ))}
        </div>
      ) : orders.length === 0 ? (
        <Card>
          <EmptyState
            title="No work orders"
            description="Drivers report issues from their assignment; orders appear here."
          />
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-5 lg:grid-cols-3">
          <PipelineColumn
            title="Reported"
            accent="border-t-warning"
            orders={reported}
            emptyText="Nothing waiting to be triaged."
            renderCard={(order) => (
              <WorkOrderCard
                order={order}
                vehicleName={vehicleName(order.vehicle_id)}
                action={actionFor(order)}
              />
            )}
          />
          <PipelineColumn
            title="In progress"
            accent="border-t-info"
            orders={inProgress}
            emptyText="No active repairs."
            renderCard={(order) => (
              <WorkOrderCard
                order={order}
                vehicleName={vehicleName(order.vehicle_id)}
                action={actionFor(order)}
              />
            )}
          />
          <PipelineColumn
            title="Completed"
            accent="border-t-success"
            orders={completed}
            emptyText="Completed orders will list here."
            renderCard={(order) => (
              <WorkOrderCard order={order} vehicleName={vehicleName(order.vehicle_id)} />
            )}
          />
        </div>
      )}

      <Modal
        open={Boolean(advance)}
        onClose={() => setAdvance(null)}
        title={advance?.next === "completed" ? "Complete work order" : "Start work order"}
        confirmLabel={advance?.next === "completed" ? "Complete" : "Start"}
        loading={updateOrder.isPending}
        onSubmit={() => void onAdvance()}
      >
        <div className="flex flex-col gap-3">
          {advance?.assign ? (
            <Select
              label="Assign to"
              options={[
                { value: "", label: "Unassigned" },
                ...mechanics.map((m) => ({
                  value: m.user_id,
                  label: m.display_name || m.email,
                })),
              ]}
              value={assignee}
              onChange={setAssignee}
            />
          ) : null}
          {advance?.next === "completed" ? (
            <>
            <Input label={`Completion cost (${draftCurrency ?? "currency not selected"})`} inputMode="decimal" value={cost} onChange={e => setCost(e.target.value)} />
            <p className="text-xs">Enter the equivalent cost in {draftCurrency ?? "the fleet currency"}. No automatic conversion is applied. You may record the original amount in notes.</p>
            {currentCurrency && currentCurrency !== draftCurrency && <Button variant="secondary" onClick={() => { setDraftCurrency(currentCurrency); setCost(""); setError(null); }}>Use {currentCurrency} and re-enter cost</Button>}
            <textarea
              className="min-h-20 rounded-md border border-line-strong bg-field p-3 text-sm text-ink"
              placeholder="Resolution notes (optional)"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
            </>
          ) : null}
          {error && <p role="alert" className="text-danger">{error}</p>}
          <p className="text-xs text-ink-caption">
            Signed in as {user?.email} ({role ?? "—"})
          </p>
        </div>
      </Modal>
    </div>
  );
}
