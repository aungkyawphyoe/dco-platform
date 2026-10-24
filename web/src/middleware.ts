import { NextRequest, NextResponse } from "next/server";
import { ADMIN_REFRESH_COOKIE, OWNER_REFRESH_COOKIE } from "@/lib/auth/cookies";

export function middleware(request: NextRequest) {
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
  const hasAdminSession = Boolean(request.cookies.get(ADMIN_REFRESH_COOKIE)?.value);
  const hasOwnerSession = Boolean(request.cookies.get(OWNER_REFRESH_COOKIE)?.value);
  const hasSession = hasAdminSession || hasOwnerSession;
  const { pathname } = request.nextUrl;

  if (pathname === "/login") {
    if (hasSession) {
      if (hasAdminSession) return NextResponse.redirect(new URL("/", request.url));
      if (hasOwnerSession) return NextResponse.redirect(new URL("/vehicles", request.url));
    }
    return next();
  }

  // Admin routes
  if (
    pathname === "/" ||
    pathname.startsWith("/users") ||
    pathname.startsWith("/partners") ||
    pathname.startsWith("/organizations")
  ) {
    if (!hasAdminSession) {
      return NextResponse.redirect(new URL("/login", request.url));
    }
    return next();
  }

  // Owner routes (vehicle sharing)
  if (pathname.startsWith("/vehicles") || pathname.startsWith("/family")) {
    if (!hasOwnerSession) {
      return NextResponse.redirect(new URL("/login", request.url));
    }
    if (pathname.startsWith("/family")) {
      return NextResponse.redirect(new URL("/vehicles", request.url));
    }
    return next();
  }

  if (!hasSession) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  return next();
}

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico|icon|.*\\..*).*)"],
};
