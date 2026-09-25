import { NextRequest, NextResponse } from "next/server";
import { FLEET_REFRESH_COOKIE, clearSessionCookies } from "@/lib/auth/cookies";
import { upstream } from "@/lib/api/upstream";

export async function POST(request: NextRequest) {
  const refresh = request.cookies.get(FLEET_REFRESH_COOKIE)?.value;
  if (refresh) {
    await upstream("/auth/logout", {
      method: "POST",
      body: JSON.stringify({ refresh_token: refresh }),
    }).catch(() => undefined);
  }

  const out = new NextResponse(null, { status: 204 });
  clearSessionCookies(out);
  return out;
}
