import type { NextResponse } from "next/server";

export const ACCESS_COOKIE = "dco_admin_access";
export const REFRESH_COOKIE = "dco_admin_refresh";

const secure = process.env.NODE_ENV === "production";

const base = {
  httpOnly: true,
  sameSite: "lax",
  secure,
  path: "/",
} as const;

export const accessCookieOptions = { ...base, maxAge: 15 * 60 };
export const refreshCookieOptions = { ...base, maxAge: 60 * 60 * 24 * 30 };

export function setSessionCookies(
  res: NextResponse,
  access: string,
  refresh: string,
): void {
  res.cookies.set(ACCESS_COOKIE, access, accessCookieOptions);
  res.cookies.set(REFRESH_COOKIE, refresh, refreshCookieOptions);
}

export function clearSessionCookies(res: NextResponse): void {
  res.cookies.delete(ACCESS_COOKIE);
  res.cookies.delete(REFRESH_COOKIE);
}
