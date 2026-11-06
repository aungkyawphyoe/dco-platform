"use client";

import { money as formatMoney } from "@dco/ui/lib/format";
import { useState, useRef, useEffect, useId, ReactNode } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiGet, apiPut, apiDownload } from "@/lib/api/client";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";
import type { AnalyticsReport, AnalyticsExpense } from "@/lib/api/analytics";
import styles from "./report.module.css";

type Settings = { currency: string | null; timezone: string };
type Filter = {
  preset: string;
  from: string;
  to: string;
  vehicles: string[];
  active: boolean;
};
const label = (s: string) =>
  s.replaceAll("_", " ").replace(/^./, c => c.toUpperCase());
const number = (n: number | null, digits = 1) =>
  n == null
    ? "Unavailable"
    : new Intl.NumberFormat("en", { maximumFractionDigits: digits }).format(n);
const categoryColor = (c: string) =>
  `var(--chart-${
    ["fuel", "maintenance", "insurance", "parking", "tolls", "parts"].includes(
      c
    )
      ? c
      : "other"
  })`;
const monthLabel = (s: string) =>
  new Date(`${s}-01T00:00:00Z`).toLocaleDateString("en", {
    month: "short",
    year: "2-digit",
    timeZone: "UTC"
  });
function presetRange(preset: string, today: string) {
  const date = new Date(`${today}T00:00:00Z`),
    y = date.getUTCFullYear(),
    m = date.getUTCMonth();
  const iso = (d: Date) => d.toISOString().slice(0, 10);
  return {
    from: iso(
      new Date(
        Date.UTC(
          y,
          m -
            (preset === "last12"
              ? 11
              : preset === "last3"
              ? 2
              : preset === "last"
              ? 1
              : 0),
          1
        )
      )
    ),
    to: preset === "last" ? iso(new Date(Date.UTC(y, m, 0))) : today
  };
}
function queryString(f: Filter, today: string) {
  const range =
    f.preset === "custom"
      ? { from: f.from, to: f.to }
      : presetRange(f.preset, today);
  const p = new URLSearchParams({
    ...range,
    calendar: String(f.preset !== "custom"),
    active: String(f.active)
  });
  if (f.vehicles.length) p.set("vehicles", f.vehicles.join(","));
  return p.toString();
}
function Change({ value }: { value: number | null }) {
  return (
    <span className={styles.change}>
      {value == null
        ? "No comparable baseline"
        : `${value > 0 ? "+" : ""}${number(value)}% vs previous period`}
    </span>
  );
}
function Section({
  title,
  note,
  children
}: {
  title: string;
  note?: string;
  children: ReactNode;
}) {
  return (
    <section className={styles.section}>
      <div className={styles.sectionHeading}>
        <h2>{title}</h2>
        {note && <p>{note}</p>}
      </div>
      {children}
    </section>
  );
}
function Trend({
  values,
  labels,
  unit,
  color = "var(--chart-maintenance)"
}: {
  values: (number | null)[];
  labels: string[];
  unit: string;
  color?: string;
}) {
  const valid = values.filter((v): v is number => v !== null),
    max = Math.max(...valid, 1);
  if (!valid.length)
    return (
      <p className={styles.empty}>
        Not enough compatible readings for this trend. Add dated odometer
        readings and complete fuel or charging records.
      </p>
    );
  const x = (i: number) => 38 + (i * 610) / Math.max(values.length - 1, 1),
    y = (n: number) => 135 - (n / max) * 110;
  return (
    <>
      <svg
        className={styles.trend}
        viewBox="0 0 680 170"
        role="img"
        aria-label={`${unit} by month. Missing months are gaps.`}
      >
        {[0, 0.5, 1].map(t => (
          <g key={t}>
            <line
              x1="38"
              x2="650"
              y1={y(max * t)}
              y2={y(max * t)}
              stroke="var(--border-divider)"
            />
            <text x="30" y={y(max * t) + 4} textAnchor="end">
              {number(max * t)}
            </text>
          </g>
        ))}
        {values.map((v, i) =>
          v == null ? null : (
            <g key={i}>
              {i > 0 && values[i - 1] != null && (
                <line
                  x1={x(i - 1)}
                  y1={y(values[i - 1]!)}
                  x2={x(i)}
                  y2={y(v)}
                  stroke={color}
                  strokeWidth="2.5"
                />
              )}
              <circle cx={x(i)} cy={y(v)} r="4" fill={color}>
                <title>
                  {labels[i]}: {number(v, 2)} {unit}
                </title>
              </circle>
              {(values.length <= 6 ||
                i % 2 === 0 ||
                i === values.length - 1) && (
                <text x={x(i)} y="160" textAnchor="middle">
                  {labels[i]}
                </text>
              )}
            </g>
          )
        )}
      </svg>
      <details className={styles.chartData}>
        <summary>View monthly values</summary>
        <dl>
          {values.map((v, i) => (
            <div key={i}>
              <dt>{labels[i]}</dt>
              <dd>
                {number(v, 2)} {v == null ? "" : unit}
              </dd>
            </div>
          ))}
        </dl>
      </details>
    </>
  );
}

