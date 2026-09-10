import { NextRequest, NextResponse } from "next/server";
import { ADMIN_REFRESH_COOKIE, OWNER_REFRESH_COOKIE, clearSessionCookies } from "@/lib/auth/cookies";
import { upstream } from "@/lib/api/upstream";

export async function POST(request: NextRequest) {
  const adminRefresh = request.cookies.get(ADMIN_REFRESH_COOKIE)?.value;
  if (adminRefresh) {
    await upstream("/auth/logout", {
      method: "POST",
      body: JSON.stringify({ refresh_token: adminRefresh }),
    }).catch(() => undefined);
  }

  const ownerRefresh = request.cookies.get(OWNER_REFRESH_COOKIE)?.value;
  if (ownerRefresh) {
    await upstream("/auth/logout", {
      method: "POST",
      body: JSON.stringify({ refresh_token: ownerRefresh }),
    }).catch(() => undefined);
  }

  const out = new NextResponse(null, { status: 204 });
  clearSessionCookies(out);
  return out;
}
