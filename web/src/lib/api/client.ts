import { apiBaseUrl } from "./config";
import { ApiError, parseApiError } from "./errors";
import { clearToken, ensureFreshToken, getToken } from "@/lib/auth/token-store";

type Json = Record<string, unknown> | unknown[] | undefined;

async function request<T>(path: string, init: RequestInit, token: string | null): Promise<Response> {
  const headers = new Headers(init.headers);
  if (init.body && !headers.has("content-type")) {
    headers.set("content-type", "application/json");
  }
  if (token) headers.set("authorization", `Bearer ${token}`);
  return fetch(`${apiBaseUrl()}${path}`, { ...init, headers });
}

async function execute<T>(path: string, init: RequestInit): Promise<T> {
  const first = await request(path, init, getToken());
  let res = first;
  if (res.status === 401 && !path.startsWith("/auth/")) {
    const refreshed = await ensureFreshToken();
    if (refreshed) res = await request(path, init, refreshed);
  }
  if (!res.ok) throw await parseApiError(res);
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export function apiGet<T>(path: string): Promise<T> {
  return execute<T>(path, { method: "GET" });
}

export function apiPost<T>(path: string, body?: Json): Promise<T> {
  return execute<T>(path, {
    method: "POST",
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

export function apiPatch<T>(path: string, body: Json): Promise<T> {
  return execute<T>(path, { method: "PATCH", body: JSON.stringify(body) });
}

export function apiDelete(path: string): Promise<void> {
  return execute<void>(path, { method: "DELETE" });
}

export { ApiError };