type Slice = {
  key: string;
  label: string;
  value: number;
  color: string;
  detail?: string;
  /// Marks spend that has no supporting detail. Hatched so it never reads as
  /// just another named category.
  unallocated?: boolean;
};

/// Fixed order keeps service-type colours stable as the report changes. The
/// expense charts keep their semantic category colours instead.
const serviceColors = [
  "var(--chart-maintenance)",
  "var(--chart-fuel)",
  "var(--chart-parts)",
  "var(--chart-insurance)",
  "var(--chart-parking)",
  "var(--chart-tolls)"
];
const UNALLOCATED = "Unallocated";
const DONUT_RADIUS = 52;
const DONUT_CIRCUMFERENCE = 2 * Math.PI * DONUT_RADIUS;

/// Ring chart with the period total at its centre and a ranked, readable
/// legend. The legend is the accessible version of the chart: every slice is
/// named, quantified, and — when [onSelect] is set — keyboard operable.
function Composition({
  slices,
  centerLabel,
  formatValue,
  money,
  onSelect,
  empty,
  caption
}: {
  slices: Slice[];
  centerLabel: string;
  formatValue: (value: number) => string;
  money: (value: number | null, digits?: number) => string;
  onSelect?: (slice: Slice) => void;
  empty: string;
  caption?: string;
}) {
  const visible = slices.filter(slice => slice.value > 0),
    total = visible.reduce((sum, slice) => sum + slice.value, 0),
    patternId = `unallocated-${useId().replace(/:/g, "")}`;
  if (!visible.length || total <= 0)
    return <p className={styles.empty}>{empty}</p>;
  const percent = (value: number) => (value / total) * 100;
  // One decimal keeps the rounded shares from summing to 101% or 99% while
  // still reading as a share, not a measurement.
  const share = (value: number) => number(percent(value), 1);
  let offset = 0;
  return (
    <div className={styles.composition}>
      <div className={styles.donut}>
        <svg
          viewBox="0 0 140 140"
          role="img"
          aria-label={`${centerLabel}: ${formatValue(total)}. ${visible
            .map(slice => `${slice.label} ${share(slice.value)} percent`)
            .join(", ")}.`}
        >
          <defs>
            <pattern
              id={patternId}
              width="6"
              height="6"
              patternUnits="userSpaceOnUse"
              patternTransform="rotate(45)"
            >
              <rect width="6" height="6" fill="var(--bg-secondary)" />
              <line
                x1="0"
                y1="0"
                x2="0"
                y2="6"
                stroke="var(--text-tertiary)"
                strokeWidth="2.5"
              />
            </pattern>
          </defs>
          <circle
            cx="70"
            cy="70"
            r={DONUT_RADIUS}
            fill="none"
            stroke="var(--bg-secondary)"
            strokeWidth="16"
          />
          <g className={styles.donutRing}>
            {visible.map(slice => {
              const length = (slice.value / total) * DONUT_CIRCUMFERENCE,
                dash = length > 3 ? length - 2 : length,
                circle = (
                  <circle
                    key={slice.key}
                    cx="70"
                    cy="70"
                    r={DONUT_RADIUS}
                    fill="none"
                    stroke={
                      slice.unallocated ? `url(#${patternId})` : slice.color
                    }
                    strokeWidth="16"
                    strokeDasharray={`${dash} ${DONUT_CIRCUMFERENCE}`}
                    strokeDashoffset={-offset}
                    transform="rotate(-90 70 70)"
                  >
                    <title>{`${slice.label}: ${money(
                      slice.value
                    )} (${share(slice.value)}%)`}</title>
                  </circle>
                );
              offset += length;
              return circle;
            })}
          </g>
        </svg>
        <div className={styles.donutCenter}>
          <strong>{formatValue(total)}</strong>
          <span>{centerLabel}</span>
        </div>
      </div>
      <div className={styles.compositionBody}>
        <ul className={styles.legend}>
          {visible.map(slice => {
            const content = (
              <>
                <i
                  className={slice.unallocated ? styles.hatched : undefined}
                  style={
                    slice.unallocated ? undefined : { background: slice.color }
                  }
                />
                <span className={styles.legendLabel}>
                  {slice.label}
                  {slice.detail && <small>{slice.detail}</small>}
                </span>
                <span className={styles.legendShare}>
                  {share(slice.value)}%
                </span>
                <strong>{formatValue(slice.value)}</strong>
              </>
            );
            return (
              <li key={slice.key}>
                {onSelect ? (
                  <button
                    type="button"
                    className={styles.legendRow}
                    onClick={() => onSelect(slice)}
                  >
                    {content}
                  </button>
                ) : (
                  <div className={styles.legendRow}>{content}</div>
                )}
              </li>
            );
          })}
        </ul>
        {caption && <p className={styles.caption}>{caption}</p>}
      </div>
    </div>
  );
}

