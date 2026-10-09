import { createHash } from "node:crypto";
import { and, eq, gt, isNull } from "drizzle-orm";
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "jose";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { authFlows, authIdentities, fuelTypes, users } from "../db/schema.js";
import type { Db } from "../db/client.js";
import { newId, randomToken, sha256 } from "../lib/crypto.js";
import { DEFAULT_FUEL_TYPES } from "../lib/catalog.js";
import { generateUniqueUsername } from "../lib/username.js";
import { AppError } from "../lib/errors.js";
import { issueSession } from "./auth.js";
import { authLimit, requireRecent } from "./account-security.js";

const googleKeys = createRemoteJWKSet(new URL("https://www.googleapis.com/oauth2/v3/certs"));
const appleKeys = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
const providerSchema = z.enum(["google", "apple"]);
const flowBody = z.object({ flow_id: z.string().uuid(), secret: z.string().min(32).max(128) });
const appReturn = "dco-auth://callback";

export const socialAuthPlugin: FastifyPluginAsync = async (app) => {
  // Apple's browser callback is form_post. Only parse bounded form bodies.
  app.addContentTypeParser("application/x-www-form-urlencoded", { parseAs: "string", bodyLimit: 16384 }, (_req, body, done) => {
    done(null, Object.fromEntries(new URLSearchParams(body as string)));
  });
  function configuration(provider: "google" | "apple") {
    const client = provider === "google" ? app.env.GOOGLE_CLIENT_ID : app.env.APPLE_CLIENT_ID;
    if (!client || (provider === "google" ? !app.env.GOOGLE_CLIENT_SECRET : !app.env.APPLE_PRIVATE_KEY || !app.env.APPLE_KEY_ID || !app.env.APPLE_TEAM_ID)) {
      throw new AppError(503, "provider_not_configured", "This sign-in provider is not configured yet");
    }
    const redirect = `${app.env.PUBLIC_API_URL.replace(/\/$/, "")}/auth/social/${provider}/callback`;
    if (!redirect.startsWith("https://") && app.env.APP_ENV !== "local") throw new AppError(503, "provider_not_configured", "Authentication callback must use HTTPS");
    return { client, redirect };
  }
  app.post("/auth/social/:provider/start", { config: { public: true } }, async (request) => {
    const provider = providerSchema.parse((request.params as { provider: string }).provider);
    const { client, redirect } = configuration(provider);
    await authLimit(app.db, `social-start:${request.ip}`, 30);
    const id = newId(), secret = randomToken(), state = randomToken(), nonce = randomToken(), verifier = randomToken();
    await app.db.insert(authFlows).values({ id, provider, secretHash: sha256(secret), state, nonce, verifier, expiresAt: new Date(Date.now() + 600000) });
    const url = new URL(provider === "google" ? "https://accounts.google.com/o/oauth2/v2/auth" : "https://appleid.apple.com/auth/authorize");
    url.search = new URLSearchParams({ client_id: client, redirect_uri: redirect, response_type: "code", scope: provider === "google" ? "openid email profile" : "email name", state, nonce,
      ...(provider === "google" ? { code_challenge: createHash("sha256").update(verifier).digest("base64url"), code_challenge_method: "S256", prompt: "select_account" } : { response_mode: "form_post" }),
    }).toString();
    return { flow_id: id, secret, authorization_url: url.toString() };
  });
  app.route({ method: ["GET", "POST"], url: "/auth/social/:provider/callback", config: { public: true }, handler: async (request, reply) => {
    const provider = providerSchema.parse((request.params as { provider: string }).provider);
    const body = z.object({ state: z.string().max(128), code: z.string().max(4096).optional(), error: z.string().optional() }).parse(request.method === "GET" ? request.query : request.body);
    const [flow] = await app.db.update(authFlows).set({ claimedAt: new Date() }).where(and(eq(authFlows.state, body.state), eq(authFlows.provider, provider), isNull(authFlows.claimedAt), gt(authFlows.expiresAt, new Date()))).returning();
    if (!flow) throw new AppError(400, "invalid_flow", "Sign-in expired. Please start again.");
    try {
      if (body.error || !body.code) throw new Error("cancelled");
      const { client, redirect } = configuration(provider);
      let clientSecret = app.env.GOOGLE_CLIENT_SECRET!;
      if (provider === "apple") {
        const key = await importPKCS8(app.env.APPLE_PRIVATE_KEY!.replace(/\\n/g, "\n"), "ES256");
        clientSecret = await new SignJWT({}).setProtectedHeader({ alg: "ES256", kid: app.env.APPLE_KEY_ID! }).setIssuer(app.env.APPLE_TEAM_ID!).setSubject(client).setAudience("https://appleid.apple.com").setIssuedAt().setExpirationTime("5m").sign(key);
      }
      const response = await fetch(provider === "google" ? "https://oauth2.googleapis.com/token" : "https://appleid.apple.com/auth/token", {
        method: "POST", signal: AbortSignal.timeout(15000), body: new URLSearchParams({ grant_type: "authorization_code", code: body.code, client_id: client, client_secret: clientSecret, redirect_uri: redirect, ...(provider === "google" ? { code_verifier: flow.verifier } : {}) }),
      });
      if (!response.ok) throw new Error("exchange_failed");
      const tokens = await response.json() as { id_token?: string };
      if (!tokens.id_token) throw new Error("missing_token");
      const { payload } = await jwtVerify(tokens.id_token, provider === "google" ? googleKeys : appleKeys, {
        issuer: provider === "google" ? ["https://accounts.google.com", "accounts.google.com"] : "https://appleid.apple.com", audience: client, algorithms: ["RS256"],
      });
      if (!payload.sub || payload.nonce !== flow.nonce) throw new Error("invalid_nonce");
      const email = typeof payload.email === "string" ? payload.email.toLowerCase() : undefined;
      const verified = Boolean(email) && (payload.email_verified === true || payload.email_verified === "true");
      await app.db.update(authFlows).set({ claims: { subject: payload.sub, email, verified } }).where(eq(authFlows.id, flow.id));
    } catch {
      await app.db.update(authFlows).set({ claims: { subject: "", verified: false, error: "Sign-in did not complete. Please try again." } }).where(eq(authFlows.id, flow.id));
    }
    // No bearer token or exchange secret appears in the browser URL.
    return reply.header("Cache-Control", "no-store").header("Referrer-Policy", "no-referrer").redirect(`${appReturn}?flow_id=${flow.id}`);
  } });

  app.post("/auth/social/complete", { config: { public: true } }, async (request) => {
    const body = flowBody.extend({ create_account: z.boolean().default(false) }).parse(request.body);
    await authLimit(app.db, `social-complete:${request.ip}`, 60);
    return app.db.transaction(async (tx) => {
      const [flow] = await tx.select().from(authFlows).where(and(eq(authFlows.id, body.flow_id), eq(authFlows.secretHash, sha256(body.secret)))).for("update");
      if (!flow || flow.consumedAt || flow.expiresAt <= new Date() || !flow.claims || flow.claims.error) throw new AppError(400, "invalid_flow", "Sign-in expired or was cancelled. Please try again.");
      const claims = flow.claims;
      const [identity] = await tx.select().from(authIdentities).where(and(eq(authIdentities.provider, flow.provider), eq(authIdentities.subject, claims.subject)));
      if (!identity && !body.create_account) return { needs_account_choice: true };
      let user;
      if (identity) {
        [user] = await tx.select().from(users).where(eq(users.id, identity.userId));
      } else {
        if (claims.email) {
          const [collision] = await tx.select().from(users).where(eq(users.email, claims.email));
          if (collision) throw new AppError(409, "account_link_required", "Authenticate your existing account before linking this provider");
        }
        const id = newId();
        [user] = await tx.insert(users).values({ id, email: claims.email ?? null, username: await generateUniqueUsername(tx as unknown as Db, claims.email ?? id), passwordHash: null, emailVerified: claims.verified, role: "owner", plan: "free" }).returning();
        await tx.insert(authIdentities).values({ id: newId(), userId: id, provider: flow.provider, subject: claims.subject });
        for (const ft of DEFAULT_FUEL_TYPES) await tx.insert(fuelTypes).values({ id: newId(), userId: id, name: ft.name, kind: ft.kind, unit: ft.unit });
      }
      if (!user || user.status !== "active" || user.role !== "owner") throw new AppError(403, "forbidden", "This account cannot sign in here");
      await tx.update(authFlows).set({ consumedAt: new Date() }).where(eq(authFlows.id, flow.id));
      return { ...await issueSession({ env: app.env, db: tx as unknown as Db }, user), is_new: !identity };
    });
  });
  app.post("/auth/social/link", async (request) => {
    const body = flowBody.extend({ password: z.string().optional() }).parse(request.body);
    const user = await requireRecent(app, request, body.password);
    if (user.role !== "owner") throw new AppError(403, "forbidden", "Owner account required");
    await authLimit(app.db, `social-link:${user.id}`, 10);
    return app.db.transaction(async (tx) => {
      const [flow] = await tx.select().from(authFlows).where(and(eq(authFlows.id, body.flow_id), eq(authFlows.secretHash, sha256(body.secret)))).for("update");
      if (!flow || flow.consumedAt || flow.expiresAt <= new Date() || !flow.claims || flow.claims.error) throw new AppError(400, "invalid_flow", "Sign-in expired or was cancelled");
      const [identity] = await tx.select().from(authIdentities).where(and(eq(authIdentities.provider, flow.provider), eq(authIdentities.subject, flow.claims.subject)));
      if (identity && identity.userId !== user.id) throw new AppError(409, "identity_in_use", "This provider belongs to another account");
      if (!identity) await tx.insert(authIdentities).values({ id: newId(), userId: user.id, provider: flow.provider, subject: flow.claims.subject });
      if (flow.claims.verified && flow.claims.email === user.email) await tx.update(users).set({ emailVerified: true }).where(eq(users.id, user.id));
      await tx.update(authFlows).set({ consumedAt: new Date() }).where(eq(authFlows.id, flow.id));
      return { linked: true };
    });
  });
  app.get("/auth/connections", async (request) => {
    const identities = await app.db.select({ provider: authIdentities.provider }).from(authIdentities).where(eq(authIdentities.userId, request.authUser!.sub));
    const [user] = await app.db.select().from(users).where(eq(users.id, request.authUser!.sub));
    return { providers: identities.map(i => i.provider), has_password: Boolean(user?.passwordHash) };
  });
};
