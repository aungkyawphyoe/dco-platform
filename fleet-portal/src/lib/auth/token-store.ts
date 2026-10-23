import { ApiError, parseApiError } from "@/lib/api/errors";

let token: string | null = null;
let inflight: Promise<string | null> | null = null;
let sessionVersion = 0;

export function getToken(): string | null {
  return token;
}

export function setToken(value: string): void {
  sessionVersion += 1;
  token = value;
  inflight = null;
}

export function clearToken(): void {
  sessionVersion += 1;
  token = null;
  inflight = null;
}

function isFresh(value: string): boolean {
  try {
    const payload = value.split(".")[1];
    const normalized = payload.replace(/-/g, "+").replace(/_/g, "/");
    const { exp } = JSON.parse(atob(normalized)) as { exp?: number };
    // Decode only to schedule refresh; the API still verifies the signature.
    return typeof exp === "number" && exp * 1000 > Date.now() + 30_000;
  } catch {
    return false;
  }
}

/**
 * Refresh on demand, with one rotation shared by concurrent requests.
 * A 401 supplies the rejected token: a newer token can be reused, but the
 * rejected one must never be returned from the cache even before its expiry.
 */
export async function ensureFreshToken(rejectedToken?: string | null): Promise<string | null> {
  if (inflight) return inflight;
  if (token && token !== rejectedToken && isFresh(token)) return token;
  const version = sessionVersion;
  const pending = (async () => {
    try {
      const res = await fetch("/api/auth/session", { method: "POST", cache: "no-store" });
      if (version !== sessionVersion) return null;
      if (res.status === 429 || res.status === 503) throw await parseApiError(res);
      const data = res.ok ? await res.json() as { access_token?: string } : null;
      // A refresh started by an old session must not undo sign-out/sign-in.
      if (version !== sessionVersion) return null;
      token = typeof data?.access_token === "string" ? data.access_token : null;
      return token;
    } catch (error) {
      if (error instanceof ApiError && (error.status === 429 || error.status === 503)) throw error;
      if (version === sessionVersion) token = null;
      return null;
    }
  })();
  inflight = pending;
  try {
    return await pending;
  } finally {
    if (inflight === pending) inflight = null;
  }
}
