import { createHash, randomBytes, randomUUID } from "node:crypto";
import bcrypt from "bcryptjs";
import { SignJWT, jwtVerify, type JWTPayload } from "jose";
import type { Env } from "../config/env.js";

const ACCESS_TYP = "access";
const REFRESH_TYP = "refresh";

export type Role = "owner" | "admin";
export type Plan = "free" | "premium";

export type AccessClaims = {
  sub: string;
  aud: string;
  role: Role;
  plan: Plan;
  typ: typeof ACCESS_TYP;
};

export function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 10);
}

export function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

export function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export function newId(): string {
  return randomUUID();
}

export function randomToken(): string {
  return randomBytes(32).toString("base64url");
}

function ttlToSeconds(ttl: string): number {
  const match = /^(\d+)([smhd])$/.exec(ttl);
  if (!match) return 900;
  const n = Number(match[1]);
  const unit = match[2];
  if (unit === "s") return n;
  if (unit === "m") return n * 60;
  if (unit === "h") return n * 3600;
  return n * 86400;
}

export async function signAccess(env: Env, input: Omit<AccessClaims, "typ" | "aud"> & { aud?: string }) {
  const aud = input.aud ?? (input.role === "admin" ? env.JWT_ADMIN_AUD : env.JWT_OWNER_AUD);
  const secret = new TextEncoder().encode(env.JWT_ACCESS_SECRET);
  const expiresIn = ttlToSeconds(env.JWT_ACCESS_TTL);
  const token = await new SignJWT({ role: input.role, plan: input.plan, typ: ACCESS_TYP })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(input.sub)
    .setAudience(aud)
    .setIssuedAt()
    .setExpirationTime(`${expiresIn}s`)
    .sign(secret);
  return { token, expiresIn, aud };
}

export async function signRefresh(env: Env, userId: string, familyId: string, jti: string) {
  const secret = new TextEncoder().encode(env.JWT_REFRESH_SECRET);
  const expiresIn = ttlToSeconds(env.JWT_REFRESH_TTL);
  const token = await new SignJWT({ typ: REFRESH_TYP, family: familyId })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setJti(jti)
    .setIssuedAt()
    .setExpirationTime(`${expiresIn}s`)
    .sign(secret);
  return { token, expiresIn, expiresAt: new Date(Date.now() + expiresIn * 1000) };
}

export async function verifyAccess(env: Env, token: string): Promise<AccessClaims & JWTPayload> {
  const secret = new TextEncoder().encode(env.JWT_ACCESS_SECRET);
  const { payload } = await jwtVerify(token, secret, {
    audience: [env.JWT_OWNER_AUD, env.JWT_ADMIN_AUD],
  });
  if (payload.typ !== ACCESS_TYP || !payload.sub || !payload.aud) {
    throw new Error("invalid_access");
  }
  return payload as AccessClaims & JWTPayload;
}

export async function verifyRefresh(env: Env, token: string) {
  const secret = new TextEncoder().encode(env.JWT_REFRESH_SECRET);
  const { payload } = await jwtVerify(token, secret);
  if (payload.typ !== REFRESH_TYP || !payload.sub || !payload.jti || typeof payload.family !== "string") {
    throw new Error("invalid_refresh");
  }
  return payload as JWTPayload & { family: string; jti: string; sub: string };
}
