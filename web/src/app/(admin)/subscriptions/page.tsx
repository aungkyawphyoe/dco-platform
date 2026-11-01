import { Subscriptions } from "@/components/billing/subscriptions";
import { PageHeader } from "@dco/ui/components/page-header";
export default function SubscriptionsPage() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Subscriptions"
        description="Review subscription history by source and manage account access."
      />
      <Subscriptions />
    </div>
  );
}
