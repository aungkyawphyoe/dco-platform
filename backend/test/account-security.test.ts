import { exportJWK, exportPKCS8, generateKeyPair, SignJWT } from "jose";
import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";
import { eq } from "drizzle-orm";
import { createTestApp } from "./helpers.js";
import { authChallenges, authFlows, authIdentities, authLimits, users } from "../src/db/schema.js";
import { newId, sha256 } from "../src/lib/crypto.js";

describe("onboarding account security", () => {
  let ctx: Awaited<ReturnType<typeof createTestApp>>;
  let access: string, refresh: string, userId: string, code: string;
  const email = "codes@test.local";
  beforeEach(async () => {
    ctx = await createTestApp();
    ctx.app.env.AUTH_CODES_ENABLED = "on";
    ctx.app.env.AUTH_CODE_SECRET = "test-code-secret-at-least-thirty-two-characters";
    vi.spyOn(ctx.app.mailer, "sendCode").mockImplementation(async (_email, sent) => { code = sent; });
    const signup = await ctx.app.inject({ method: "POST", url: "/v1/auth/signup", payload: { email, password: "Password123!" } });
    expect(signup.statusCode).toBe(201);
    const session = signup.json(); access = session.access_token; refresh = session.refresh_token; userId = session.user.id;
    expect(session.user.email_verified).toBe(false);
  });
  afterEach(async () => { await ctx.app.close(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });
  const bearer = (token: string) => ({ authorization: `Bearer ${token}` });
  async function issue() {
    const response = await ctx.app.inject({ method: "POST", url: "/v1/auth/email-code", headers: bearer(access), payload: { locale: "en" } });
    expect(response.statusCode).toBe(200); return response.json().challenge_id as string;
  }
  it("verifies a bound code once and guards new collaboration", async () => {
    const blocked = await ctx.app.inject({ method: "POST", url: "/v1/vehicles/shares/join", headers: bearer(access), payload: { code: "whatever" } });
    expect(blocked.json().error.code).toBe("email_verification_required");
    const id = await issue();
    expect(code).toMatch(/^\d{6}$/);
    const [stored] = await ctx.db.select().from(authChallenges).where(eq(authChallenges.id, id));
    expect(stored.digest).not.toBe(code);
    const submit = () => ctx.app.inject({ method: "POST", url: "/v1/auth/email-code/confirm", headers: bearer(access), payload: { challenge_id: id, code } });
    expect((await submit()).statusCode).toBe(200);
    expect((await submit()).statusCode).toBe(400);
    expect((await ctx.db.select().from(users).where(eq(users.id, userId)))[0].emailVerified).toBe(true);
  });
  it("persists five failures and rejects the correct code afterwards", async () => {
    const id = await issue();
    const wrong = code === "000000" ? "111111" : "000000";
    for (let i = 0; i < 5; i++) expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/email-code/confirm", headers: bearer(access), payload: { challenge_id: id, code: wrong } })).statusCode).toBe(400);
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/email-code/confirm", headers: bearer(access), payload: { challenge_id: id, code } })).statusCode).toBe(400);
  });
  it("throttles resend and invalidates old codes", async () => {
    const first = await issue(), firstCode = code;
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/email-code", headers: bearer(access), payload: {} })).statusCode).toBe(429);
    await ctx.db.update(authLimits).set({ expiresAt: new Date(0) });
    await issue();
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/email-code/confirm", headers: bearer(access), payload: { challenge_id: first, code: firstCode } })).statusCode).toBe(400);
  });
  it("reset revokes access and refresh tokens", async () => {
    const request = await ctx.app.inject({ method: "POST", url: "/v1/auth/recovery-code", payload: { email } });
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/recovery-code/confirm", payload: { challenge_id: request.json().challenge_id, code, password: "NewPassword123!" } })).statusCode).toBe(204);
    expect((await ctx.app.inject({ method: "GET", url: "/v1/me", headers: bearer(access) })).statusCode).toBe(401);
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/refresh", payload: { refresh_token: refresh } })).statusCode).toBe(401);
  });
  it("social-only accounts cannot acquire passwords through recovery", async () => {
    await ctx.db.update(users).set({ passwordHash: null }).where(eq(users.id, userId));
    const response = await ctx.app.inject({ method: "POST", url: "/v1/auth/recovery-code", payload: { email } });
    expect(response.statusCode).toBe(200);
    expect(ctx.app.mailer.sendCode).not.toHaveBeenCalled();
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/recovery-code/confirm", payload: { challenge_id: response.json().challenge_id, code: "000000", password: "Password123!" } })).statusCode).toBe(400);
  });
  async function flow(subject: string, flowEmail = email) {
    const id = newId(), secret = "test-flow-secret-at-least-thirty-two-characters";
    await ctx.db.insert(authFlows).values({ id, provider: "apple", secretHash: sha256(secret), state: newId(), nonce: newId(), verifier: newId(), claims: { subject, email: flowEmail, verified: true }, expiresAt: new Date(Date.now() + 600000) });
    return { flow_id: id, secret };
  }
  it("requires authenticated linking instead of email auto-linking", async () => {
    const body = await flow("apple-subject");
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/social/complete", payload: body })).json()).toEqual({ needs_account_choice: true });
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/social/complete", payload: { ...body, create_account: true } })).statusCode).toBe(409);
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/social/link", payload: body })).statusCode).toBe(401);
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/social/link", headers: bearer(access), payload: body })).statusCode).toBe(200);
    expect((await ctx.db.select().from(authIdentities))[0].userId).toBe(userId);
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/social/link", headers: bearer(access), payload: body })).statusCode).toBe(400);
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/social/complete", payload: await flow("apple-subject") })).json().user.id).toBe(userId);
  });
  it("creates a social owner only after explicit choice", async () => {
    const response = await ctx.app.inject({ method: "POST", url: "/v1/auth/social/complete", payload: { ...await flow("new-subject", "hidden@privaterelay.appleid.com"), create_account: true } });
    expect(response.statusCode).toBe(200);
    const user = (await ctx.db.select().from(users).where(eq(users.id, response.json().user.id)))[0];
    expect(user.passwordHash).toBeNull(); expect(user.role).toBe("owner"); expect(user.emailVerified).toBe(true);
  });
  it("rejects provider entry until credentials are configured", async () => {
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/social/apple/start", payload: {} })).statusCode).toBe(503);
  });
  it("validates the browser exchange, nonce, audience and one-time state", async () => {
    ctx.app.env.GOOGLE_CLIENT_ID = "test-client";
    ctx.app.env.GOOGLE_CLIENT_SECRET = "test-client-secret";
    const start = await ctx.app.inject({ method: "POST", url: "/v1/auth/social/google/start", payload: {} });
    expect(start.statusCode).toBe(200);
    const details = start.json();
    const authUrl = new URL(details.authorization_url);
    expect(authUrl.searchParams.get("code_challenge_method")).toBe("S256");
    const { publicKey, privateKey } = await generateKeyPair("RS256");
    const jwk = { ...await exportJWK(publicKey), kid: "test-google-key", alg: "RS256", use: "sig" };
    const idToken = await new SignJWT({ nonce: authUrl.searchParams.get("nonce"), email: "provider@test.local", email_verified: true })
      .setProtectedHeader({ alg: "RS256", kid: jwk.kid }).setSubject("real-provider-subject").setIssuer("https://accounts.google.com").setAudience("test-client").setIssuedAt().setExpirationTime("5m").sign(privateKey);
    vi.stubGlobal("fetch", vi.fn(async (url: string | URL) => {
      if (String(url).includes("certs")) return new Response(JSON.stringify({ keys: [jwk] }), { headers: { "content-type": "application/json" } });
      if (String(url).includes("oauth2.googleapis.com/token")) return new Response(JSON.stringify({ id_token: idToken }), { headers: { "content-type": "application/json" } });
      throw new Error("Unexpected network call");
    }));
    const callbackUrl = `/v1/auth/social/google/callback?state=${authUrl.searchParams.get("state")}&code=test-code`;
    const callback = await ctx.app.inject({ method: "GET", url: callbackUrl });
    expect(callback.statusCode).toBe(302);
    expect(callback.headers.location).toBe(`dco-auth://callback?flow_id=${details.flow_id}`);
    expect(callback.headers.location).not.toContain(details.secret);
    const [flow] = await ctx.db.select().from(authFlows).where(eq(authFlows.id, details.flow_id));
    expect(flow.claims?.subject).toBe("real-provider-subject");
    // A valid signature is insufficient: a new flow must reject the old nonce.
    const nextStart = (await ctx.app.inject({ method: "POST", url: "/v1/auth/social/google/start", payload: {} })).json();
    const nextState = new URL(nextStart.authorization_url).searchParams.get("state");
    await ctx.app.inject({ method: "GET", url: `/v1/auth/social/google/callback?state=${nextState}&code=another-code` });
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/social/complete", payload: { flow_id: nextStart.flow_id, secret: nextStart.secret } })).statusCode).toBe(400);
    expect((await ctx.app.inject({ method: "GET", url: callbackUrl })).statusCode).toBe(400);
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/social/complete", payload: { flow_id: details.flow_id, secret: "wrong-secret-at-least-thirty-two-characters" } })).statusCode).toBe(400);
  });
  it("rejects expired, wrong-account, and wrong-purpose codes", async () => {
    const id = await issue();
    const other = await ctx.app.inject({ method: "POST", url: "/v1/auth/signup", payload: { email: "other@test.local", password: "Password123!" } });
    const request = { method: "POST" as const, url: "/v1/auth/email-code/confirm", payload: { challenge_id: id, code } };
    expect((await ctx.app.inject({ ...request, headers: bearer(other.json().access_token) })).statusCode).toBe(400);
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/recovery-code/confirm", payload: { challenge_id: id, code, password: "Replacement123!" } })).statusCode).toBe(400);
    await ctx.db.update(authChallenges).set({ expiresAt: new Date(0) }).where(eq(authChallenges.id, id));
    expect((await ctx.app.inject({ ...request, headers: bearer(access) })).statusCode).toBe(400);
  });
  it("corrects an unverified address and invalidates the old challenge", async () => {
    const old = await issue(), oldCode = code;
    const corrected = await ctx.app.inject({ method: "POST", url: "/v1/auth/email-correction", headers: bearer(access), payload: { email: "corrected@test.local", locale: "my" } });
    expect(corrected.statusCode).toBe(200);
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/email-code/confirm", headers: bearer(access), payload: { challenge_id: old, code: oldCode } })).statusCode).toBe(400);
    expect((await ctx.app.inject({ method: "POST", url: "/v1/auth/email-code/confirm", headers: bearer(access), payload: { challenge_id: corrected.json().challenge_id, code } })).statusCode).toBe(200);
    expect((await ctx.db.select().from(users).where(eq(users.id, userId)))[0].email).toBe("corrected@test.local");
  });

  it("validates Apple's form-post callback and private relay email", async () => {
    const clientKey = await generateKeyPair("ES256", { extractable: true });
    ctx.app.env.APPLE_CLIENT_ID = "test.apple.service";
    ctx.app.env.APPLE_TEAM_ID = "TESTTEAM";
    ctx.app.env.APPLE_KEY_ID = "TESTKEY";
    ctx.app.env.APPLE_PRIVATE_KEY = await exportPKCS8(clientKey.privateKey);
    const start = (await ctx.app.inject({ method: "POST", url: "/v1/auth/social/apple/start", payload: {} })).json();
    const url = new URL(start.authorization_url);
    expect(url.searchParams.get("response_mode")).toBe("form_post");
    const { publicKey, privateKey } = await generateKeyPair("RS256");
    const jwk = { ...await exportJWK(publicKey), kid: "test-apple-key", alg: "RS256", use: "sig" };
    const token = await new SignJWT({ nonce: url.searchParams.get("nonce"), email: "relay@privaterelay.appleid.com", email_verified: "true" })
      .setProtectedHeader({ alg: "RS256", kid: jwk.kid }).setSubject("apple-browser-subject").setIssuer("https://appleid.apple.com").setAudience("test.apple.service").setIssuedAt().setExpirationTime("5m").sign(privateKey);
    vi.stubGlobal("fetch", vi.fn(async (input: string | URL) => new Response(JSON.stringify(String(input).endsWith("/keys") ? { keys: [jwk] } : { id_token: token }), { headers: { "content-type": "application/json" } })));
    const response = await ctx.app.inject({ method: "POST", url: "/v1/auth/social/apple/callback", headers: { "content-type": "application/x-www-form-urlencoded" }, payload: new URLSearchParams({ state: url.searchParams.get("state")!, code: "apple-test-code" }).toString() });
    expect(response.statusCode).toBe(302);
    const [flow] = await ctx.db.select().from(authFlows).where(eq(authFlows.id, start.flow_id));
    expect(flow.claims).toEqual({ subject: "apple-browser-subject", email: "relay@privaterelay.appleid.com", verified: true });
  });

});
