import { NextRequest, NextResponse } from "next/server";
import { FLEET_REFRESH_COOKIE } from "@/lib/auth/cookies";

export function middleware(request: NextRequest) {
  const hasSession = Boolean(request.cookies.get(FLEET_REFRESH_COOKIE)?.value);
  const { pathname } = request.nextUrl;

  if (pathname === "/login") {
    if (hasSession) return NextResponse.redirect(new URL("/", request.url));
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