/// Single-series monthly cost. Used by the scoped Maintenance and Expenses
/// reports, where a stacked bar would repeat what the adjacent ring already
/// says.
function ScopedBars({
  months,
  values,
  color,
  formatValue,
  ariaLabel,
  onSelect,
  empty
}: {
  months: { month: string; from: string; to: string }[];
  values: number[];
  color: string;
  formatValue: (value: number) => string;
  ariaLabel: (month: string, value: number) => string;
  onSelect: (month: { month: string; from: string; to: string }) => void;
  empty: string;
}) {
  if (!values.some(value => value > 0))
    return <p className={styles.empty}>{empty}</p>;
  const max = Math.max(...values, 1);
  return (
    <div className={styles.columns}>
      {months.map((month, index) => {
        const value = values[index] ?? 0;
        return (
          <button
            type="button"
            key={month.month}
            className={styles.column}
            onClick={() => onSelect(month)}
            aria-label={ariaLabel(month.month, value)}
          >
            <span className={styles.barValue} aria-hidden={value <= 0}>
              {value > 0 ? formatValue(value) : "\u00A0"}
            </span>
            <span className={styles.barTrack}>
              <span
                className={styles.stack}
                style={{ height: `${(value / max) * 100}%` }}
              >
                <span style={{ background: color, height: "100%" }} />
              </span>
            </span>
            <span>{monthLabel(month.month)}</span>
          </button>
        );
      })}
    </div>
  );
}

