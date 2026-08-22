import { PageHeader } from "@/components/ui/page-header";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";

export default function PartnersPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Partners"
        description="Workshops and insurers onboarding records"
      />
      <Card>
        <EmptyState
          title="Partner table lands in Phase 3"
          description="GET /v1/admin/partners with search and status filter; create button opens A6."
        />
      </Card>
    </div>
  );
}
