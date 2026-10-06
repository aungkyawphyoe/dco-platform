"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { useSession } from "@/lib/auth/session-context";
import { TopBar } from "@/components/layout/top-bar";

export default function OwnerLayout({ children }: { children: React.ReactNode }) {
  const { ready, user } = useSession();
  const router = useRouter();

  useEffect(() => {
    if (ready && (!user || user.role !== "owner")) {
      router.replace("/login");
    }
  }, [ready, user, router]);

  if (!ready || !user || user.role !== "owner") {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <p className="text-sm text-ink-caption">Loading…</p>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-col">
      <TopBar user={user} />
      <main className="min-w-0 flex-1 p-8">{children}</main>
    </div>
  );
}
