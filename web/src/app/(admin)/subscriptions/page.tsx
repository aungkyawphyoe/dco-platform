import { Subscriptions } from '@/components/billing/subscriptions';
import { PageHeader } from '@dco/ui/components/page-header';
export default function SubscriptionsPage() { return <div className="space-y-6"><PageHeader title="Subscriptions" description="Manage direct sales, complimentary access, renewals, and organization migration."/><Subscriptions /></div>; }