export default function AnalyticsPage() {
  const role = useOrgRole(),
    org = useOrgId();
  if (!["org_admin", "org_manager"].includes(role ?? ""))
    return (
      <div className={styles.page}>
        <h1>Analytics</h1>
        <p>Fleet administrators and managers can access this report.</p>
      </div>
    );
  return <Analytics key={org} org={org!} admin={role === "org_admin"} />;
}
function Analytics({ org, admin }: { org: string; admin: boolean }) {
  const base = `/organizations/${org}/analytics`,
    client = useQueryClient();
  const settings = useQuery({
    queryKey: ["analytics-settings", org],
    queryFn: () => apiGet<Settings>(`${base}/settings`)
  });
  const [view, setView] = useState("costs");
  const [timezone, setTimezone] = useState<string | null>(null);
  const save = useMutation({
    mutationFn: () =>
      apiPut<Settings>(`${base}/settings`, {
        timezone: timezone ?? settings.data?.timezone
      }),
    onSuccess: () => {
      void client.invalidateQueries({ queryKey: ["analytics-settings", org] });
      void client.invalidateQueries({ queryKey: ["analytics", org] });
    }
  });
  const today = new Intl.DateTimeFormat("en-CA", {
    timeZone: settings.data?.timezone ?? "UTC",
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).format(new Date());
  const [filter, setFilter] = useState<Filter>({
    preset: "last12",
    ...presetRange("last12", today),
    vehicles: [],
    active: false
  });
  const [draft, setDraft] = useState(filter),
    [downloadError, setDownloadError] = useState(""),
    [downloading, setDownloading] = useState(false);
  const params = queryString(filter, today);
  const report = useQuery({
    queryKey: [
      "analytics",
      org,
      params,
      settings.data?.currency,
      settings.data?.timezone
    ],
    queryFn: () => apiGet<AnalyticsReport>(`${base}/report?${params}`),
    enabled: !!settings.data?.currency
  });
  const [drill, setDrill] = useState<{ title: string; params: string } | null>(
    null
  );
  const [sort, setSort] = useState<{
    key:
      | "name"
      | "total_cost"
      | "distance_km"
      | "cost_per_km"
      | "cost_per_day"
      | "efficiency";
    desc: boolean;
  }>({ key: "total_cost", desc: true });
  const [trend, setTrend] = useState<"cost_per_km" | "cost_per_day">(
    "cost_per_km"
  );
  async function download(kind: string, query = params) {
    setDownloading(true);
    setDownloadError("");
    try {
      const blob = await apiDownload(`${base}/export?${query}&kind=${kind}`),
        url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `fleet-${kind}.csv`;
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (e) {
      setDownloadError(
        e instanceof Error ? e.message : "Export failed. Try again."
      );
    } finally {
      setDownloading(false);
    }
  }
  function openRecords(title: string, additions: Record<string, string>) {
    const p = new URLSearchParams(params);
    Object.entries(additions).forEach(([k, v]) => p.set(k, v));
    setDrill({ title, params: p.toString() });
  }
  if (settings.isPending)
    return (
      <div className={styles.page} role="status">
        Loading reporting settings…
      </div>
    );
  if (settings.error)
    return (
      <div className={styles.page} role="alert">
        {settings.error.message}
        <button onClick={() => settings.refetch()}>Try again</button>
      </div>
    );
  if (!settings.data?.currency)
    return (
      <div className={styles.page}>
        <h1>Fleet analytics</h1>
        <p>
          A Fleet Admin must select the fleet currency in organization settings
          before comparing costs.
        </p>
        <a href="/settings">Organization settings</a>
      </div>
    );
  const r = report.data,
    money = (
      v: number | null,
      digits = settings.data?.currency === "MMK" ? 0 : 2
    ) =>
      v == null
        ? "Unavailable"
        : formatMoney(v, digits, r?.currency ?? settings.data?.currency ?? "MMK");
  const sorted = [...(r?.vehicles ?? [])].sort((a, b) => {
    const av = sort.key === "efficiency" ? a.efficiency.value : a[sort.key],
      bv = sort.key === "efficiency" ? b.efficiency.value : b[sort.key];
    if (av == null) return bv == null ? 0 : 1;
    if (bv == null) return -1;
    if (sort.key === "efficiency" && a.efficiency.group !== b.efficiency.group)
      return String(a.efficiency.group).localeCompare(
        String(b.efficiency.group)
      );
    return (
      (typeof av === "string"
        ? av.localeCompare(String(bv))
        : av - Number(bv)) * (sort.desc ? -1 : 1)
    );
  });
  const categories = Object.entries(r?.categories ?? {}).sort(
    (a, b) => b[1] - a[1]
  );
  const digits = r?.currency === "MMK" ? 0 : 2;
  // Service types are ranked, then folded to six slices plus an honest tail.
  // Unallocated is never folded: it is the part of maintenance spending that
  // has no line-item detail behind it.
  const serviceTypes = r?.service_types ?? {},
    serviceEntries = Object.entries(serviceTypes)
      .filter(([name]) => name !== UNALLOCATED)
      .sort((a, b) => b[1] - a[1]),
    otherServiceValue = serviceEntries
      .slice(6)
      .reduce((sum, [, value]) => sum + value, 0),
    unallocatedValue = serviceTypes[UNALLOCATED] ?? 0,
    serviceSlices: Slice[] = [
      ...serviceEntries.slice(0, 6).map(([name, value], index) => ({
        key: name,
        label: name,
        value,
        color: serviceColors[index] ?? "var(--chart-other)"
      })),
      ...(otherServiceValue > 0
        ? [
            {
              key: "other-service-types",
              label: "Other service types",
              value: otherServiceValue,
              color: "var(--chart-other)"
            }
          ]
        : []),
      ...(unallocatedValue > 0
        ? [
            {
              key: UNALLOCATED,
              label: UNALLOCATED,
              value: unallocatedValue,
              color: "var(--text-tertiary)",
              detail: "Manual or missing line items",
              unallocated: true
            }
          ]
        : [])
    ];
  // Expenses here mean everything the Maintenance and Cost overview reports do
  // not already own: fuel and maintenance are excluded on purpose.
  const expenseCategories = categories.filter(
      ([category]) => category !== "fuel" && category !== "maintenance"
    ),
    expenseSlices: Slice[] = expenseCategories.map(([category, value]) => ({
      key: category,
      label: label(category),
      value,
      color: categoryColor(category)
    })),
    expenseMonthValues =
      r?.months.map(month =>
        expenseCategories.reduce(
          (sum, [category]) => sum + (month.categories[category] ?? 0),
          0
        )
      ) ?? [],
    expenseCategoryList = expenseCategories.map(([category]) => category).join(",");
  const filtersChanged = JSON.stringify(draft) !== JSON.stringify(filter);
  const displayDate = (value: string) =>
    new Date(`${value}T00:00:00Z`).toLocaleDateString("en-GB", {
      day: "numeric",
      month: "short",
      year: "numeric",
      timeZone: "UTC"
    });
  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <h1>Fleet analytics</h1>
          <p>
            Understand operating costs, compare vehicles, and inspect the
            records behind them.
          </p>
        </div>
        <details className={styles.exportMenu}>
          <summary>Export CSV</summary>
          <div className={styles.exports}>
            <button
              disabled={!r || downloading}
              onClick={() => download("vehicles")}
            >
              Vehicle comparison
            </button>
            <button
              disabled={!r || downloading}
              onClick={() => download("expenses")}
            >
              Expense records
            </button>
            {downloading && <p role="status">Preparing export…</p>}
          </div>
        </details>
      </header>
      {downloadError && (
        <p role="alert" className={styles.error}>
          {downloadError}
        </p>
      )}
      <form
        className={styles.filters}
        onSubmit={e => {
          e.preventDefault();
          setFilter(draft);
        }}
      >
        <label>
          Period
          <select
            value={draft.preset}
            onChange={e => setDraft({ ...draft, preset: e.target.value })}
          >
            <option value="this">This month</option>
            <option value="last">Last month</option>
            <option value="last3">Last 3 months</option>
            <option value="last12">Last 12 months</option>
            <option value="custom">Custom range</option>
          </select>
        </label>
        {draft.preset === "custom" && (
          <>
            <label>
              From
              <input
                type="date"
                value={draft.from}
                max={draft.to}
                required
                onChange={e => setDraft({ ...draft, from: e.target.value })}
              />
            </label>
            <label>
              To
              <input
                type="date"
                value={draft.to}
                min={draft.from}
                max={today}
                required
                onChange={e => setDraft({ ...draft, to: e.target.value })}
              />
            </label>
          </>
        )}
        <details className={styles.vehicleFilter}>
          <summary>
            {draft.vehicles.length
              ? `${draft.vehicles.length} vehicles selected`
              : "All vehicles"}
          </summary>
          <div>
            <button
              type="button"
              onClick={() => setDraft({ ...draft, vehicles: [] })}
            >
              Select all vehicles
            </button>
            {r?.catalog.map(v => (
              <label className={styles.check} key={v.id}>
                <input
                  type="checkbox"
                  checked={draft.vehicles.includes(v.id)}
                  onChange={e =>
                    setDraft({
                      ...draft,
                      vehicles: e.target.checked
                        ? [...draft.vehicles, v.id]
                        : draft.vehicles.filter(id => id !== v.id)
                    })
                  }
                />
                {v.name} · {v.plate} ({v.status})
              </label>
            ))}
          </div>
        </details>
        <label className={styles.check}>
          <input
            type="checkbox"
            checked={draft.active}
            onChange={e => setDraft({ ...draft, active: e.target.checked })}
          />
          Active vehicles only
        </label>
        <button className={styles.primary} disabled={report.isFetching}>
          {report.isFetching ? "Updating…" : "Apply filters"}
        </button>
        {filtersChanged && (
          <span className={styles.pending} role="status">
            Filters not yet applied
          </span>
        )}
      </form>
      <div className={styles.reportBar}>
        <p>
          {r
            ? `${displayDate(r.period.from)} – ${displayDate(r.period.to)}`
            : "Preparing report"}
          <span>
            {settings.data.currency} / Kilometres / {settings.data.timezone}
          </span>
        </p>
        {admin && (
          <details className={styles.reportSettings}>
            <summary>Report settings</summary>
            <form
              onSubmit={e => {
                e.preventDefault();
                save.mutate();
              }}
            >
              <h2>Reporting preferences</h2>
              <p>
                Currency: {settings.data.currency}.{" "}
                <a href="/settings">Manage organization currency</a>
              </p>
              <label>
                Reporting timezone
                <input
                  value={timezone ?? settings.data.timezone}
                  onChange={e => {
                    setTimezone(e.target.value);
                    save.reset();
                  }}
                  required
                />
              </label>
              <button disabled={save.isPending}>
                {save.isPending ? "Saving…" : "Save timezone"}
              </button>
              {save.error && <p role="alert">{save.error.message}</p>}
              {save.isSuccess && <p role="status">Reporting timezone saved.</p>}
            </form>
          </details>
        )}
      </div>
      {report.isPending && (
        <p role="status" className={styles.empty}>
          Calculating fleet costs…
        </p>
      )}
      {report.error && (
        <p role="alert" className={styles.error}>
          {report.error.message}{" "}
          <button onClick={() => report.refetch()}>Try again</button>
        </p>
      )}
      {r && (
        <>
          {r.warnings
            .filter(w => w.includes("other currencies"))
            .map(w => (
              <p key={w} role="status">
                {w}
              </p>
            ))}
          {r.period.to === r.today && (
            <p className={styles.partial}>
              Current period includes an incomplete month.
            </p>
          )}

          <div className={styles.metrics}>
            <div>
              <span>Recorded operating costs</span>
              <strong>{money(r.total_cost)}</strong>
              <Change value={r.changes.total_cost} />
            </div>
            <div>
              <span>Recorded distance</span>
              <strong>
                {number(r.distance_km)}
                {r.distance_km == null ? "" : " km"}
              </strong>
              <small>
                {r.vehicles.filter(v => v.distance_km != null).length} of{" "}
                {r.vehicles.length} vehicles with measured distance
              </small>
            </div>
            <div>
              <span>Cost per km</span>
              <strong>{money(r.cost_per_km, 2)}</strong>
              <small>Costs within measured intervals</small>
              <Change value={r.changes.cost_per_km} />
            </div>
            <div>
              <span>Cost per day</span>
              <strong>{money(r.cost_per_day, 2)}</strong>
              <small>Elapsed calendar days, including idle days</small>
              <Change value={r.changes.cost_per_day} />
            </div>
          </div>
          {!r.vehicles.length && (
            <p className={styles.empty}>
              No vehicles match these filters. Select all vehicles or include
              archived and transferred vehicles.
            </p>
          )}
          <nav className={styles.reportNav} aria-label="Analytics reports">
            {[
              { value: "costs", label: "Cost overview" },
              { value: "efficiency", label: "Efficiency" },
              { value: "vehicles", label: "Vehicle comparison" },
              { value: "maintenance", label: "Maintenance" },
              { value: "expense", label: "Expenses" }
            ].map(item => (
              <button
                key={item.value}
                aria-current={view === item.value ? "page" : undefined}
                onClick={() => setView(item.value)}
              >
                {item.label}
              </button>
            ))}
          </nav>
          {view === "costs" && (
            <>
              <div className={styles.chartGrid}>
                <Section
                  title="Monthly operating costs"
                  note="Select a month to inspect its expenses."
                >
                  <div className={styles.columns}>
                    {r.months.map(m => (
                      <button
                        key={m.month}
                        className={styles.column}
                        onClick={() =>
                          openRecords(monthLabel(m.month), {
                            from: m.from,
                            to: m.to
                          })
                        }
                        aria-label={`${monthLabel(m.month)}: ${money(
                          m.total_cost
                        )}. View expenses.`}
                      >
                        <span className={styles.barValue}>
                          {number(m.total_cost, r.currency === "MMK" ? 0 : 2)}
                        </span>
                        <span className={styles.barTrack}>
                          <span
                            className={styles.stack}
                            style={{
                              height: `${(m.total_cost /
                                Math.max(
                                  ...r.months.map(x => x.total_cost),
                                  1
                                )) *
                                100}%`
                            }}
                          >
                            {Object.entries(m.categories).map(([c, n]) => (
                              <span
                                key={c}
                                style={{
                                  background: categoryColor(c),
                                  height: `${(n / Math.max(m.total_cost, 1)) *
                                    100}%`
                                }}
                                title={`${label(c)}: ${money(n)}`}
                              />
                            ))}
                          </span>
                        </span>
                        <span>{monthLabel(m.month)}</span>
                      </button>
                    ))}
                  </div>
                  <div className={styles.chartLegend}>
                    {categories.map(([category]) => (
                      <span key={category}>
                        <i style={{ background: categoryColor(category) }} />
                        {label(category)}
                      </span>
                    ))}
                  </div>
                  <p className={styles.caption}>
                    Actual recorded costs in {r.currency}. Pending submissions
                    are excluded.
                  </p>
                </Section>
                <Section
                  title="Costs by category"
                  note="Select a category to inspect its expenses."
                >
                  <Composition
                    slices={categories.map(([category, cost]) => ({
                      key: category,
                      label: label(category),
                      value: cost,
                      color: categoryColor(category)
                    }))}
                    centerLabel={`${r.currency} · Total cost`}
                    formatValue={value => number(value, digits)}
                    money={money}
                    onSelect={slice =>
                      openRecords(slice.label, { category: slice.key })
                    }
                    empty="No recorded expenses in this period. Approved expenses will appear here."
                  />
                </Section>
              </div>
            </>
          )}
          {view === "efficiency" && (
            <>
              <div className={styles.chartGrid}>
                <Section
                  title="Cost over time"
                  note="Missing distance is shown as a gap, never zero."
                >
                  <div className={styles.tabs}>
                    <button
                      aria-pressed={trend === "cost_per_km"}
                      onClick={() => setTrend("cost_per_km")}
                    >
                      Cost per km
                    </button>
                    <button
                      aria-pressed={trend === "cost_per_day"}
                      onClick={() => setTrend("cost_per_day")}
                    >
                      Cost per day
                    </button>
                  </div>
                  <Trend
                    color={
                      trend === "cost_per_day"
                        ? "var(--chart-insurance)"
                        : "var(--chart-maintenance)"
                    }
                    values={r.months.map(m => m[trend])}
                    labels={r.months.map(m => monthLabel(m.month))}
                    unit={`${r.currency}/${
                      trend === "cost_per_km" ? "km" : "day"
                    }`}
                  />
                </Section>
                <Section
                  title="Fuel and charging efficiency"
                  note="Weighted by measured distance. Fuel types stay separate."
                >
                  {r.efficiency.length ? (
                    r.efficiency.map(e => (
                      <div key={e.fuel}>
                        <div className={styles.efficiencyHeading}>
                          <strong>{label(e.fuel ?? "")}</strong>
                          <span>
                            {number(e.value, 2)} {e.unit}
                          </span>
                        </div>
                        <p className={styles.caption}>
                          {e.label}
                          {e.fuel === "electric"
                            ? " · Not battery consumption; charging losses and state of charge can affect this estimate."
                            : " · Partial fills are included between full tanks."}
                        </p>
                        <Trend
                          color={
                            e.fuel === "electric"
                              ? "var(--chart-parts)"
                              : "var(--chart-fuel)"
                          }
                          values={r.months.map(
                            m =>
                              m.efficiency.find(x => x.fuel === e.fuel)
                                ?.value ?? null
                          )}
                          labels={r.months.map(m => monthLabel(m.month))}
                          unit={e.unit ?? ""}
                        />
                      </div>
                    ))
                  ) : (
                    <p className={styles.empty}>
                      No complete efficiency intervals yet. Liquid fuel needs
                      two full tanks with odometer readings. EVs need two dated
                      charging readings. Unknown historical fills are excluded.
                    </p>
                  )}
                  <p className={styles.caption}>
                    Plug-in hybrids use combined energy cost per km in vehicle
                    details.
                  </p>
                </Section>
              </div>
            </>
          )}
          {view === "vehicles" && (
            <>
              <Section
                title="Vehicle comparison"
                note="Select a vehicle for its expenses. Unavailable values do not rank as zero."
              >
                <div className={styles.tableWrap}>
                  <table>
                    <thead>
                      <tr>
                        {[
                          ["name", "Vehicle"],
                          ["total_cost", "Operating costs"],
                          ["distance_km", "Recorded km"],
                          ["cost_per_km", "Cost / km"],
                          ["cost_per_day", "Cost / day"],
                          ["efficiency", "Efficiency"]
                        ].map(([key, title]) => (
                          <th
                            key={key}
                            aria-sort={
                              sort.key === key
                                ? sort.desc
                                  ? "descending"
                                  : "ascending"
                                : "none"
                            }
                          >
                            <button
                              onClick={() =>
                                setSort({
                                  key: key as typeof sort.key,
                                  desc: sort.key === key ? !sort.desc : false
                                })
                              }
                            >
                              {title}
                              {sort.key === key
                                ? sort.desc
                                  ? " ↓"
                                  : " ↑"
                                : ""}
                            </button>
                          </th>
                        ))}
                        <th>Coverage</th>
                      </tr>
                    </thead>
                    <tbody>
                      {sorted.map(v => (
                        <tr key={v.id}>
                          <td>
                            <button
                              className={styles.vehicleLink}
                              onClick={() =>
                                openRecords(v.name, { vehicles: v.id })
                              }
                            >
                              {v.name}
                            </button>
                            <small>
                              {v.plate} · {v.status}
                            </small>
                          </td>
                          <td>{money(v.total_cost)}</td>
                          <td>{number(v.distance_km)}</td>
                          <td>{money(v.cost_per_km, 2)}</td>
                          <td>{money(v.cost_per_day, 2)}</td>
                          <td>
                            {v.fuel === "hybrid_plugin" ? (
                              <>
                                <span>
                                  {money(v.energy_cost_per_km, 2)} / km
                                </span>
                                <small>
                                  Combined energy · Fuel {money(v.liquid_cost)}{" "}
                                  · Charging {money(v.electric_cost)}
                                  {v.unclassified_energy_cost > 0
                                    ? ` · Unclassified energy ${money(
                                        v.unclassified_energy_cost
                                      )}`
                                    : ""}
                                </small>
                              </>
                            ) : (
                              <>
                                {number(v.efficiency.value, 2)}
                                <small>
                                  {v.efficiency.value == null
                                    ? v.efficiency.label
                                    : `${v.efficiency.unit} · ${label(
                                        v.efficiency.group ?? ""
                                      )}`}
                                </small>
                              </>
                            )}
                          </td>
                          <td>
                            <span>{v.coverage ?? "Complete"}</span>
                            {v.measured_from && (
                              <small>
                                {v.measured_from} – {v.measured_to}
                              </small>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </Section>
            </>
          )}
          {view === "maintenance" && (
            <div className={styles.chartGrid}>
              <Section
                title="Monthly maintenance cost"
                note="Select a month to inspect its maintenance expenses."
              >
                <ScopedBars
                  months={r.months}
                  values={r.months.map(
                    month => month.categories.maintenance ?? 0
                  )}
                  color="var(--chart-maintenance)"
                  formatValue={value => number(value, digits)}
                  ariaLabel={(month, value) =>
                    `${monthLabel(
                      month
                    )}: ${money(value)}. View maintenance expenses.`
                  }
                  onSelect={month =>
                    openRecords(monthLabel(month.month), {
                      from: month.from,
                      to: month.to,
                      category: "maintenance"
                    })
                  }
                  empty="No maintenance costs in this period."
                />
                <p className={styles.caption}>
                  Service records and manually entered maintenance expenses.
                </p>
              </Section>
              <Section
                title="Cost by service type"
                note="Line items captured from service records. Unallocated covers manual costs and missing line items."
              >
                <Composition
                  slices={serviceSlices}
                  centerLabel={`${r.currency} · Maintenance`}
                  formatValue={value => number(value, digits)}
                  money={money}
                  empty="No maintenance costs in this period."
                />
              </Section>
            </div>
          )}
          {view === "expense" && (
            <div className={styles.chartGrid}>
              <Section
                title="Monthly expense cost"
                note="Select a month to inspect these expenses."
              >
                <ScopedBars
                  months={r.months}
                  values={expenseMonthValues}
                  color="var(--chart-insurance)"
                  formatValue={value => number(value, digits)}
                  ariaLabel={(month, value) =>
                    `${monthLabel(month)}: ${money(value)}. View expenses.`
                  }
                  onSelect={month =>
                    openRecords(monthLabel(month.month), {
                      from: month.from,
                      to: month.to,
                      categories: expenseCategoryList
                    })
                  }
                  empty="No other expenses in this period."
                />
                <p className={styles.caption}>
                  Excludes fuel and maintenance, which are reported in Cost
                  overview and Maintenance.
                </p>
              </Section>
              <Section
                title="Cost by category"
                note="Select a category to inspect its expenses."
              >
                <Composition
                  slices={expenseSlices}
                  centerLabel={`${r.currency} · Other expenses`}
                  formatValue={value => number(value, digits)}
                  money={money}
                  onSelect={slice =>
                    openRecords(slice.label, { category: slice.key })
                  }
                  empty="No other expenses in this period."
                />
              </Section>
            </div>
          )}
          <details className={styles.methods}>
            <summary>Calculation notes and data coverage</summary>
            <p>
              Operating costs include only expenses recorded in the fleet
              currency, counted once through the expense ledger. Other
              currencies remain visible in records and exports and are excluded
              from all totals and comparisons. No conversion is applied.
              Distance uses dated odometer readings inside the selected period.
              Cost per km includes only costs between those readings. Fleet
              rates are weighted by distance; vehicle cost per day uses
              organization ownership days. Monthly distance totals can differ
              from the whole period when readings do not land on month
              boundaries. Fuel efficiency is grouped by compatible fuel type.
            </p>
            <p>
              Comparison period: {r.previous_period.from} to{" "}
              {r.previous_period.to}. Changes are unavailable when the baseline
              is zero or coverage is insufficient.
            </p>
            {r.warnings.map(w => (
              <p key={w}>{w}</p>
            ))}
          </details>
        </>
      )}
      {drill && (
        <Records
          base={base}
          selection={drill}
          currency={settings.data.currency}
          onClose={() => setDrill(null)}
          onExport={() => download("expenses", drill.params)}
          downloading={downloading}
        />
      )}
    </div>
  );
}
function Records({
  base,
  selection,
  currency,
  onClose,
  onExport,
  downloading
}: {
  base: string;
  selection: { title: string; params: string };
  currency: string;
  onClose: () => void;
  onExport: () => void;
  downloading: boolean;
}) {
  const dialog = useRef<HTMLDialogElement>(null),
    [page, setPage] = useState(1),
    [detail, setDetail] = useState<AnalyticsExpense | null>(null);
  useEffect(() => {
    dialog.current?.showModal();
  }, []);
  const rows = useQuery({
    queryKey: ["analytics-records", base, selection.params, page],
    queryFn: () =>
      apiGet<{ total: number; items: AnalyticsExpense[] }>(
        `${base}/records?${selection.params}&page=${page}`
      )
  });
  return (
    <dialog
      ref={dialog}
      className={styles.dialog}
      aria-labelledby="expense-records-title"
      onCancel={onClose}
    >
      <header>
        <div>
          <h2 id="expense-records-title">{selection.title}</h2>
          <p>Original recorded amounts. Totals include {currency} only.</p>
        </div>
        <button onClick={onClose} aria-label="Close expense records">
          Close
        </button>
      </header>
      <button disabled={downloading} onClick={onExport}>
        Export these expenses CSV
      </button>
      {rows.isPending && <p role="status">Loading records…</p>}
      {rows.error && <p role="alert">{rows.error.message}</p>}
      {detail ? (
        <section className={styles.detail}>
          <button onClick={() => setDetail(null)}>Back to expenses</button>
          <h3>{detail.description}</h3>
          <dl>
            {Object.entries({
              Date: detail.date,
              Vehicle: detail.vehicle,
              Category: label(detail.category),
              Amount: `${number(detail.amount, 20)} ${detail.currency}`,
              "Entered by": detail.entered_by,
              "Record type": detail.source_kind
                ? label(detail.source_kind)
                : "Expense",
              ...(detail.detail
                ? Object.fromEntries(
                    Object.entries(detail.detail)
                      .filter(([k]) =>
                        [
                          "logged_on",
                          "serviced_on",
                          "odometer",
                          "fuel_type_name",
                          "amount",
                          "unit",
                          "fill_status",
                          "notes",
                          "cost"
                        ].includes(k)
                      )
                      .map(([k, v]) => [
                        k === "amount" ? "Quantity" : label(k),
                        k === "cost"
                          ? `${number(Number(v), 20)} ${detail.currency}`
                          : k === "amount"
                          ? `${number(Number(v), 2)} ${detail.detail?.unit ??
                              ""}`
                          : k === "odometer"
                          ? `${number(v == null ? null : Number(v))} ${detail
                              .detail?.odometer_unit ?? ""}`
                          : v
                      ])
                  )
                : {})
            }).map(([k, v]) => (
              <div key={k}>
                <dt>{k}</dt>
                <dd>{String(v ?? "Not recorded")}</dd>
              </div>
            ))}
          </dl>
        </section>
      ) : (
        <>
          <div className={styles.tableWrap}>
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Vehicle</th>
                  <th>Category / description</th>
                  <th>Amount</th>
                  <th>Entered by</th>
                  <th>Details</th>
                </tr>
              </thead>
              <tbody>
                {rows.data?.items.map(r => (
                  <tr key={r.id}>
                    <td>{r.date}</td>
                    <td>{r.vehicle}</td>
                    <td>
                      {label(r.category)}
                      <small>{r.description}</small>
                    </td>
                    <td>
                      {number(r.amount, 20)} {r.currency}
                      {!r.included_in_total && (
                        <small>Excluded from totals</small>
                      )}
                    </td>
                    <td>{r.entered_by}</td>
                    <td>
                      <button onClick={() => setDetail(r)}>View record</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {rows.data?.total === 0 && (
            <p className={styles.empty}>No expenses match this selection.</p>
          )}
          <footer>
            <button disabled={page === 1} onClick={() => setPage(page - 1)}>
              Previous
            </button>
            <span>
              Page {page} · {rows.data?.total ?? 0} records
            </span>
            <button
              disabled={!rows.data || page * 50 >= rows.data.total}
              onClick={() => setPage(page + 1)}
            >
              Next
            </button>
          </footer>
        </>
      )}
    </dialog>
  );
}
