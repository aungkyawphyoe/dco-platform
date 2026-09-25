"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { Sidebar } from "@/components/layout/sidebar";
import { useSession } from "@/lib/auth/session-context";

export default function FleetLayout({ children }: { children: React.ReactNode }) {
  const { ready, user, org } = useSession();
  const router = useRouter();

  useEffect(() => {
    if (ready && !user) router.replace("/login");
  }, [ready, user, router]);

  if (!ready || !user) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <p className="text-sm text-ink-caption">Restoring session…</p>
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
            Contact your organization administrator or DCO support.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <main className="min-w-0 flex-1 p-8">{children}</main>
    </div>
  );
}
