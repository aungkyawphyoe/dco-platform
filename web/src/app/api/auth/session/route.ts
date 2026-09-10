import { NextRequest, NextResponse } from "next/server";
import {
  ADMIN_REFRESH_COOKIE,
  OWNER_REFRESH_COOKIE,
  clearSessionCookies,
  setAdminSessionCookies,
  setOwnerSessionCookies,
} from "@/lib/auth/cookies";
import { upstream, type UpstreamSession } from "@/lib/api/upstream";

export async function POST(request: NextRequest) {
  // Try admin refresh first
  const adminRefresh = request.cookies.get(ADMIN_REFRESH_COOKIE)?.value;
  if (adminRefresh) {
    const res = await upstream("/auth/refresh", {
      method: "POST",
      body: JSON.stringify({ refresh_token: adminRefresh }),
    });

    if (res.status === 200) {
      const session = (await res.json()) as UpstreamSession;
      if (session.user.role === "admin") {
        const out = NextResponse.json({
          user: session.user,
          access_token: session.access_token,
        });
        setAdminSessionCookies(out, session.access_token, session.refresh_token);
        return out;
      }
    }
  }

  // Try owner refresh
  const ownerRefresh = request.cookies.get(OWNER_REFRESH_COOKIE)?.value;
  if (ownerRefresh) {
    const res = await upstream("/auth/refresh", {
      method: "POST",
      body: JSON.stringify({ refresh_token: ownerRefresh }),
    });

    if (res.status === 200) {
      const session = (await res.json()) as UpstreamSession;
      if (session.user.role === "owner" && session.user.family_id) {
        const out = NextResponse.json({
          user: session.user,
          access_token: session.access_token,
        });
        setOwnerSessionCookies(out, session.access_token, session.refresh_token);
        return out;
      }
    }
  }

  const out = NextResponse.json(
    { error: { code: "unauthenticated", message: "Session expired" } },
    { status: 401 },
  );
  clearSessionCookies(out);
  return out;
}
