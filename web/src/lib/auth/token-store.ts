let token: string | null = null;
let inflight: Promise<string | null> | null = null;

export function getToken(): string | null {
  return token;
}

export function setToken(value: string): void {
  token = value;
}

export function clearToken(): void {
  token = null;
}

/**
 * Exchange the httpOnly refresh cookie for a fresh access token via the BFF.
 * Single-flight so concurrent callers share one rotation.
 */
export async function ensureFreshToken(): Promise<string | null> {
  if (token) return token;
  if (!inflight) {
    inflight = (async () => {
      try {
        const res = await fetch("/api/auth/session", { method: "POST" });
        if (!res.ok) {
          token = null;
          return null;
        }
        const data = (await res.json()) as { access_token?: string };
        token = data.access_token ?? null;
        return token;
      } catch {
        token = null;
        return null;
      } finally {
        inflight = null;
      }
    })();
  }
  return inflight;
}
