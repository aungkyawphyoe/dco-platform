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
import { ApiError, apiGet, apiPost } from "@/lib/api/client";

import type { OrgContext } from "@/lib/api/types";

export type SessionUser = {
  id: string;
  email: string;
  display_name: string | null;
  role: string;
  family_id: string | null;
};

type SessionState = {
  user: SessionUser | null;
  org: OrgContext | null;
  ready: boolean;
  passwordChangeRequired: boolean;
  signIn: (input: { email: string; password: string }) => Promise<SessionUser>;
  signOut: () => Promise<void>;
  changePassword: (input: { currentPassword: string; newPassword: string }) => Promise<void>;
};

function isPasswordChangeRequired(err: unknown): boolean {
  return err instanceof ApiError && err.code === "password_change_required";
}

const SessionContext = createContext<SessionState | null>(null);

export function SessionProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<SessionUser | null>(null);
  const [org, setOrg] = useState<OrgContext | null>(null);
  const [ready, setReady] = useState(false);
  const [passwordChangeRequired, setPasswordChangeRequired] = useState(false);
  const queryClient = useQueryClient();

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const token = await ensureFreshToken();
        if (!active) return;
        if (!token) {
          setUser(null);
          setOrg(null);
          setReady(true);
          return;
        }
        const res = await fetch("/api/proxy/me", { cache: "no-store" });
        if (!res.ok) throw new Error("me failed");
        const me = (await res.json()) as SessionUser;
        if (!active) return;
        setUser({
          id: me.id,
          email: me.email,
          display_name: me.display_name,
          role: me.role,
          family_id: me.family_id ?? null,
        });
        try {
          const context = await apiGet<OrgContext>("/organizations/me");
          if (active) {
            setOrg(context);
            setPasswordChangeRequired(false);
          }
        } catch (err) {
          if (active) {
            setOrg(null);
            setPasswordChangeRequired(isPasswordChangeRequired(err));
          }
        }
      } catch (error) {
        if (!(error instanceof ApiError && (error.status === 429 || error.status === 503))) clearToken();
        setUser(null);
        setOrg(null);
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
        authenticated?: boolean;
        error?: { message?: string };
      };
      if (!res.ok || !data.user || !data.authenticated) {
        throw new Error(data.error?.message ?? "Sign in failed");
      }
      setToken(String(Date.now() + 10 * 60_000));
      setUser({
        id: data.user.id,
        email: data.user.email,
        display_name: data.user.display_name,
        role: data.user.role,
        family_id: data.user.family_id ?? null,
      });
      queryClient.clear();
      try {
        const context = await apiGet<OrgContext>("/organizations/me");
        setOrg(context);
        setPasswordChangeRequired(false);
      } catch (err) {
        setOrg(null);
        setPasswordChangeRequired(isPasswordChangeRequired(err));
      }
      return data.user;
    },
    [queryClient],
  );

  const signOut = useCallback(async () => {
    await fetch("/api/auth/logout", { method: "POST" }).catch(() => undefined);
    clearToken();
    setUser(null);
    setOrg(null);
    setPasswordChangeRequired(false);
    queryClient.clear();
  }, [queryClient]);

  const changePassword = useCallback(
    async ({ currentPassword, newPassword }: { currentPassword: string; newPassword: string }) => {
      await apiPost("/auth/change-password", {
        current_password: currentPassword,
        new_password: newPassword,
      });
      // The backend revokes all refresh tokens on password change, so re-sign-in
      // with the new password to establish a fresh session and cookies.
      if (user?.email) {
        await signIn({ email: user.email, password: newPassword });
      }
      setPasswordChangeRequired(false);
      queryClient.invalidateQueries();
    },
    [user, signIn, queryClient],
  );

  const value = useMemo(
    () => ({ user, org, ready, passwordChangeRequired, signIn, signOut, changePassword }),
    [user, org, ready, passwordChangeRequired, signIn, signOut, changePassword],
  );

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession(): SessionState {
  const ctx = useContext(SessionContext);
  if (!ctx) throw new Error("useSession must be used within SessionProvider");
  return ctx;
}

export function useOrgId(): string | null {
  return useSession().org?.organization?.id ?? null;
}

export function useOrgRole(): string | null {
  return useSession().org?.organization?.role ?? null;
}
