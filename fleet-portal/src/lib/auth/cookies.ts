import type { NextResponse } from "next/server";

export const FLEET_ACCESS_COOKIE = "dco_fleet_access";
export const FLEET_REFRESH_COOKIE = "dco_fleet_refresh";

const secure = process.env.NODE_ENV === "production";

const base = {
  httpOnly: true,
  sameSite: "lax",
  secure,
  path: "/",
} as const;

export const accessCookieOptions = { ...base, maxAge: 15 * 60 };
export const refreshCookieOptions = { ...base, maxAge: 60 * 60 * 24 * 30 };

export function setFleetSessionCookies(
  res: NextResponse,
  access: string,
  refresh: string,
): void {
  res.cookies.set(FLEET_ACCESS_COOKIE, access, accessCookieOptions);
  res.cookies.set(FLEET_REFRESH_COOKIE, refresh, refreshCookieOptions);
}

export function clearSessionCookies(res: NextResponse): void {
  res.cookies.delete(FLEET_ACCESS_COOKIE);
  res.cookies.delete(FLEET_REFRESH_COOKIE);
}
