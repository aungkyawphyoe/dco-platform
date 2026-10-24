import { NextResponse } from "next/server";

/** Preserve a session on transient upstream throttling/store failure. */
export function authBackoffResponse(response: Response): NextResponse | null {
  if (response.status !== 429 && response.status !== 503) return null;
  const seconds = Number(response.headers.get("retry-after"));
  const retryAfter = Number.isSafeInteger(seconds) && seconds > 0 ? Math.min(seconds, 3600) : 30;
  return NextResponse.json({ error: {
    code: response.status === 429 ? "rate_limited" : "service_unavailable",
    message: response.status === 429 ? "Too many attempts. Please try again later." : "Authentication service temporarily unavailable. Please try again shortly.",
    details: { retry_after: retryAfter },
  } }, { status: response.status, headers: { "Retry-After": String(retryAfter), "Cache-Control": "no-store" } });
}
