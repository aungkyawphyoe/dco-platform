import { NextRequest, NextResponse } from "next/server";
import { ADMIN_REFRESH_COOKIE, OWNER_REFRESH_COOKIE } from "@/lib/auth/cookies";

export function middleware(request: NextRequest) {
  const hasAdminSession = Boolean(request.cookies.get(ADMIN_REFRESH_COOKIE)?.value);
  const hasOwnerSession = Boolean(request.cookies.get(OWNER_REFRESH_COOKIE)?.value);
  const hasSession = hasAdminSession || hasOwnerSession;
  const { pathname } = request.nextUrl;

  if (pathname === "/login") {
    if (hasSession) {
      if (hasAdminSession) return NextResponse.redirect(new URL("/", request.url));
      if (hasOwnerSession) return NextResponse.redirect(new URL("/family", request.url));
    }
    return NextResponse.next();
  }

  // Admin routes
  if (pathname === "/" || pathname.startsWith("/users") || pathname.startsWith("/partners")) {
    if (!hasAdminSession) {
      return NextResponse.redirect(new URL("/login", request.url));
    }
    return NextResponse.next();
  }

  // Family routes (Primary Owner only)
  if (pathname.startsWith("/family")) {
    if (!hasOwnerSession) {
      return NextResponse.redirect(new URL("/login", request.url));
    }
    return NextResponse.next();
  }

  if (!hasSession) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico|icon|.*\\..*).*)"],
};
