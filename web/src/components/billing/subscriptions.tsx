"use client";
import { useEffect, useRef, useState } from "react";
import { HistoryNavigation } from "./history-navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiGet, apiPost, apiPatch } from "@/lib/api/client";
import { Card } from "@dco/ui/components/card";
import { Input } from "@dco/ui/components/input";
import { Select } from "@dco/ui/components/select";
import { Button } from "@dco/ui/components/button";
import type { Price } from "@/app/(admin)/pricing/page";
type Term = {
  id: string;
  userId: string | null;
  organizationId: string | null;
  label: string;
  plan: string;
  source: string;
  status: string;
  startsAt: string;
  endsAt: string;
  accessEndsAt: string;
  version: number;
  payment: Record<string, unknown> | null;
  reason: string | null;
};
type Result = {
  items: Term[];
  next_offset: number | null;
  stores: {
    userId: string;
    email: string;
    plan: string;
    state: string;
    expiresAt: string;
    autoRenewing: boolean;
    conflict: boolean;
  }[];
  gifts: {
    id: string;
    email: string;
    plan: string;
    endsAt: string;
  }[];
  legacy: {
    id: string;
    email: string;
    plan: string;
  }[];
  awaiting_review: {
    id: string;
    name: string;
  }[];
};
const isoToday = () => new Date().toISOString().slice(0, 16);
function calculateEnd(start: string, unit: string, count: number) {
  const date = new Date(start + "Z");
  if (!Number.isFinite(date.getTime())) return "";
  if (unit === "days") date.setUTCDate(date.getUTCDate() + count);
  else {
    const day = date.getUTCDate();
    date.setUTCDate(1);
    date.setUTCMonth(date.getUTCMonth() + count * (unit === "years" ? 12 : 1));
    date.setUTCDate(
      Math.min(
        day,
        new Date(
          Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)
        ).getUTCDate()
      )
    );
  }
  return date.toISOString();
}
export function Subscriptions({
  kind: initialKind = "user",
  id: initialId = ""
}: {
  kind?: "user" | "organization";
  id?: string;
}) {
  const qc = useQueryClient();
  const [view, setView] = useState("history");
  const [recording, setRecording] = useState(false);
  const detailsHeading = useRef<HTMLHeadingElement>(null);
  const [correctionReason, setCorrectionReason] = useState("");
  const viewSource =
    view === "play"
      ? "google_play"
      : view === "gifts"
      ? "gift"
      : view === "legacy"
      ? "legacy"
      : "";
  const descriptions: Record<string, string> = {
    history:
      "Direct payments and complimentary access. Open a record to review payments, adjust dates, or inspect its audit history.",
    play:
      "Verified Google Play records. Store dates and charges are read-only.",
    gifts: "Access granted through promotions, with each gift’s expiry date.",
    legacy:
      "Personal assignments without a term and organizations awaiting billing migration."
  };
  const views = [
    { value: "history", label: "Subscription history" },
    ...(initialKind !== "organization"
      ? [
          { value: "play", label: "Google Play" },
          { value: "gifts", label: "Promotional gifts" }
        ]
      : []),
    { value: "legacy", label: "Legacy & review" }
  ];
  const [kind, setKind] = useState<string>(initialKind),
    [id, setId] = useState(initialId),
    [q, setQ] = useState(""),
    [status, setStatus] = useState(""),
    [sourceFilter, setSourceFilter] = useState(""),
    [offset, setOffset] = useState(0);
  const [plan, setPlan] = useState(
      initialKind === "organization" ? "fleet" : "lite"
    ),
    [source, setSource] = useState("direct"),
    [start, setStart] = useState(isoToday),
    [unit, setUnit] = useState("years"),
    [count, setCount] = useState("1"),
    [currency, setCurrency] = useState("MMK"),
    [amount, setAmount] = useState(""),
    [method, setMethod] = useState("cash"),
    [reference, setReference] = useState(""),
    [receipt, setReceipt] = useState(""),
    [reason, setReason] = useState(""),
    [paid, setPaid] = useState(isoToday),
    [renew, setRenew] = useState(false),
    [requestId, setRequestId] = useState(""),
    [selected, setSelected] = useState<Term | null>(null),
    [action, setAction] = useState("correct"),
    [correctStart, setCorrectStart] = useState(""),
    [correctEnd, setCorrectEnd] = useState(""),
    [actionReason, setActionReason] = useState(""),
    [additional, setAdditional] = useState("");
  const [planFilter, setPlanFilter] = useState("");
  useEffect(() => {
    if (selected) detailsHeading.current?.focus();
  }, [selected]);
  const query = useQuery({
    queryKey: [
      "subscriptions",
      initialKind,
      initialId,
      q,
      status,
      sourceFilter,
      viewSource,
      planFilter,
      offset
    ],
    queryFn: () =>
      apiGet<Result>(
        `/admin/subscriptions?offset=${offset}&q=${encodeURIComponent(
          q
        )}&status=${status}&source=${viewSource ||
          sourceFilter}&plan=${planFilter}${
          initialId ? `&kind=${initialKind}&id=${initialId}` : ""
        }`
      )
  });
  const prices = useQuery({
    queryKey: ["prices"],
    queryFn: () =>
      apiGet<{
        items: Price[];
      }>("/admin/prices")
  });
  const price = prices.data?.items.find(p => p.id === plan);
  const catalog =
    unit === "years" && count === "1"
      ? currency === "MMK"
        ? price?.priceAnnualMmk
        : price?.priceAnnualUsd
      : unit === "months" && count === "1"
      ? currency === "MMK"
        ? price?.priceMonthlyMmk
        : price?.priceMonthlyUsd
      : undefined;
  const actual = amount || String(catalog ?? "");
  const latest = query.data?.items
    .filter(
      t =>
        (t.userId ?? t.organizationId) === id &&
        t.source === "direct" &&
        t.status !== "revoked"
    )
    .sort((a, b) => b.endsAt.localeCompare(a.endsAt))[0];
  const effectiveStart =
    renew && latest && new Date(latest.accessEndsAt) > new Date()
      ? latest.endsAt.slice(0, 16)
      : start;
  const end = calculateEnd(effectiveStart, unit, Number(count));
  const refresh = () => qc.invalidateQueries({ queryKey: ["subscriptions"] });
  const create = useMutation({
    mutationFn: ({
      key,
      expectedStart
    }: {
      key: string;
      expectedStart: string;
    }) =>
      apiPost("/admin/subscriptions", {
        request_id: key,
        expected_start: expectedStart,
        kind,
        id,
        plan,
        source,
        starts_at: new Date(start + "Z").toISOString(),
        unit,
        count: Number(count),
        renew,
        reason: reason || undefined,
        price_version: price?.priceVersion,
        ...(source === "direct"
          ? {
              payment: {
                amount: Number(actual),
                currency,
                paid_at: new Date(paid + "Z").toISOString(),
                method,
                reference: reference || undefined,
                receipt: receipt || undefined,
                override_reason: reason || undefined
              }
            }
          : {})
      }),
    onSuccess: () => {
      setRequestId("");
      setAmount("");
      setReason("");
      setRecording(false);
      refresh();
    }
  });
  const change = useMutation({
    mutationFn: () =>
      apiPatch(`/admin/subscriptions/${selected!.id}`, {
        version: selected!.version,
        action,
        reason: actionReason,
        ...(action === "correct"
          ? {
              starts_at: new Date(correctStart + "Z").toISOString(),
              ends_at: new Date(correctEnd + "Z").toISOString()
            }
          : {}),
        ...(action === "upgrade" && Number(additional) > 0
          ? {
              payment: {
                amount: Number(additional),
                currency,
                method,
                paid_at: new Date().toISOString()
              }
            }
          : {})
      }),
    onSuccess: () => {
      setSelected(null);
      setActionReason("");
      refresh();
    }
  });
  const migrate = useMutation({
    mutationFn: (org: string) =>
      apiPost(`/admin/organizations/${org}/migrate-billing`),
    onSuccess: refresh
  });
  const history = useQuery({
    queryKey: ["subscription-history", selected?.id, selected?.version],
    enabled: !!selected,
    queryFn: () =>
      apiGet<{
        items: {
          id: number;
          action: string;
          at: string;
          adminUserId: string;
          detail: unknown;
        }[];
      }>(`/admin/subscriptions/history?id=${selected!.id}`)
  });
  const [freeVehicle, setFreeVehicle] = useState("");
  const correction = useMutation({
    mutationFn: () =>
      apiPost(`/admin/users/${id}/free-vehicle`, {
        vehicle_id: freeVehicle,
        reason: correctionReason
      }),
    onSuccess: refresh
  });
  return (
    <div className="min-w-0 space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="font-display text-2xl font-semibold">
            {recording
              ? "Record subscription"
              : initialId
              ? "Subscription history"
              : "Billing records"}
          </h2>
          <p className="mt-1 max-w-3xl text-sm text-ink-muted">
            {recording
              ? "Record a confirmed payment or grant complimentary access."
              : initialId
              ? "Review this account’s access by source."
              : "Choose a history to review payments, store access, or promotional grants."}
          </p>
        </div>
        <Button
          variant={recording ? "secondary" : "primary"}
          onClick={() => {
            setRecording(!recording);
            create.reset();
          }}
        >
          {recording ? "Back to history" : "Record subscription"}
        </Button>
      </div>
      {create.isSuccess && !recording && (
        <p
          role="status"
          className="rounded-md bg-success-dim p-3 text-sm text-success"
        >
          Subscription saved.
        </p>
      )}
      <div hidden={!recording}>
        <Card className="p-4 sm:p-6 space-y-4">
          <form
            className="space-y-4"
            onSubmit={async e => {
              e.preventDefault();
              try {
                const preview = await apiPost<{
                  starts_at: string;
                  ends_at: string;
                  access_ends_at: string;
                }>("/admin/subscriptions/preview", {
                  kind,
                  id,
                  starts_at: new Date(start + "Z").toISOString(),
                  unit,
                  count: Number(count),
                  renew,
                  source
                });
                const key = requestId || crypto.randomUUID();
                setRequestId(key);
                if (
                  window.confirm(
                    `${
                      source === "direct"
                        ? "Record confirmed payment"
                        : "Grant complimentary access"
                    } for ${id}?\n${preview.starts_at} → ${
                      preview.ends_at
                    }\nAccess ends: ${preview.access_ends_at}\n${
                      source === "direct"
                        ? `${actual} ${currency}`
                        : "No payment; no grace period."
                    }`
                  )
                )
                  create.mutate({ key, expectedStart: preview.starts_at });
              } catch (error) {
                window.alert(
                  error instanceof Error
                    ? error.message
                    : "Could not preview subscription"
                );
              }
            }}
          >
            <div className="grid gap-4 md:grid-cols-3">
              <Select
                label="Subscriber"
                disabled={!!initialId}
                value={kind}
                onChange={v => {
                  setKind(v);
                  setPlan(v === "organization" ? "fleet" : "lite");
                }}
                options={[
                  { value: "user", label: "Personal account" },
                  { value: "organization", label: "Organization" }
                ]}
              />
              <Input
                label="Subscriber ID"
                readOnly={!!initialId}
                required
                value={id}
                onChange={e => {
                  setId(e.target.value);
                  setRequestId("");
                }}
              />
              <Select
                label="Plan"
                value={plan}
                onChange={setPlan}
                options={(kind === "organization"
                  ? ["fleet"]
                  : ["lite", "standard"]
                ).map(value => ({ value, label: value }))}
              />
              <Select
                label="Access source"
                value={source}
                onChange={setSource}
                options={[
                  { value: "direct", label: "Confirmed direct payment" },
                  { value: "complimentary", label: "Complimentary grant" }
                ]}
              />
              <Input
                label="Start (UTC)"
                type="datetime-local"
                required
                value={start}
                onChange={e => setStart(e.target.value)}
              />
              <Select
                label="Duration unit"
                value={unit}
                onChange={setUnit}
                options={["months", "years", "days"].map(value => ({
                  value,
                  label: value
                }))}
              />
              <Input
                label="Duration"
                type="number"
                min={1}
                max={3650}
                required
                value={count}
                onChange={e => setCount(e.target.value)}
              />
              {source === "direct" && (
                <>
                  <Select
                    label="Currency"
                    value={currency}
                    onChange={setCurrency}
                    options={["MMK", "USD"].map(value => ({
                      value,
                      label: value
                    }))}
                  />
                  <Input
                    label={`Amount paid (catalog: ${catalog ??
                      "custom quote"})`}
                    required
                    type="number"
                    min={0.01}
                    step={0.01}
                    value={actual}
                    onChange={e => setAmount(e.target.value)}
                  />
                  <Input
                    label="Payment date (UTC)"
                    type="datetime-local"
                    required
                    value={paid}
                    onChange={e => setPaid(e.target.value)}
                  />
                  <Input
                    label="Payment method"
                    required
                    value={method}
                    onChange={e => setMethod(e.target.value)}
                  />
                  <Input
                    label="Reference (optional)"
                    value={reference}
                    onChange={e => setReference(e.target.value)}
                  />
                  <Input
                    label="Receipt URL (optional)"
                    type="url"
                    value={receipt}
                    onChange={e => setReceipt(e.target.value)}
                  />
                </>
              )}
              <Input
                label="Grant / negotiated-price reason"
                required={
                  source === "complimentary" ||
                  catalog === undefined ||
                  Number(actual) !== Number(catalog)
                }
                value={reason}
                onChange={e => setReason(e.target.value)}
              />
            </div>
            {source === "direct" && (
              <label className="flex gap-2">
                <input
                  type="checkbox"
                  checked={renew}
                  onChange={e => setRenew(e.target.checked)}
                />
                Renew from existing paid expiry when still active or in grace
              </label>
            )}
            <p className="text-sm">
              Preview: {effectiveStart} UTC → {end || "Choose valid dates"}.{" "}
              {renew && !latest
                ? "Open the subscriber detail page to preview its renewal dates. The server validates the final term."
                : ""}
            </p>
            {create.error && (
              <p role="alert" className="text-danger">
                {create.error.message}
              </p>
            )}
            {create.isSuccess && <p role="status">Subscription saved.</p>}
            <>
              {prices.error && (
                <p role="alert" className="text-danger">
                  Could not load plan prices.{" "}
                  <button
                    type="button"
                    className="underline"
                    onClick={() => prices.refetch()}
                  >
                    Try again
                  </button>
                </p>
              )}
            </>
            <Button type="submit" disabled={create.isPending || !price}>
              {create.isPending ? "Saving…" : "Review and save"}
            </Button>
          </form>
        </Card>
      </div>
      <div hidden={recording} className="space-y-5">
        <HistoryNavigation
          label="Subscription histories"
          options={views}
          value={view}
          onChange={value => {
            setView(value);
            setOffset(0);
            setStatus("");
            setSourceFilter("");
            setPlanFilter("");
            setSelected(null);
          }}
        />
        <Card className="overflow-hidden">
          <div className="space-y-4 border-b border-line p-4 sm:p-6">
            <div>
              <h3 className="font-display text-xl font-semibold">
                {views.find(item => item.value === view)?.label}
              </h3>
              <p className="mt-1 max-w-3xl text-sm text-ink-muted">
                {descriptions[view]}
              </p>
            </div>
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
              <Input
                label={
                  initialId
                    ? "Search account"
                    : "Search account or organization"
                }
                value={q}
                onChange={e => {
                  setQ(e.target.value);
                  setOffset(0);
                }}
              />
              {view !== "legacy" && (
                <Select
                  label="Status"
                  value={status}
                  onChange={v => {
                    setStatus(v);
                    setOffset(0);
                  }}
                  options={[
                    "",
                    "active",
                    "scheduled",
                    ...(view !== "gifts" ? ["grace"] : []),
                    "expired",
                    ...(view === "history" ? ["revoked"] : [])
                  ].map(value => ({ value, label: value || "All statuses" }))}
                />
              )}
              {view !== "legacy" && (
                <Select
                  label="Plan"
                  value={planFilter}
                  onChange={v => {
                    setPlanFilter(v);
                    setOffset(0);
                  }}
                  options={[
                    "",
                    "lite",
                    "standard",
                    ...(view === "history" ? ["fleet"] : [])
                  ].map(value => ({ value, label: value || "All plans" }))}
                />
              )}
              {view === "history" && (
                <Select
                  label="Source"
                  value={sourceFilter}
                  onChange={v => {
                    setSourceFilter(v);
                    setOffset(0);
                  }}
                  options={[
                    { value: "", label: "All admin-issued terms" },
                    { value: "direct", label: "Direct payment" },
                    { value: "complimentary", label: "Complimentary access" }
                  ]}
                />
              )}
            </div>
          </div>
          {query.isLoading && (
            <p role="status" className="p-6 text-ink-muted">
              Loading{" "}
              {views.find(item => item.value === view)?.label.toLowerCase()}…
            </p>
          )}
          {query.error && (
            <div role="alert" className="p-6 text-danger">
              {query.error.message}{" "}
              <Button variant="secondary" onClick={() => query.refetch()}>
                Try again
              </Button>
            </div>
          )}
          {query.isSuccess && (
            <>
              {view === "history" && (
                <>
                  <div className="overflow-x-auto">
                    <table className="w-full text-left text-sm">
                      <thead className="bg-panel text-ink-muted">
                        <tr>
                          {[
                            "Customer",
                            "Plan / source",
                            "Status",
                            "Start (UTC)",
                            "Expiry / grace end (UTC)",
                            "Actions"
                          ].map(h => (
                            <th scope="col" className="p-3 font-medium" key={h}>
                              {h}
                            </th>
                          ))}
                        </tr>
                      </thead>
                      <tbody>
                        {query.data?.items.map(t => (
                          <tr key={t.id} className="border-b border-line">
                            <td className="p-3">
                              <a
                                href={
                                  t.organizationId
                                    ? `/organizations/${t.organizationId}`
                                    : `/users/${t.userId}`
                                }
                              >
                                {t.label}
                              </a>
                            </td>
                            <td className="p-3">
                              {t.plan} / {t.source}
                            </td>
                            <td className="p-3">
                              {t.status}
                              <br />
                              {["active", "grace"].includes(t.status)
                                ? `${Math.max(
                                    0,
                                    Math.ceil(
                                      (new Date(t.accessEndsAt).getTime() -
                                        Date.now()) /
                                        86400000
                                    )
                                  )} days of access remaining`
                                : null}
                            </td>
                            <td className="p-3">
                              {formatTimestamp(t.startsAt)}
                            </td>
                            <td className="p-3">
                              {formatTimestamp(t.endsAt)}
                              <br />
                              {t.source === "direct"
                                ? formatTimestamp(t.accessEndsAt)
                                : "No grace"}
                            </td>
                            <td className="p-3">
                              <Button
                                variant="secondary"
                                onClick={() => {
                                  change.reset();
                                  setActionReason("");
                                  setAdditional("");
                                  setSelected(t);
                                  setCorrectStart(t.startsAt.slice(0, 16));
                                  setCorrectEnd(t.endsAt.slice(0, 16));
                                  setAction("correct");
                                }}
                              >
                                Details / manage
                              </Button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  {query.data?.items.length === 0 && (
                    <p className="p-6 text-sm text-ink-muted">
                      No matching subscription records. Adjust the filters or
                      record a subscription.
                    </p>
                  )}
                </>
              )}
              {view === "play" && (
                <HistoryTable
                  headings={[
                    "Account",
                    "Plan",
                    "Store status",
                    "Expiry (UTC)",
                    "Renewal"
                  ]}
                  empty={!query.data.stores.length}
                  emptyText="No matching Google Play records. Try another search or filter."
                >
                  {query.data.stores.map((s, index) => (
                    <tr key={`${s.userId}-${s.expiresAt}-${index}`}>
                      <td>
                        <a
                          className="text-link hover:underline"
                          href={`/users/${s.userId}`}
                        >
                          {s.email}
                        </a>
                      </td>
                      <td className="capitalize">{s.plan}</td>
                      <td>
                        {s.state
                          .replace("SUBSCRIPTION_STATE_", "")
                          .replaceAll("_", " ")
                          .toLowerCase()}
                        {s.conflict && (
                          <p className="mt-2 text-warning">
                            Needs reconciliation: overlapping admin-issued
                            access
                          </p>
                        )}
                      </td>
                      <td>{formatTimestamp(s.expiresAt)}</td>
                      <td>
                        {s.autoRenewing ? "Auto-renews" : "Auto-renew off"}
                      </td>
                    </tr>
                  ))}
                </HistoryTable>
              )}
              {view === "gifts" && (
                <HistoryTable
                  headings={["Account", "Plan", "Expiry (UTC)"]}
                  empty={!query.data.gifts.length}
                  emptyText="No matching promotional gifts. Try another search or filter."
                >
                  {query.data.gifts.map(g => (
                    <tr key={g.id}>
                      <td>{g.email}</td>
                      <td className="capitalize">{g.plan}</td>
                      <td>{formatTimestamp(g.endsAt)}</td>
                    </tr>
                  ))}
                </HistoryTable>
              )}
              {view === "legacy" && (
                <div className="space-y-6 p-4 sm:p-6">
                  <section>
                    <h4 className="mb-3 font-display text-lg">
                      Legacy personal assignments
                    </h4>
                    <HistoryTable
                      headings={["Account", "Plan", "Term"]}
                      empty={!query.data.legacy.length}
                      emptyText="No legacy personal assignments on this page."
                    >
                      {query.data.legacy.map(u => (
                        <tr key={u.id}>
                          <td>
                            <a
                              className="text-link hover:underline"
                              href={`/users/${u.id}`}
                            >
                              {u.email}
                            </a>
                          </td>
                          <td className="capitalize">{u.plan}</td>
                          <td>No term assigned</td>
                        </tr>
                      ))}
                    </HistoryTable>
                  </section>
                  <section>
                    <h4 className="mb-3 font-display text-lg">
                      Organizations awaiting migration review
                    </h4>
                    {!query.data.awaiting_review.length && (
                      <p className="text-sm text-ink-muted">
                        No organizations awaiting review on this page.
                      </p>
                    )}
                    {query.data.awaiting_review.map(o => (
                      <div
                        className="flex flex-wrap items-center justify-between gap-4 border-b border-line py-3"
                        key={o.id}
                      >
                        <a
                          className="text-link hover:underline"
                          href={`/organizations/${o.id}`}
                        >
                          {o.name}
                        </a>
                        <Button
                          variant="secondary"
                          disabled={migrate.isPending}
                          onClick={() => {
                            if (
                              window.confirm(
                                "Confirm migration? Assigned terms will permanently govern access. Review dates first."
                              )
                            )
                              migrate.mutate(o.id);
                          }}
                        >
                          Confirm migration
                        </Button>
                      </div>
                    ))}
                    {migrate.error && (
                      <p role="alert" className="text-danger">
                        {migrate.error.message}
                      </p>
                    )}
                  </section>
                </div>
              )}
              <div className="flex flex-wrap items-center justify-between gap-3 border-t border-line p-4">
                <span className="text-sm text-ink-muted">
                  Page {Math.floor(offset / 50) + 1}
                </span>
                <div className="flex gap-2">
                  <Button
                    variant="secondary"
                    disabled={!offset || query.isFetching}
                    onClick={() => setOffset(Math.max(0, offset - 50))}
                  >
                    Previous
                  </Button>
                  <Button
                    variant="secondary"
                    disabled={
                      query.data.next_offset == null ||
                      query.isFetching ||
                      (view === "history" && query.data.items.length < 50)
                    }
                    onClick={() => setOffset(query.data!.next_offset!)}
                  >
                    Next
                  </Button>
                </div>
              </div>
            </>
          )}
        </Card>
        {selected && (
          <Card className="p-6 space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <h2
                ref={detailsHeading}
                tabIndex={-1}
                className="font-display text-xl focus-visible:outline-2 focus-visible:outline-focus"
              >
                Manage {selected.label}
              </h2>
              <Button variant="secondary" onClick={() => setSelected(null)}>
                Close details
              </Button>
            </div>
            <pre className="whitespace-pre-wrap text-sm">
              {JSON.stringify(
                selected.payment ?? { reason: selected.reason },
                null,
                2
              )}
            </pre>
            <form
              className="space-y-4"
              onSubmit={e => {
                e.preventDefault();
                if (
                  window.confirm(
                    `Confirm ${action}? Revocation does not issue a refund.`
                  )
                )
                  change.mutate();
              }}
            >
              <Select
                label="Action"
                value={action}
                onChange={setAction}
                options={[
                  { value: "correct", label: "Correct dates" },
                  { value: "revoke", label: "Revoke immediately" },
                  ...(selected.plan === "lite" &&
                  selected.source === "direct" &&
                  selected.status === "active"
                    ? [{ value: "upgrade", label: "Upgrade to Standard" }]
                    : [])
                ]}
              />
              {action === "correct" && (
                <div className="grid gap-4 md:grid-cols-2">
                  <Input
                    label="Start (UTC)"
                    type="datetime-local"
                    required
                    value={correctStart}
                    onChange={e => setCorrectStart(e.target.value)}
                  />
                  <Input
                    label="Expiry (UTC)"
                    type="datetime-local"
                    required
                    value={correctEnd}
                    onChange={e => setCorrectEnd(e.target.value)}
                  />
                </div>
              )}
              {action === "upgrade" && (
                <>
                  <Input
                    label={`Additional payment (${currency}, ${method}); leave empty for complimentary upgrade`}
                    type="number"
                    min={0}
                    step={0.01}
                    value={additional}
                    onChange={e => setAdditional(e.target.value)}
                  />
                  <Select
                    label="Currency"
                    value={currency}
                    onChange={setCurrency}
                    options={[
                      { value: "MMK", label: "MMK" },
                      { value: "USD", label: "USD" }
                    ]}
                  />
                  <Input
                    label="Payment method"
                    required
                    value={method}
                    onChange={e => setMethod(e.target.value)}
                  />
                  <p>Expiry stays unchanged.</p>
                </>
              )}
              <Input
                label="Required reason"
                required
                value={actionReason}
                onChange={e => setActionReason(e.target.value)}
              />
              {change.error && <p role="alert">{change.error.message}</p>}
              <Button
                disabled={change.isPending || selected.status === "revoked"}
                type="submit"
              >
                Confirm change
              </Button>
            </form>
            <h3>Audit history</h3>
            {history.error && <p role="alert">{history.error.message}</p>}
            {history.data?.items.map(h => (
              <details key={h.id}>
                <summary>
                  {h.at} — {h.action} — admin {h.adminUserId}
                </summary>
                <pre className="whitespace-pre-wrap text-xs">
                  {JSON.stringify(h.detail, null, 2)}
                </pre>
              </details>
            ))}
          </Card>
        )}
      </div>
      {initialId && initialKind === "user" && !recording && (
        <details className="rounded-lg border border-line-strong p-4">
          <summary className="cursor-pointer font-display text-lg focus-visible:outline-2 focus-visible:outline-focus">
            Free vehicle correction
          </summary>
          <div className="mt-4 max-w-xl space-y-4">
            <p className="text-sm text-ink-muted">
              Correct the vehicle locked to this account’s Free plan. A reason
              is required for the audit log.
            </p>
            <Input
              label="Owned vehicle ID"
              value={freeVehicle}
              onChange={e => setFreeVehicle(e.target.value)}
            />
            <Input
              label="Correction reason"
              required
              value={correctionReason}
              onChange={e => setCorrectionReason(e.target.value)}
            />
            <Button
              variant="secondary"
              disabled={
                !freeVehicle || !correctionReason || correction.isPending
              }
              onClick={() => correction.mutate()}
            >
              Save audited correction
            </Button>
            {correction.error && (
              <p role="alert" className="text-danger">
                {correction.error.message}
              </p>
            )}
            {correction.isSuccess && (
              <p role="status" className="text-success">
                Free vehicle corrected.
              </p>
            )}
          </div>
        </details>
      )}
    </div>
  );
}

function formatTimestamp(value: string) {
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? value
    : new Intl.DateTimeFormat("en-GB", {
        dateStyle: "medium",
        timeStyle: "short",
        timeZone: "UTC"
      }).format(date);
}

function HistoryTable({
  headings,
  empty,
  emptyText,
  children
}: {
  headings: string[];
  empty: boolean;
  emptyText: string;
  children: React.ReactNode;
}) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-left text-sm">
        <thead className="bg-panel text-ink-muted">
          <tr>
            {headings.map(heading => (
              <th scope="col" className="px-4 py-3 font-medium" key={heading}>
                {heading}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="[&_td]:px-4 [&_td]:py-4 [&_td]:align-top [&_tr]:border-b [&_tr]:border-line">
          {children}
        </tbody>
      </table>
      {empty && <p className="p-6 text-sm text-ink-muted">{emptyText}</p>}
    </div>
  );
}
