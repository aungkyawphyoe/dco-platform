"use client";

import { useRouter } from "next/navigation";
import { useSession } from "@/lib/auth/session-context";
import { Button } from "@/components/ui/button";

interface TopBarProps {
  user: { id: string; email: string; display_name: string | null; role: string; family_id: string | null };
}

export function TopBar({ user }: TopBarProps) {
  const router = useRouter();
  const { signOut } = useSession();

  async function onSignOut() {
    await signOut();
    router.replace("/login");
  }

  return (
    <header className="h-16 flex items-center justify-between px-6 border-b border-line-subtle bg-panel shrink-0">
      <div className="flex items-center gap-4">
        <span className="font-display text-lg font-semibold tracking-tight text-gold">
          DCO Family
        </span>
        {user.family_id && (
          <span className="text-xs text-ink-caption bg-card px-2 py-1 rounded">
            {user.family_id.slice(0, 8)}
          </span>
        )}
      </div>

      <div className="flex items-center gap-4">
        <Button variant="ghost" size="sm" onClick={onSignOut}>
          Sign out
        </Button>
        <div className="truncate text-sm text-ink" title={user.email}>
          {user.display_name || user.email}
        </div>
      </div>
    </header>
  );
}
