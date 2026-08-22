import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";

export default function UsersPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Users" description="Search, view, and support owner accounts" />
      <Card>
        <EmptyState
          title="User table lands in Phase 3"
          description="GET /v1/admin/users with search (q) and status filter; row click opens the profile."
        />
      </Card>
    </div>
  );
}
