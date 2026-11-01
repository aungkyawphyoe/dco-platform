"use client";
import { useQuery } from "@tanstack/react-query";
import { apiGet } from "@/lib/api/client";
import { Card } from "@dco/ui/components/card";
import { Button } from "@dco/ui/components/button";

export function SubscriptionNotice({ id }: { id: string }) {
  const query = useQuery({
    queryKey: ["organization-subscription", id],
    queryFn: () =>
      apiGet<{
        status: string;
        writable: boolean;
        term: {
          plan: string;
          source: string;
          endsAt: string;
          accessEndsAt: string;
        } | null;
      }>(`/organizations/${id}/subscription`),
    refetchInterval: 60000
  });
  if (query.error)
    return (
      <Card
        className="mb-5 flex flex-wrap items-center justify-between gap-3 p-4"
        role="alert"
      >
        <p>Subscription status unavailable.</p>
        <Button variant="secondary" size="sm" onClick={() => query.refetch()}>
          Try again
        </Button>
      </Card>
    );
  if (!query.data) return null;
  const subscription = query.data;
  const active = subscription.status === "active" && subscription.writable;
  const date = (value: string) =>
    new Date(value).toLocaleDateString(undefined, {
      day: "numeric",
      month: "short",
      year: "numeric"
    });
  return (
    <div
      className={`mb-5 flex flex-wrap items-center justify-between gap-x-6 gap-y-2 rounded-md px-4 py-3 text-sm ${
        active ? "border border-line text-ink-muted" : "bg-warning-dim text-ink"
      }`}
    >
      <p className="flex flex-wrap items-center gap-2">
        <span
          className={`h-2 w-2 rounded-full ${
            active ? "bg-success" : "bg-warning"
          }`}
          aria-hidden="true"
        />
        <span className="font-medium text-ink">Fleet subscription</span>
        <span>
          {subscription.writable
            ? subscription.status.replaceAll("_", " ")
            : "read-only"}
        </span>
      </p>
      {subscription.term && (
        <p>
          {subscription.term.source === "direct" ? "Paid" : "Complimentary"}{" "}
          access until {date(subscription.term.endsAt)}
          {subscription.status === "grace"
            ? `; grace ends ${date(subscription.term.accessEndsAt)}`
            : ""}
        </p>
      )}
      {!subscription.writable && (
        <p className="w-full">
          Existing records and permitted exports remain available. Contact AutoX
          administration to renew.
        </p>
      )}
      {subscription.status === "grace" && subscription.writable && (
        <p className="w-full">
          Renew before grace ends to continue operations.
        </p>
      )}
      {subscription.status === "awaiting_review" && subscription.writable && (
        <p className="w-full">
          Contact AutoX administration to record this organization’s
          subscription.
        </p>
      )}
    </div>
  );
}
