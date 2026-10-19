"use client";

import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { InstrumentBand } from "@/components/ui/instrument-band";
import { SectionHeading } from "@/components/ui/section-heading";
import { Stat } from "@/components/ui/stat";
import { useAdminDashboard } from "@/lib/api/hooks";

const activityKindConfig: Record<string, { color: string; label: string }> = {
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

function Kpi({ label, value }: { label: string; value?: number }) {
  return (
    <Stat
      label={label}
      value={
        value === undefined ? (
          <Skeleton className="h-5 w-14" />
        ) : (
          <span className="text-xl font-semibold">{value.toLocaleString()}</span>
        )
      }
    />
  );
}

export default function DashboardPage() {
  const { data, isLoading, error } = useAdminDashboard();

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Dashboard"
        description="Platform overview: users, vehicles, and recent activity"
      />

      {error ? (
        <Card className="p-6">
          <p className="text-sm text-danger">
            Failed to load dashboard. Please try again.
          </p>
        </Card>
      ) : (
        <>
          <InstrumentBand>
            <div className="grid grid-cols-2 gap-5 p-5 sm:grid-cols-4">
              <Kpi label="Users" value={data?.users_total} />
              <Kpi label="Active vehicles" value={data?.vehicles_active} />
              <Kpi label="Partners" value={data?.partners_total} />
              <Kpi label="Sync errors (24h)" value={data?.sync_errors_24h} />
            </div>
          </InstrumentBand>

          <Card>
            <SectionHeading title="Recent activity" count={data?.recent_activity?.length} />
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
                    activityKindConfig[item.kind ?? ""] ?? activityKindConfig.signup;
                  return (
                    <li key={i} className="flex items-center gap-3 px-5 py-3">
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
