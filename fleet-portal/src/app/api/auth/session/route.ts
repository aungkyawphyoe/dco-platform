import { rejectCrossOrigin } from "@/lib/auth/request-origin";
import { authBackoffResponse } from "@/lib/auth/backoff-response";
import { NextRequest, NextResponse } from "next/server";
import {
  FLEET_REFRESH_COOKIE,
  clearSessionCookies,
  setFleetSessionCookies,
} from "@/lib/auth/cookies";
import { upstream, type UpstreamSession } from "@/lib/api/upstream";

export async function POST(request: NextRequest) {
  const rejected = rejectCrossOrigin(request);
  if (rejected) return rejected;
  const refresh = request.cookies.get(FLEET_REFRESH_COOKIE)?.value;
  if (refresh) {
    const res = await upstream("/auth/refresh", {
      method: "POST",
      body: JSON.stringify({ refresh_token: refresh }),
    });

    const backoff = authBackoffResponse(res);
    if (backoff) return backoff;

    if (res.status === 200) {
      const session = (await res.json()) as UpstreamSession;
      const out = NextResponse.json({
        user: session.user,
        authenticated: true,
      });
      setFleetSessionCookies(out, session.access_token, session.refresh_token);
      return out;
    }
  }

  const out = NextResponse.json(
    { error: { code: "unauthenticated", message: "Session expired" } },
    { status: 401 },
  );
  clearSessionCookies(out);
  return out;
}
