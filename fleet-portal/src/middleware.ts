import { NextRequest, NextResponse } from "next/server";
import { FLEET_REFRESH_COOKIE } from "@/lib/auth/cookies";

function getPublicOrigin(request: NextRequest): string {
  const proto = request.headers.get("x-forwarded-proto") || "https";
  const host = request.headers.get("x-forwarded-host") || request.headers.get("host") || "";
  const cleanHost = host.replace(/:3000$/, "");
  return `${proto}://${cleanHost}`;
}

function normalizeRequestUrl(request: NextRequest): NextRequest {
  const publicOrigin = getPublicOrigin(request);
  const url = new URL(request.url);
  if (url.origin !== publicOrigin) {
    url.protocol = publicOrigin.startsWith("https") ? "https:" : "http:";
    url.host = publicOrigin.replace(/^https?:\/\//, "");
    return new NextRequest(url, request);
  }
  return request;
}

export function middleware(request: NextRequest) {
  request = normalizeRequestUrl(request);
  const publicOrigin = getPublicOrigin(request);
  const nonce = btoa(crypto.randomUUID());
  const development = process.env.NODE_ENV !== "production";
  const csp = `default-src 'self'; script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${development ? " 'unsafe-eval'" : ""}; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; font-src 'self'; connect-src 'self'${development ? " ws: wss:" : ""}; object-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none';${development ? "" : " upgrade-insecure-requests;"}`;
  const headers = new Headers(request.headers);
  headers.set("x-nonce", nonce);
  headers.set("content-security-policy", csp);
  const next = () => {
    const response = NextResponse.next({ request: { headers } });
    response.headers.set("Content-Security-Policy", csp);
    response.headers.set("Cache-Control", "private, no-store");
    return response;
  };
  const hasSession = Boolean(request.cookies.get(FLEET_REFRESH_COOKIE)?.value);
  const { pathname } = request.nextUrl;

  if (pathname === "/login") {
    if (hasSession) return NextResponse.redirect(new URL("/", publicOrigin));
    return next();
  }

  if (!hasSession) {
    return NextResponse.redirect(new URL("/login", publicOrigin));
  }
  return next();
}

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico|icon|.*\\..*).*)"],
};
