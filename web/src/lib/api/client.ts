import { ApiError, parseApiError } from "./errors";
import { ensureFreshToken } from "@/lib/auth/token-store";

type Json = Record<string, unknown> | unknown[] | undefined;

async function request(path: string, init: RequestInit): Promise<Response> {
  const headers = new Headers(init.headers);
  if (typeof init.body === "string" && !headers.has("content-type")) {
    headers.set("content-type", "application/json");
  }
  headers.delete("authorization");
  return fetch(`/api/proxy${path}`, { ...init, headers, cache: "no-store" });
}

/** Shared by JSON requests, uploads and downloads. Retry authentication once. */
export async function apiRequest(path: string, init: RequestInit = {}): Promise<Response> {
  const sentToken = await ensureFreshToken();
  let res = await request(path, init);
  if (sentToken && res.status === 401 && !path.startsWith("/auth/")) {
    const refreshed = await ensureFreshToken(sentToken);
    if (refreshed) res = await request(path, init);
  }
  return res;
}

async function execute<T>(path: string, init: RequestInit): Promise<T> {
  const res = await apiRequest(path, init);
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
