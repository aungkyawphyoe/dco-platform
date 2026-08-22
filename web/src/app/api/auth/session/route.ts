import { NextRequest, NextResponse } from "next/server";
import {
  REFRESH_COOKIE,
  clearSessionCookies,
  setSessionCookies,
} from "@/lib/auth/cookies";
import { upstream, type UpstreamSession } from "@/lib/api/upstream";

export async function POST(request: NextRequest) {
  const refresh = request.cookies.get(REFRESH_COOKIE)?.value;
  if (!refresh) {
    return NextResponse.json(
      { error: { code: "unauthenticated", message: "No session" } },
      { status: 401 },
    );
  }

  const res = await upstream("/auth/refresh", {
    method: "POST",
    body: JSON.stringify({ refresh_token: refresh }),
  });

  if (res.status !== 200) {
    const out = NextResponse.json(
      { error: { code: "unauthenticated", message: "Session expired" } },
      { status: 401 },
    );
    clearSessionCookies(out);
    return out;
  }

  const session = (await res.json()) as UpstreamSession;
  if (session.user.role !== "admin") {
    const out = NextResponse.json(
      { error: { code: "forbidden", message: "Admin role required" } },
      { status: 403 },
    );
    clearSessionCookies(out);
    return out;
  }

  const out = NextResponse.json({
    user: session.user,
    access_token: session.access_token,
  });
  setSessionCookies(out, session.access_token, session.refresh_token);
  return out;
}
