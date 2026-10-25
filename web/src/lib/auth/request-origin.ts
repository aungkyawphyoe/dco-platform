import { NextRequest, NextResponse } from "next/server";

function getPublicOrigin(request: NextRequest): string {
  const proto = request.headers.get("x-forwarded-proto") || "https";
  const host = request.headers.get("x-forwarded-host") || request.headers.get("host") || "";
  const cleanHost = host.replace(/:3000$/, "");
  return `${proto}://${cleanHost}`;
}

/** Cookie-authenticated mutations must originate in this portal. */
export function rejectCrossOrigin(request: NextRequest): NextResponse | null {
  if (["GET", "HEAD", "OPTIONS"].includes(request.method)) return null;
  const publicOrigin = getPublicOrigin(request);
  if (request.headers.get("origin") !== publicOrigin || request.headers.get("sec-fetch-site") === "cross-site") {
    return NextResponse.json({ error: { code: "invalid_origin", message: "Request origin rejected" } }, { status: 403 });
  }
  return null;
}
