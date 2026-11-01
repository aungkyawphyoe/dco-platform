import type { NextRequest } from "next/server";

/** Keep local ports intact; production uses the reverse proxy's public origin. */
export function getPublicOrigin(request: NextRequest): string {
  if (process.env.NODE_ENV !== "production") {
    return `${request.nextUrl.protocol}//${request.headers.get("host") || request.nextUrl.host}`;
  }

  const proto = request.headers.get("x-forwarded-proto") || "https";
  const host = request.headers.get("x-forwarded-host") || request.headers.get("host") || "";
  return `${proto}://${host.replace(/:3000$/, "")}`;
}
