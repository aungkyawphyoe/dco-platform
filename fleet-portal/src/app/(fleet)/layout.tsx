"use client";
import { CurrencySettings } from "@/components/currency/currency-settings";
import { SubscriptionNotice } from "@/components/billing/subscription-notice";

import { useRouter, usePathname } from "next/navigation";
import { useEffect } from "react";
import { Sidebar } from "@/components/layout/sidebar";
import { useSession, useOrgRole } from "@/lib/auth/session-context";
import { Card } from "@dco/ui/components/card";

export default function FleetLayout({ children }: { children: React.ReactNode }) {
  const { ready, user, org, passwordChangeRequired } = useSession();
  const role = useOrgRole();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (ready && !user) router.replace("/login");
  }, [ready, user, router]);

  useEffect(() => {
    if (ready && user && passwordChangeRequired) router.replace("/change-password");
  }, [ready, user, passwordChangeRequired, router]);

  if (!ready || !user) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <p className="text-sm text-ink-caption">Restoring session…</p>
      </div>
    );
  }

  if (passwordChangeRequired) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <p className="text-sm text-ink-caption">Redirecting to password change…</p>
      </div>
    );
  }

  if (ready && user && org && !org.fleet_access) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="max-w-md rounded-lg border border-line-subtle bg-card p-6 text-center">
          <p className="font-display text-lg font-semibold text-ink">
            Fleet access required
          </p>
          <p className="mt-2 text-sm text-ink-caption">
            Your account is not a member of an active Enterprise organization.
            Contact your organization administrator or AutoX support.
          </p>
        </div>
      </div>
    );
  }

  if (role === "org_driver") {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <Card className="max-w-md p-6 text-center">
          <p className="font-display text-lg font-semibold text-ink">
            Drivers do not use the Fleet Portal
          </p>
          <p className="mt-2 text-sm text-ink-caption">
            Please use the AutoX mobile app for your driver workflow.
          </p>
        </Card>
      </div>
    );
  }

  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar />
      <main className="min-w-0 flex-1 overflow-y-auto p-8">{org?.organization && <SubscriptionNotice id={org.organization.id} />}{pathname !== "/settings" && <CurrencySettings setupOnly />}{children}</main>
    </div>
  );
}
