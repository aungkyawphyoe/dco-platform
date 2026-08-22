"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { Sidebar } from "@/components/layout/sidebar";
import { useSession } from "@/lib/auth/session-context";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const { ready, user } = useSession();
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

  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <main className="min-w-0 flex-1 p-8">{children}</main>
    </div>
  );
}
