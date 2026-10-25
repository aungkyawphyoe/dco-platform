"use client";
import { useQuery } from '@tanstack/react-query';
import { apiGet } from '@/lib/api/client';
import { Card } from '@dco/ui/components/card';
export function SubscriptionNotice({ id }: {
    id: string;
}) {
    const q = useQuery({ queryKey: ['organization-subscription', id], queryFn: () => apiGet<{
            status: string;
            writable: boolean;
            term: {
                plan: string;
                source: string;
                endsAt: string;
                accessEndsAt: string;
            } | null;
        }>(`/organizations/${id}/subscription`), refetchInterval: 60000 });
    if (q.error)
        return <Card className="mb-6 p-4" role="alert">Subscription status unavailable. Refresh to retry.</Card>;
    if (!q.data)
        return null;
    const s = q.data;
    return <Card className="mb-6 p-4 space-y-2"><h2 className="font-display text-lg">Fleet subscription · {s.status.replaceAll('_', ' ')}</h2>{s.term && <p>{s.term.source === 'direct' ? 'Paid' : 'Complimentary'} access ends {new Date(s.term.endsAt).toLocaleString()}.{s.term.source === 'direct' ? ` Grace ends ${new Date(s.term.accessEndsAt).toLocaleString()}.` : ''}</p>}{!s.writable && <p>Read-only access. Existing records and permitted exports remain available. Contact AutoX administration to renew.</p>}{s.status === 'grace' && <p>Your payment term has ended. Renew before grace ends to continue operations.</p>}{s.status === 'awaiting_review' && <p>Your existing access continues while AutoX administration reviews your subscription.</p>}</Card>;
}
