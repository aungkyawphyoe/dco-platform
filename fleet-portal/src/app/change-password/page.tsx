"use client";

import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Button } from "@dco/ui/components/button";
import { Input } from "@dco/ui/components/input";
import { useSession } from "@/lib/auth/session-context";

export default function ChangePasswordPage() {
  const router = useRouter();
  const { ready, user, passwordChangeRequired, changePassword, signOut } = useSession();
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

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

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (newPassword !== confirmPassword) {
      setError("New passwords do not match");
      return;
    }
    if (newPassword.length < 8) {
      setError("New password must be at least 8 characters");
      return;
    }
    setPending(true);
    try {
      await changePassword({ currentPassword, newPassword });
      router.replace("/");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Password change failed");
      setPending(false);
    }
  }

  async function onSignOut() {
    await signOut();
    router.replace("/login");
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <Image
            src="/autox-logo.png"
            alt=""
            width={96}
            height={96}
            className="mx-auto mb-4 size-24 rounded-lg bg-white"
            priority
          />
          <p className="font-display text-3xl font-semibold tracking-tight text-gold">
            AutoX Fleet
          </p>
          <p className="mt-2 text-sm text-ink-caption">
            You signed in with a temporary password. Set a new password to continue.
          </p>
        </div>

        <form
          onSubmit={onSubmit}
          className="flex flex-col gap-5 rounded-lg border border-line-subtle bg-card p-6"
        >
          <Input
            label="Current password"
            type="password"
            name="current-password"
            autoComplete="current-password"
            placeholder="••••••••"
            value={currentPassword}
            onChange={(e) => setCurrentPassword(e.target.value)}
            required
          />
          <Input
            label="New password"
            type="password"
            name="new-password"
            autoComplete="new-password"
            placeholder="••••••••"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            hint="At least 8 characters"
            required
          />
          <Input
            label="Confirm new password"
            type="password"
            name="confirm-new-password"
            autoComplete="new-password"
            placeholder="••••••••"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            required
          />

          {error ? (
            <p role="alert" className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">
              {error}
            </p>
          ) : null}

          <Button type="submit" disabled={pending}>
            {pending ? "Updating…" : "Set new password"}
          </Button>
          {passwordChangeRequired ? (
            <p className="text-center text-xs text-ink-caption">
              Fleet access is locked until your password is changed.
            </p>
          ) : null}
          <Button type="button" variant="ghost" size="sm" onClick={onSignOut}>
            Sign out
          </Button>
        </form>
      </div>
    </main>
  );
}
