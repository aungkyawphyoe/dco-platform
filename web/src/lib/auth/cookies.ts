import type { NextResponse } from "next/server";

export const ADMIN_ACCESS_COOKIE = "dco_admin_access";
export const ADMIN_REFRESH_COOKIE = "dco_admin_refresh";
export const OWNER_ACCESS_COOKIE = "dco_owner_access";
export const OWNER_REFRESH_COOKIE = "dco_owner_refresh";

const secure = process.env.NODE_ENV === "production";

const base = {
  httpOnly: true,
  sameSite: "lax",
  secure,
  path: "/",
} as const;

export const accessCookieOptions = { ...base, maxAge: 15 * 60 };
export const refreshCookieOptions = { ...base, maxAge: 60 * 60 * 24 * 30 };

export function setAdminSessionCookies(
  res: NextResponse,
  access: string,
  refresh: string,
): void {
  res.cookies.set(ADMIN_ACCESS_COOKIE, access, accessCookieOptions);
  res.cookies.set(ADMIN_REFRESH_COOKIE, refresh, refreshCookieOptions);
}

export function setOwnerSessionCookies(
  res: NextResponse,
  access: string,
  refresh: string,
): void {
  res.cookies.set(OWNER_ACCESS_COOKIE, access, accessCookieOptions);
  res.cookies.set(OWNER_REFRESH_COOKIE, refresh, refreshCookieOptions);
}

export function clearSessionCookies(res: NextResponse): void {
  res.cookies.delete(ADMIN_ACCESS_COOKIE);
  res.cookies.delete(ADMIN_REFRESH_COOKIE);
  res.cookies.delete(OWNER_ACCESS_COOKIE);
  res.cookies.delete(OWNER_REFRESH_COOKIE);
}

export function getAccessCookieName(isAdmin: boolean): string {
  return isAdmin ? ADMIN_ACCESS_COOKIE : OWNER_ACCESS_COOKIE;
}

export function getRefreshCookieName(isAdmin: boolean): string {
  return isAdmin ? ADMIN_REFRESH_COOKIE : OWNER_REFRESH_COOKIE;
}
