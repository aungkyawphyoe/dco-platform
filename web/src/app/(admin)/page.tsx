"use client";

import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { useAdminDashboard } from "@/lib/api/hooks";

const activityKindConfig: Record<
  string,
  { color: string; label: string }
> = {
  signup: { color: "bg-success", label: "Signup" },
  vehicle_added: { color: "bg-info", label: "Vehicle" },
  sync_error: { color: "bg-danger", label: "Sync error" },
  partner_status: { color: "bg-warning", label: "Partner" },
};

function relativeTime(iso?: string) {
  if (!iso) return "";
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

function KpiCard({ label, value }: { label: string; value?: number }) {
  return (
    <Card className="p-5">
      <p className="text-sm text-ink-caption">{label}</p>
      {value === undefined ? (
        <Skeleton className="mt-2 h-8 w-16" />
      ) : (
        <p className="mt-1 font-display text-3xl font-semibold text-ink">
          {value.toLocaleString()}
        </p>
      )}
    </Card>
  );
}

export default function DashboardPage() {
  const { data, isLoading, error } = useAdminDashboard();

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Dashboard"
        description="Platform overview — users, vehicles, and recent activity"
      />

      {error ? (
        <Card className="p-6">
          <p className="text-sm text-danger">
            Failed to load dashboard. Please try again.
          </p>
        </Card>
      ) : (
        <>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <KpiCard label="Users" value={data?.users_total} />
            <KpiCard label="Active vehicles" value={data?.vehicles_active} />
            <KpiCard label="Partners" value={data?.partners_total} />
            <KpiCard
              label="Sync errors (24h)"
              value={data?.sync_errors_24h}
            />
          </div>

          <Card>
            <div className="border-b border-line-subtle px-5 py-4">
              <h2 className="font-display text-base font-semibold text-ink">
                Recent activity
              </h2>
            </div>
            {isLoading ? (
              <div className="space-y-4 p-5">
                {Array.from({ length: 5 }).map((_, i) => (
                  <div key={i} className="flex items-center gap-3">
                    <Skeleton className="h-3 w-3 rounded-full" />
                    <Skeleton className="h-4 flex-1" />
                    <Skeleton className="h-4 w-16" />
                  </div>
                ))}
              </div>
            ) : !data?.recent_activity?.length ? (
              <p className="p-5 text-sm text-ink-caption">No recent activity.</p>
            ) : (
              <ul className="divide-y divide-line-subtle">
                {data.recent_activity.map((item, i) => {
                  const cfg =
                    activityKindConfig[item.kind ?? ""] ??
                    activityKindConfig.signup;
                  return (
                    <li
                      key={i}
                      className="flex items-center gap-3 px-5 py-3"
                    >
                      <span
                        className={`h-2.5 w-2.5 shrink-0 rounded-full ${cfg.color}`}
                      />
                      <span className="flex-1 text-sm text-ink">
                        {item.summary ?? cfg.label}
                      </span>
                      <span className="shrink-0 text-xs text-ink-caption">
                        {relativeTime(item.at)}
                      </span>
                    </li>
                  );
                })}
              </ul>
            )}
          </Card>
        </>
      )}
    </div>
  );
}
