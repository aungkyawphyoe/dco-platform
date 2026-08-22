"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import { useQueryClient } from "@tanstack/react-query";
import { clearToken, ensureFreshToken, setToken } from "@/lib/auth/token-store";

export type SessionUser = {
  id: string;
  email: string;
  display_name: string | null;
};

type SessionState = {
  user: SessionUser | null;
  ready: boolean;
  signIn: (input: { email: string; password: string }) => Promise<SessionUser>;
  signOut: () => Promise<void>;
};

const SessionContext = createContext<SessionState | null>(null);

export function SessionProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<SessionUser | null>(null);
  const [ready, setReady] = useState(false);
  const queryClient = useQueryClient();

  useEffect(() => {
    let active = true;
    (async () => {
      const token = await ensureFreshToken();
      if (!active) return;
      if (!token) {
        setUser(null);
        setReady(true);
        return;
      }
      try {
        const res = await fetch(
          `${process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8080/v1"}/me`,
          { headers: { authorization: `Bearer ${token}` } },
        );
        if (!res.ok) throw new Error("me failed");
        const me = (await res.json()) as SessionUser;
        if (!active) return;
        setUser({ id: me.id, email: me.email, display_name: me.display_name });
      } catch {
        clearToken();
        setUser(null);
      } finally {
        if (active) setReady(true);
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  const signIn = useCallback(
    async ({ email, password }: { email: string; password: string }) => {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const data = (await res.json().catch(() => ({}))) as {
        user?: SessionUser;
        access_token?: string;
        error?: { message?: string };
      };
      if (!res.ok || !data.user || !data.access_token) {
        throw new Error(data.error?.message ?? "Sign in failed");
      }
      setToken(data.access_token);
      setUser(data.user);
      queryClient.clear();
      return data.user;
    },
    [queryClient],
  );

  const signOut = useCallback(async () => {
    await fetch("/api/auth/logout", { method: "POST" }).catch(() => undefined);
    clearToken();
    setUser(null);
    queryClient.clear();
  }, [queryClient]);

  const value = useMemo(
    () => ({ user, ready, signIn, signOut }),
    [user, ready, signIn, signOut],
  );

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession(): SessionState {
  const ctx = useContext(SessionContext);
  if (!ctx) throw new Error("useSession must be used within SessionProvider");
  return ctx;
}
