import { importPKCS8, SignJWT } from "jose";
import type { Env } from "../config/env.js";
import { AppError } from "./errors.js";
import { PLANS, type Plan } from "./plans.js";

/**
 * Offline entitlement license issuance (`architecture/feature-gating.md` §5).
 *
 * EdDSA (Ed25519) compact JWT, `kid` in the header for client keyring
 * selection. Claims are fully self-contained: the server only signs, the
 * client trusts claims when the signature verifies (decision 10). The
 * private key never leaves the server (Key Vault / env); the matching
 * public key ships as a mobile asset (`assets/license_keys.json`).
 *
 * Expiry: `period_end` + 7d grace once billing exists; until then a rolling
 * `LICENSE_TTL_DAYS` window keeps licenses fresh (§5.1). Free tier licenses
 * are issued too — an expired/garbage license degrades to Free, never a
 * lockout (decision 11).
 */

export const LICENSE_ISSUER = "dco";
export const LICENSE_GRACE_DAYS = 7;

export function pemFromBase64Url(raw: string): string {
  const der = Buffer.from(raw, "base64url");
  const b64 = der.toString("base64").match(/.{1,64}/g)?.join("\n") ?? "";
  return `-----BEGIN PRIVATE KEY-----\n${b64}\n-----END PRIVATE KEY-----`;
}

let cachedKey: { raw: string; key: CryptoKey } | null = null;

async function licenseSigningKey(raw: string): Promise<CryptoKey> {
  if (cachedKey && cachedKey.raw === raw) return cachedKey.key;
  const key = await importPKCS8(pemFromBase64Url(raw), "EdDSA");
  cachedKey = { raw, key };
  return key;
}

export type LicenseIssueInput = {
  userId: string;
  plan: Plan;
  now?: Date;
  /** Billing period end; null until the subscriptions table lands. */
  periodEnd?: Date | null;
};

export type IssuedLicense = {
  license: string;
  expiresAt: Date;
};

export async function issueLicense(env: Env, input: LicenseIssueInput): Promise<IssuedLicense> {
  if (!env.LICENSE_ED25519_KEY) {
    throw new AppError(503, "license_unavailable", "License signing is not configured");
  }
  const plan = PLANS[input.plan];
  const now = input.now ?? new Date();
  const periodEnd = input.periodEnd ?? null;
  const expiresAt = periodEnd
    ? new Date(periodEnd.getTime() + LICENSE_GRACE_DAYS * 86_400_000)
    : new Date(now.getTime() + env.LICENSE_TTL_DAYS * 86_400_000);

  const license = await new SignJWT({
    plan_id: plan.id,
    vehicle_limit: plan.vehicleLimit,
    sharing_limit: plan.sharingLimit,
    storage_bytes: plan.storageBytes,
    ai_tier: plan.aiTier,
    features: { ...plan.features },
    period_end: periodEnd ? periodEnd.toISOString() : null,
  })
    .setProtectedHeader({ alg: "EdDSA", kid: env.LICENSE_KID })
    .setSubject(input.userId)
    .setIssuer(LICENSE_ISSUER)
    .setIssuedAt(now)
    .setExpirationTime(expiresAt)
    .sign(await licenseSigningKey(env.LICENSE_ED25519_KEY));

  return { license, expiresAt };
}
