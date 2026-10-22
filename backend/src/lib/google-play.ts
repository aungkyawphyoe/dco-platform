import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "jose";
import type { Env } from "../config/env.js";
import { AppError } from "./errors.js";
import { sha256 } from "./crypto.js";

export const PLAY_PRODUCTS = { autox_lite: "lite", autox_standard: "standard" } as const;
export const PLAY_BASE_PLANS = ["monthly", "annual"] as const;
export const playAccountId = (userId: string) => sha256(`autox-play:${userId}`);
export type PlayPurchase = {
  subscriptionState: string;
  acknowledgementState?: string;
  externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string };
  linkedPurchaseToken?: string;
  lineItems?: { productId: string; expiryTime?: string; offerDetails?: { basePlanId: string; offerId?: string }; autoRenewingPlan?: { autoRenewEnabled?: boolean } }[];
};
export interface PlayGateway {
  get(token: string): Promise<PlayPurchase>;
  acknowledge(productId: string, token: string): Promise<void>;
}
export function playConfigured(env: Env) {
  return !!env.PLAY_SERVICE_ACCOUNT_JSON && !!env.LICENSE_ED25519_KEY && !!env.PLAY_RTDN_AUDIENCE && !!env.PLAY_RTDN_SERVICE_ACCOUNT;
}
export function playEnabled(env: Env) {
  return env.PLAY_BILLING_ENABLED === "on" && playConfigured(env);
}
export function verifiedPlayLine(purchase: PlayPurchase, accountId: string, now = new Date()) {
  if (purchase.externalAccountIdentifiers?.obfuscatedExternalAccountId !== accountId) {
    throw new AppError(409, "purchase_account_mismatch", "Use the AutoX account that made this purchase");
  }
  if (purchase.lineItems?.length !== 1) throw new AppError(422, "unsupported_purchase", "Unsupported subscription");
  const line = purchase.lineItems[0];
  const plan = PLAY_PRODUCTS[line.productId as keyof typeof PLAY_PRODUCTS];
  if (!plan || !PLAY_BASE_PLANS.includes(line.offerDetails?.basePlanId as typeof PLAY_BASE_PLANS[number])) {
    throw new AppError(422, "unsupported_purchase", "Unsupported subscription");
  }
  const expiresAt = new Date(line.expiryTime ?? 0);
  if (!Number.isFinite(expiresAt.getTime())) throw new AppError(422, "invalid_purchase", "Invalid subscription expiry");
  const entitled = ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "SUBSCRIPTION_STATE_CANCELED"].includes(purchase.subscriptionState) && expiresAt > now;
  return { line, plan, expiresAt, entitled };
}

export class GooglePlayGateway implements PlayGateway {
  private access?: { token: string; until: number };
  constructor(private env: Env) {}
  private async accessToken() {
    if (this.access && this.access.until > Date.now()) return this.access.token;
    try {
      const credentials = JSON.parse(this.env.PLAY_SERVICE_ACCOUNT_JSON ?? "{}");
      const key = await importPKCS8(credentials.private_key, "RS256");
      const assertion = await new SignJWT({ scope: "https://www.googleapis.com/auth/androidpublisher" })
        .setProtectedHeader({ alg: "RS256" }).setIssuer(credentials.client_email)
        .setAudience("https://oauth2.googleapis.com/token").setIssuedAt().setExpirationTime("5m").sign(key);
      const response = await fetch("https://oauth2.googleapis.com/token", { method: "POST",
        body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }), signal: AbortSignal.timeout(15000) });
      if (!response.ok) throw new Error("OAuth failed");
      const data = await response.json() as { access_token: string; expires_in: number };
      this.access = { token: data.access_token, until: Date.now() + Math.max(0, data.expires_in - 60) * 1000 };
      return this.access.token;
    } catch { throw new AppError(503, "billing_unavailable", "Google Play verification is temporarily unavailable"); }
  }
  private async request(path: string, method = "GET") {
    try {
      const response = await fetch(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(this.env.PLAY_PACKAGE_NAME)}/${path}`, {
        method, headers: { Authorization: `Bearer ${await this.accessToken()}`, "Content-Type": "application/json" },
        ...(method === "POST" ? { body: "{}" } : {}), signal: AbortSignal.timeout(15000),
      });
      if (response.status === 404 || response.status === 410) throw new AppError(422, "invalid_purchase", "Purchase could not be verified");
      if (!response.ok) throw new AppError(503, "billing_unavailable", "Google Play verification is temporarily unavailable");
      return response;
    } catch (e) {
      if (e instanceof AppError) throw e;
      // Never expose or log URLs containing purchase tokens.
      throw new AppError(503, "billing_unavailable", "Google Play verification is temporarily unavailable");
    }
  }
  async get(token: string): Promise<PlayPurchase> {
    return (await this.request(`purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`)).json() as Promise<PlayPurchase>;
  }
  async acknowledge(productId: string, token: string) {
    await this.request(`purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}:acknowledge`, "POST");
  }
}
const googleKeys = createRemoteJWKSet(new URL("https://www.googleapis.com/oauth2/v3/certs"));
export async function verifyPlayPush(env: Env, authorization?: string) {
  if (!env.PLAY_RTDN_AUDIENCE || !env.PLAY_RTDN_SERVICE_ACCOUNT || !authorization?.startsWith("Bearer ")) {
    throw new AppError(401, "unauthorized", "Authenticated Pub/Sub push required");
  }
  try {
    const { payload } = await jwtVerify(authorization.slice(7), googleKeys, { audience: env.PLAY_RTDN_AUDIENCE,
      issuer: ["https://accounts.google.com", "accounts.google.com"], algorithms: ["RS256"] });
    if (payload.email !== env.PLAY_RTDN_SERVICE_ACCOUNT || payload.email_verified !== true) throw new Error("Wrong identity");
  } catch { throw new AppError(401, "unauthorized", "Invalid Pub/Sub identity"); }
}
