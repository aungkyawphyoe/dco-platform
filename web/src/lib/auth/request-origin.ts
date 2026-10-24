import { NextRequest, NextResponse } from "next/server";

/** Cookie-authenticated mutations must originate in this portal. */
export function rejectCrossOrigin(request: NextRequest): NextResponse | null {
  if (["GET", "HEAD", "OPTIONS"].includes(request.method)) return null;
  if (request.headers.get("origin") !== request.nextUrl.origin || request.headers.get("sec-fetch-site") === "cross-site") {
    return NextResponse.json({ error: { code: "invalid_origin", message: "Request origin rejected" } }, { status: 403 });
  }
  return null;
}
