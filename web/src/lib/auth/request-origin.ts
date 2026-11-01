import { NextRequest, NextResponse } from "next/server";
import { getPublicOrigin } from "./public-origin";

/** Cookie-authenticated mutations must originate in this portal. */
export function rejectCrossOrigin(request: NextRequest): NextResponse | null {
  if (["GET", "HEAD", "OPTIONS"].includes(request.method)) return null;
  const publicOrigin = getPublicOrigin(request);
  if (request.headers.get("origin") !== publicOrigin || request.headers.get("sec-fetch-site") === "cross-site") {
    return NextResponse.json({ error: { code: "invalid_origin", message: "Request origin rejected" } }, { status: 403 });
  }
  return null;
}
