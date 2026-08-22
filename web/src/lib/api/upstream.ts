import { apiBaseUrl } from "@/lib/api/config";

export async function upstream(
  path: string,
  init: RequestInit,
): Promise<Response> {
  const headers = new Headers(init.headers);
  if (init.body && !headers.has("content-type")) {
    headers.set("content-type", "application/json");
  }
  return fetch(`${apiBaseUrl()}${path}`, { ...init, headers, cache: "no-store" });
}

export type SessionUser = {
  id: string;
  email: string;
  display_name: string | null;
  role: "owner" | "admin";
  plan: "free" | "premium";
};

export type UpstreamSession = {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  user: SessionUser;
};
