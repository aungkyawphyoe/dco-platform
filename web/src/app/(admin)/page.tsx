import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";

export default function DashboardPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Dashboard"
        description="Platform overview — users, vehicles, and recent activity"
      />
      <Card>
        <EmptyState
          title="KPI cards land in Phase 3"
          description="users_total, vehicles_active, partners_total, sync_errors_24h and recent activity will be fetched from GET /v1/admin/dashboard."
        />
      </Card>
    </div>
  );
}
