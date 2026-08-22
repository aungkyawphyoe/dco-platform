"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useSession } from "@/lib/auth/session-context";

export default function LoginPage() {
  const router = useRouter();
  const { signIn } = useSession();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setPending(true);
    try {
      await signIn({ email: email.trim(), password });
      router.replace("/");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign in failed");
      setPending(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <p className="font-display text-3xl font-semibold tracking-tight text-gold">
            DCO Admin
          </p>
          <p className="mt-2 text-sm text-ink-caption">
            Digital Car Ownership platform — staff access only
          </p>
        </div>

        <form
          onSubmit={onSubmit}
          className="flex flex-col gap-5 rounded-lg border border-line-subtle bg-card p-6"
        >
          <Input
            label="Email"
            type="email"
            name="email"
            autoComplete="email"
            placeholder="admin@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
          <Input
            label="Password"
            type="password"
            name="password"
            autoComplete="current-password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />

          {error ? (
            <p role="alert" className="rounded-md bg-danger-dim px-3 py-2 text-sm text-danger">
              {error}
            </p>
          ) : null}

          <Button type="submit" disabled={pending}>
            {pending ? "Signing in…" : "Sign in"}
          </Button>
        </form>
      </div>
    </main>
  );
}
