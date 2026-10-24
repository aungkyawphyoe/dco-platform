# Security assessment — 23 October 2026

Repository baseline: `10aecb3`. Focus: Fastify/TypeScript auth and Drizzle routes, with supporting Admin, Fleet, Flutter, and infrastructure review.

> This is the original baseline assessment, not the current fix status. See [security-remediation-2026-10-24.md](security-remediation-2026-10-24.md) for implemented changes, validation, and remaining deployment/device checks.

## Executive assessment

**High-risk authorization defects are present.** Ordinary Fleet credentials do not directly pass the Admin role/audience guard. However, personal record creation has object-authorization gaps, stale Admin tokens retain privileges after demotion, and Fleet membership management can affect global personal accounts.

Six findings are rated High, eight Medium, and one Low. Severity expresses impact under the stated prerequisites, not proof of internet exploitation. No Critical finding was established. Findings 1–5 and 7 were reproduced against an isolated PGlite database through the real Fastify app; other findings distinguish static evidence from deployment-dependent risks. No production service was contacted or modified. Application code was not changed.

The review covers authentication, representative route families and their shared authorization helpers, personal and organization record operations, sync, media, social login, sharing, portal sessions, Flutter storage/network/deep links, and checked-in infrastructure. This is not a certification of every route or dependency: production configuration, live response headers, cloud IAM, deployed artifacts, dependency vulnerability feeds, device backups, and real PostgreSQL concurrency were not independently assessed.

OWASP mapping uses the current [OWASP Top 10:2025](https://top10.owasp.org/2025/) and the [OWASP API Security Top 10](https://owasp.org/API-Security/). In particular, [API1:2023 BOLA](https://api-security.owasp.org/editions/2023/en/0xa1-broken-object-level-authorization/) requires authorization for the requested object even when the user is authenticated. UUID unpredictability does not replace authorization.

## Trust boundaries and existing controls

| Boundary | Actual enforcement | Threat to test |
|---|---|---|
| Internet → `/v1` | `attachAuth` validates JWT, account status, and auth version, except explicitly public routes | Public abuse, token theft, route classification mistakes |
| Owner/Fleet/Admin | `requireOwner`, `requireFleetPortal`, `requireAdmin`; audience plus role | Stale roles and alternate routes to the same data |
| Fleet organization | `getOrganizationAccess` checks caller membership, enterprise plan, organization status, and permitted roles | Tenant ID substitution and excessive authority over global users |
| Vehicle/record | Ownership, sharing, assignment, author checks | Child IDs and duplicate-create paths bypassing parent checks |
| Offline client → sync | Personal sync invokes normal HTTP handlers with bearer auth | Unbounded work and inherited handler defects |
| Web JavaScript → session routes | HttpOnly cookies; access JWT returned to JavaScript memory | XSS can obtain access tokens despite cookie protection |
| Device → storage | Keychain/Keystore-backed tokens; ordinary Drift and document files | Backup/device compromise and stale offline access |
| Ownership transfer | Current ownership changes; historical Fleet endpoint still queries live records | Former owner reads new owner's data |

The mobile client is not a trusted security principal. Audience distinguishes an issued credential's intended surface; a malicious caller can still construct HTTP requests. Every route must enforce live permissions and relationships independently.

Positive controls found:

- Admin plugin has a `preHandler` calling `requireAdmin`; an owner token received **403** on `/v1/admin/dashboard`.
- Fleet helpers check live membership and organization status, not just the JWT. Organization record routes add explicit vehicle/reference validation and revision-aware transactions.
- Most payloads use Zod before business logic, and updates explicitly select writable fields. OpenAPI is loaded as static Swagger documentation; it is **not** the runtime validator.
- No request-controlled `sql.raw` construction was found in the reviewed backend. Drizzle builders and `sql` template interpolations bind values; the presence of raw-looking tagged SQL is not itself SQL injection.
- Generic unexpected errors are hidden by the central handler. Authorization/cookie headers are redacted, and request query strings are removed from request logging.
- CORS uses a configured origin list, not arbitrary origin reflection. Checked-in Azure ingress has `allowInsecure: false`. Mobile native HTTP is not governed by browser CORS.
- Web refresh cookies are HttpOnly, SameSite=Lax, and Secure in production. Token stores use module memory, not localStorage/sessionStorage. Sidebar localStorage contains UI preferences.
- Flutter uses `flutter_secure_storage` for tokens. No accept-all TLS certificate callback was found. OAuth callback parsing checks scheme, host, and the initiating flow ID. Server-side OAuth uses state, nonce, provider issuer/audience verification, one-time flows, and a separate exchange secret; Google also uses PKCE.
- The `dangerouslySetInnerHTML` hits are static theme initialization scripts; no confirmed user-controlled XSS sink was identified.

## Findings and remediation

Examples below are implementation sketches using repository entities and conventions, not applied patches. Named new helpers/tables are explicitly design additions. Preserve existing entitlement, author, revision, and transaction rules when implementing them.

### 1. High — BOLA through idempotent record creation

**Component:** Backend; exposed to Mobile/personal clients. **Mapping:** A01:2025 / API1:2023. **Status:** Reproduced for plan items; same unchecked pattern found for services, parts, fuel logs, and expenses.

Evidence: [owner.ts:474](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/owner.ts:474), [owner.ts:629](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/owner.ts:629), [owner.ts:777](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/owner.ts:777), [owner.ts:920](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/owner.ts:920), [owner.ts:1203](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/owner.ts:1203).

The handler authorizes the URL vehicle, then globally looks up `body.id` and returns that record without confirming its vehicle or the caller's access to it. An attacker with an accessible personal vehicle and a known foreign record UUID can retrieve foreign data. Knowing an ID is a prerequisite; blind UUID guessing was not demonstrated. Previously shared IDs and offline history are realistic sources. The organization wrapper has additional conflict checks, but the personal route reaches the same global tables without them. The documents create handler already demonstrates a stronger pattern.

Probe: Owner A posted Owner B's plan UUID under A's vehicle. Response was **201**, with B's vehicle ID and private plan name.

```ts
// Before: authorization covers vehicleId, not the returned object.
const [existing] = await db().select().from(planItems)
  .where(eq(planItems.id, body.id));
if (existing) return publicPlan(existing);

// After: run after authorizing vehicleId; never disclose a foreign collision.
const [existing] = await db().select().from(planItems)
  .where(eq(planItems.id, body.id));
if (existing) {
  if (existing.vehicleId !== vehicleId) {
    throw new AppError(409, "id_conflict", "Record ID already exists");
  }
  await loadPlanItemFor(db(), uid(request), existing.id, "write");
  return reply.code(201).send(publicPlan(existing));
}
```

Apply analogous resource-specific authorization to all five record types. Concurrent duplicate inserts must handle the unique-key conflict by re-reading only through the same scoped authorization path. Regression: foreign ID replay returns 403/404/409 and never foreign fields; legitimate same-object retry remains idempotent.

### 2. High — Nested service references permit cross-vehicle writes

**Component:** Backend. **Mapping:** A01:2025 / API1:2023. **Status:** Reproduced.

Evidence: [owner.ts:645](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/owner.ts:645). Personal service creation accepts `items[].plan_item_id`, loads that plan globally, then updates its next-due values. It does not establish that the plan belongs to the authorized vehicle. Organization routes have reference validation; personal routes do not inherit it. Related personal service/expense part and receipt references also need relationship validation, although arbitrary receipt download was not demonstrated.

Probe: A service on A's vehicle referenced B's plan. It returned **201** and changed B's next-due mileage to **10,999**.

```ts
// Before
const [plan] = await db().select().from(planItems)
  .where(eq(planItems.id, item.plan_item_id));
if (plan) await db().update(planItems).set(due)
  .where(eq(planItems.id, plan.id));

// After: validate every reference before mutation, within the same transaction.
await app.db.transaction(async tx => {
  await getAccessibleVehicle(tx as Db, uid(request), vehicleId, "full");
  for (const item of body.items) {
    if (!item.plan_item_id) continue;
    const [plan] = await tx.select().from(planItems).where(and(
      eq(planItems.id, item.plan_item_id),
      eq(planItems.vehicleId, vehicleId),
    )).for("update");
    if (!plan) throw new AppError(422, "invalid_plan_item", "Invalid plan item");
    // Insert service + items and compute due values inside this transaction.
    const due = dueFrom(plan.intervalDays, num(plan.intervalDistance), body.odometer);
    await tx.update(planItems).set({
      nextDueOn: due.nextDueOn,
      nextDueMileage: due.nextDueMileage == null ? null : String(due.nextDueMileage),
    }).where(and(eq(planItems.id, plan.id), eq(planItems.vehicleId, vehicleId)));
  }
});
```

Apply this validation on create and patch for parts, plans, media, and other nested references. A foreign reference must reject the entire transaction with no partial service or schedule change. Database composite constraints can add defense in depth but do not replace the caller permission check.

### 3. High — Demoted Admin access tokens retain Admin authority

**Component:** Backend / Admin. **Mapping:** A01:2025, A07:2025. **Status:** Reproduced.

Evidence: [admin.ts:455](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/admin.ts:455), [auth.ts:342](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/auth.ts:342).

Role changes do not increment `authVersion`. Middleware loads the current account but retains the role from the signed token. A demoted Admin therefore continues to pass `requireAdmin` until access expiration (15 minutes by default), potentially undoing the demotion or creating another privileged account.

Probe: promote test user, log in, demote user, call Admin dashboard with old token → **200**.

```ts
// Before
await db.update(users).set({ role: body.role }).where(eq(users.id, userId));

// After: role change + session invalidation are atomic.
await db.transaction(async tx => {
  await tx.update(users).set({
    role: body.role,
    authVersion: sql`${users.authVersion} + 1`,
  }).where(eq(users.id, userId));
  await tx.update(refreshTokens).set({ revokedAt: new Date() })
    .where(eq(refreshTokens.userId, userId));
});
// In attachAuth, additionally reject a role mismatch against the live account:
if (claims.role !== account.role) throw new Error("revoked");
```

Test both access and refresh after demotion, plus deactivate/reactivate transitions: reactivation must not resurrect an old access token. Increment the version on security-sensitive revocations consistently.

### 4. High — Fleet administration escapes organization scope

**Component:** Backend / Fleet. **Mapping:** A01:2025 / API5:2023. **Status:** Reproduced.

Evidence: [fleet.ts:181](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/fleet.ts:181), [fleet.ts:255](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/fleet.ts:255).

A Fleet admin can immediately add an existing active personal owner as a manager/mechanic by email, without invitation acceptance. The status endpoint then updates global `users.status`. For a target not already in an organization, this allows a malicious Fleet admin to disable the target's personal account. Role changes to `org_driver` can also impose the personal-garage ban on an existing personal identity, bypassing the create-time prohibition on reusing personal accounts as drivers.

Probe: adding an unrelated existing owner returned **201**; deactivation returned **200**; victim's personal `/v1/me` then returned **401**.

```ts
// Before: organization authority modifies a global identity.
await db.update(users).set({ status: "deactivated" })
  .where(eq(users.id, memberId));

// After: schema change — membership status is organization-local.
await db.update(organizationMembers).set({ status: "suspended" })
  .where(and(
    eq(organizationMembers.orgId, orgId),
    eq(organizationMembers.userId, memberId),
  ));
// getOrganizationAccess must require membership.status === "active".
// Global user suspension stays restricted to platform Admin routes.
```

Introduce pending invitations for existing identities, bound to the authenticated intended recipient, with explicit acceptance. Preserve separate provisioned driver identities, and reject manager/mechanic → driver conversion where it would capture personal accounts. Ensure active assignments are revoked transactionally with membership suspension.

### 5. High — Former Fleet owner can read buyer's future service history

**Component:** Backend / Fleet / Mobile data. **Mapping:** A01:2025 / API1:2023. **Status:** Reproduced using a historical-transfer fixture and a new buyer-created service record.

Evidence: [fleet-operations.ts:713](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/fleet-operations.ts:713), especially the unbounded-by-tenure live query at line 722.

The route verifies that the organization once transferred the vehicle, then returns all current service records for the vehicle. The buyer's subsequent notes, costs, and workshop visits become visible to the former organization. A valid historic relationship is not ongoing authorization to new owner records. The newer analytics module already uses organization-scoped snapshots; the legacy history endpoint should follow that boundary.

```ts
// Before
const services = await db.select().from(serviceRecords)
  .where(eq(serviceRecords.vehicleId, vehicleId));

// After: proposed snapshot table, populated atomically at transfer.
const services = await db.select().from(transferServiceSnapshots).where(and(
  eq(transferServiceSnapshots.transferId, transfer.id),
  eq(transferServiceSnapshots.orgId, orgId),
));
```

Store only authorized historical fields at transfer, or reuse appropriately frozen `analytics_records` snapshots. Filtering by user-entered `serviced_on` is insufficient: a buyer can backdate a service. The live service table lacks an immutable creation timestamp in the schema reviewed. Warranty-related post-sale disclosure needs an explicit limited policy rather than unrestricted history.

### 6. High — Authentication throttling disabled with email-code feature

**Component:** Backend, affecting all clients. **Mapping:** A07:2025 / API2 and API4:2023. **Status:** Confirmed code/config risk; deployed flag and edge controls unverified.

Evidence: [auth.ts:43](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/auth.ts:43), [auth.ts:96](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/auth.ts:96), [auth.ts:278](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/auth.ts:278), [env.ts:6](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/config/env.ts:6).

Login/signup/reset-delivery throttling is conditional on `AUTH_CODES_ENABLED=on`; default is `off`. This couples abuse protection to an unrelated rollout feature. The account-security module already has shared PostgreSQL counters, so a production-capable primitive exists. Password-change attempts also need independent throttling. No global application rate limiter was found.

```ts
// Before
if (app.env.AUTH_CODES_ENABLED === "on") {
  await authLimit(app.db, `login-ip:${request.ip}`, 60);
}

// After: always apply before expensive password verification.
await authLimit(app.db, `login-ip:${request.ip}`, 60);
await authLimit(app.db, `login-account:${normalizedIdentifier}`, 20);
// Apply independent limits to signup, recovery delivery, password change,
// refresh, and public expensive routes, regardless of email feature flags.
```

Resolve email/username aliases to a consistent account key after bounded lookup, use progressive backoff, and avoid making targeted account lockout easy. Verify proxy-hop settings against the actual ingress path; never trust arbitrary forwarded IP headers. Add edge request/body/concurrency limits and expiration cleanup for rate-limit/challenge rows. Test identical throttling with the feature on and off.

### 7. Medium — Password change does not revoke existing access tokens

**Component:** Backend / all clients. **Mapping:** A07:2025 / API2:2023. **Status:** Reproduced.

Evidence: [auth.ts:207](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/auth.ts:207). Password change revokes refresh rows but does not increment `authVersion`; the password-reset flow does. A stolen access token remains usable until its expiration. Logout similarly revokes refresh credentials only; clarify whether logout promises immediate access revocation or a bounded expiry window.

Probe: password change → **204**; old access token on `/v1/me` → **200**.

```ts
// Before
.set({ passwordHash: await hashPassword(body.new_password), mustChangePassword: false })

// After: in one transaction with refresh revocation.
.set({
  passwordHash: newPasswordHash,
  mustChangePassword: false,
  authVersion: sql`${users.authVersion} + 1`,
})
```

Invalidate every old access/refresh session after password change and require sign-in again, or issue the initiating client a fresh versioned session. For per-device logout, add a session ID with server-side session revocation rather than globally revoking all devices unintentionally.

### 8. Medium — Refresh rotation is not atomic

**Component:** Backend / all clients. **Mapping:** A07:2025 / API2:2023. **Status:** Static concurrency risk, not reproduced on the single-connection test database.

Evidence: [auth.ts:142](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/auth.ts:142). The handler selects an unrevoked row, then unconditionally updates by ID, then issues replacement credentials. Two PostgreSQL connections can both observe the original row as active and mint successors. Token-family replay invalidation is also absent.

```ts
// Before
const [stored] = await db.select().from(refreshTokens).where(activePredicate);
await db.update(refreshTokens).set({ revokedAt: new Date() })
  .where(eq(refreshTokens.id, stored.id));
return issueSession(app, user, stored.audience);

// After: conditional consume and successor creation in the same transaction.
return app.db.transaction(async tx => {
  // Lock the user first; use the same lock order as password reset/revocation.
  const [user] = await tx.select().from(users)
    .where(eq(users.id, payload.sub)).for("update");
  if (!user || user.status !== "active" || payload.ver !== user.authVersion) {
    throw new AppError(401, "invalid_refresh", "Invalid refresh token");
  }
  const [stored] = await tx.update(refreshTokens).set({ revokedAt: new Date() })
    .where(and(
      eq(refreshTokens.id, payload.jti), eq(refreshTokens.userId, user.id),
      eq(refreshTokens.tokenHash, sha256(body.refresh_token)),
      isNull(refreshTokens.revokedAt), gt(refreshTokens.expiresAt, new Date()),
    )).returning();
  if (!stored) throw new AppError(401, "invalid_refresh", "Invalid refresh token");
  return issueSession({ env: app.env, db: tx as Db }, user,
    stored.audience, Number(payload.auth_time ?? payload.iat));
});
```

Add token-family IDs and a deliberate reuse policy; ensure any family revocation commits even when the request subsequently returns an error. Validate with two real PostgreSQL connections synchronized before consume. The local parallel probe returned **200/401**, which does not establish safety under multi-connection scheduling.

### 9. Medium — Unbounded sync work and database retrieval

**Component:** Backend / Mobile sync. **Mapping:** API4:2023 / A06:2025. **Status:** Static evidence.

Evidence: [sync.ts:34](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/sync.ts:34), [sync.ts:69](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/sync.ts:69). Push accepts an array without an operation-count cap; each operation can issue multiple internal requests. Pull retrieves all matching history and only then slices to 200 in memory. Fastify's body limit bounds request bytes, but not historical rows fetched or aggregate per-account work.

```ts
// Before
z.object({ operations: z.array(opSchema) }).parse(request.body);
const rows = await db.select().from(changeLog).where(scope).orderBy(changeLog.seq);
return rows.slice(0, 200);

// After
z.object({ operations: z.array(opSchema).min(1).max(100) }).strict()
  .parse(request.body);
const rows = await db.select().from(changeLog).where(scope)
  .orderBy(changeLog.seq).limit(200);
```

Bound nested service items/parts, text lengths, report ranges, and per-account concurrent operations. Validate cursors as safe nonnegative integers. Keep date/number constraints consistent between Zod and OpenAPI; strings that happen to resemble dates should not reach database casts unchecked. Return standard 400/413/429 errors rather than turning Fastify parser/size failures into generic 500s.

### 10. Medium — Share capability codes use non-cryptographic randomness

**Component:** Backend / Mobile sharing. **Mapping:** A04:2025 / API2 and API4:2023. **Status:** Static evidence; no practical code prediction demonstrated.

Evidence: [vehicle-shares.ts:46](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/vehicle-shares.ts:46), join at line 941, preview at line 1072. Eight-character codes use `Math.random`, remain valid for seven days, and have no route-specific attempt limits. Preview returns vehicle plate and owner display name. Auth is required, but account creation is public. Eight base-36 characters have about 41 bits of nominal entropy; lack of throttling is not proof that a particular code is cheaply guessable.

```ts
// Before
code += chars.charAt(Math.floor(Math.random() * chars.length));

// After: preserve the current code format with a cryptographic generator.
import { randomInt } from "node:crypto";
const code = Array.from({ length: 8 }, () => chars[randomInt(chars.length)]).join("");
await authLimit(app.db, `share-lookup-user:${uid(request)}`, 20, 60);
await authLimit(app.db, `share-lookup-ip:${request.ip}`, 60, 60);
```

Apply limits to both preview and join; shorten validity, use longer secrets for QR/link flows, and atomically consume one-time invitations. Consider storing a hash of the code/token and never returning capability secrets to recipients who need only ordinary shared access.

### 11. Medium — Legacy CSV export allows spreadsheet formulas

**Component:** Backend / Fleet. **Mapping:** A05:2025. **Status:** Static evidence; spreadsheet execution not attempted.

Evidence: [fleet-operations.ts:807](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/fleet-operations.ts:807). The legacy exporter quotes CSV cells but does not neutralize formula prefixes. User-controlled vehicle names/plates beginning with `=`, `+`, `-`, or `@` may be interpreted as formulas when a recipient opens the export. Actual impact depends on spreadsheet software and the attacker's ability to influence exported fields. The newer analytics exporter already has a safer helper.

```ts
// Before: CSV quoting alone does not prevent formula interpretation.
const escape = (value: unknown) => `"${String(value ?? "").replaceAll('"', '""')}"`;

// After: reuse the existing helper and test the supported spreadsheet clients.
import { csvCell } from "../lib/fleet-analytics.js";
const csv = lines.map(line => line.map(csvCell).join(",")).join("\r\n");
```

Prefer typed XLSX text cells for exports where robust cross-client behavior matters. Add fixtures for formula prefixes, leading whitespace/control characters, quotes, commas, and newlines.

### 12. Medium — Web tokens remain JavaScript-accessible; browser hardening absent in source

**Component:** Admin / Fleet, with Backend header hardening. **Mapping:** A02:2025; XSS impact amplification. **Status:** Architectural risk; no XSS exploit confirmed and live headers unverified.

Evidence: [web login route](/Users/akp/Desktop/PersonalProjects/dco-platform/web/src/app/api/auth/login/route.ts:47), [web token store](/Users/akp/Desktop/PersonalProjects/dco-platform/web/src/lib/auth/token-store.ts:1), corresponding Fleet files, and both `next.config.ts` files. HttpOnly refresh cookies are good, but login/session responses return the access JWT and the app stores it in JavaScript memory. An origin-level XSS can request a fresh token. No application CSP/HSTS/frame policy was found; an ingress may add some headers.

```ts
// Before: browser gets an extractable bearer credential.
return NextResponse.json({ user: session.user, access_token: session.access_token });

// After: proposed BFF design — keep credentials server-side/in HttpOnly cookies.
const out = NextResponse.json({ user: session.user });
setAdminSessionCookies(out, session.access_token, session.refresh_token);
out.headers.set("Cache-Control", "no-store");
return out;
// Browser calls same-origin, explicitly allowlisted BFF endpoints.
// BFF reads cookies and forwards bearer auth to fixed upstream API paths.
```

A BFF prevents direct bearer-token extraction but cannot stop XSS from taking actions in an active session. Add a nonce/hash-based CSP that accommodates the static theme script, `frame-ancestors`, `nosniff`, appropriate Referrer-Policy, and HTTPS-only HSTS at the edge. Do not copy a blanket unsafe-inline policy. For cookie-authenticated writes, validate an exact configured Origin and use CSRF protection; SameSite is defense in depth. Login/session handlers currently lack explicit Origin validation, but an end-to-end CSRF exploit was not established. Do not add mobile custom schemes to CORS; native clients do not need browser origin permission.

### 13. Medium — Sensitive offline files lack explicit app encryption and backup controls

**Component:** Mobile. **Mapping:** A04:2025; mobile storage threat. **Status:** Device/backup-dependent risk, not remote API compromise.

Evidence: [document_cache.dart](/Users/akp/Desktop/PersonalProjects/dco-platform/mobile/lib/core/media/document_cache.dart:41), [app_database.dart](/Users/akp/Desktop/PersonalProjects/dco-platform/mobile/lib/core/database/app_database.dart:40), [AndroidManifest.xml](/Users/akp/Desktop/PersonalProjects/dco-platform/mobile/android/app/src/main/AndroidManifest.xml:8). Tokens use secure storage, but documents are written as plain PDF/JPEG/PNG files and Drift opens a normal database. No explicit Android backup exclusions were found in the main manifest reviewed. OS sandboxing and device encryption still provide protection; backup/device extraction needs separate assessment.

```dart
// Before
await file.writeAsBytes(response.data!);

// After: proposed authenticated-encryption wrapper, not an existing API.
final key = await accountKeyStore.loadOrCreate(userId); // Keychain/Keystore backed
final encrypted = await encryptedFiles.seal(
  plaintext: response.data!, key: key,
  associatedData: '$userId/$organizationId/${row.mediaId}',
); // Random nonce + authenticated encryption; store nonce and tag with ciphertext.
await file.writeAsBytes(encrypted);
```

Use a maintained encryption implementation, an encrypted SQLite solution with tested migrations where the threat model warrants it, and explicit Android/iOS backup exclusions for credentials and sensitive caches. Scope encryption keys per account and define logout/revocation retention behavior. Secure storage for tokens does not encrypt unrelated files. A fully offline device cannot receive immediate server revocations; document this access window and consider a bounded offline lease for sensitive Fleet data.

### 14. Medium — Release endpoint configuration does not require HTTPS

**Component:** Mobile. **Mapping:** A02/A04:2025. **Status:** Configuration risk; no live cleartext release demonstrated.

Evidence: [app_config.dart](/Users/akp/Desktop/PersonalProjects/dco-platform/mobile/lib/core/config/app_config.dart:13), [dio_client.dart](/Users/akp/Desktop/PersonalProjects/dco-platform/mobile/lib/core/network/dio_client.dart:15). The default URL is HTTP localhost and arbitrary build-time URLs are accepted even in release. Platform restrictions may block cleartext; neither their absence nor absence of pinning proves TLS verification is disabled. No permissive certificate callback or iOS ATS exception was found.

```dart
// Before
return AppConfig(apiBaseUrl: apiBaseUrl, /* other fields */);

// After: run before building the client.
final uri = Uri.tryParse(apiBaseUrl);
if (kReleaseMode && (uri == null || uri.scheme != 'https' || uri.host.isEmpty)) {
  throw StateError('Release API_BASE_URL must use HTTPS');
}
```

Explicitly block Android cleartext traffic in the release manifest/network-security policy, preserve default iOS ATS restrictions, and test the actual built release. Restrict bearer attachment to the configured API origin, especially for absolute media URLs. Certificate pinning is optional defense in depth for a justified threat model, with backup pins and a rotation plan; missing pinning alone is not a vulnerability. Prefer verified App/Universal Links to custom schemes where feasible. Current callback host/flow and secret checks substantially reduce custom-scheme interception impact; no intent-redirection/token-theft exploit was confirmed.

### 15. Low — Obsolete destructive reset route remains registered

**Component:** Backend / Admin. **Mapping:** A02:2025. **Status:** Dead/dangerous maintenance code; not a confirmed public bypass.

Evidence: [admin.ts:38](/Users/akp/Desktop/PersonalProjects/dco-platform/backend/src/modules/admin.ts:38). The route is marked public, contains a hardcoded reset header and default-password fixture creation, and issues sequential deletes without a transaction. However, Fastify applies the plugin Admin hook even though it is declared later. Since global auth skips this public route, `authUser` is unset and `requireAdmin` rejects it. A local framework probe and real app request both confirmed blocking. Some referenced tables are also legacy; successful deletion was not tested.

```ts
// Before
app.post("/admin/reset-users", { config: { public: true } }, destructiveReset);

// After
// Remove this HTTP route entirely. Use isolated test fixtures for resets.
```

Do not fix this by merely removing the Admin hook or moving the route. Production maintenance, if genuinely needed, should be a separately authorized, audited operational workflow with a reviewed target scope and transaction/backup strategy. Remove path-pattern auth exemptions and rely on explicit public route metadata to reduce future classification mistakes.

## Additional hardening without a demonstrated exploit

- JWT verification should explicitly allow `HS256`, require expected claims, validate role/audience combinations, and use issuer validation. Environment validation currently permits 16-character JWT secrets and an 8-character media signing key; enforce cryptographically generated secrets of at least 32 random bytes with no local fallback in production. Minimum string length alone does not prove actual weak deployed keys.
- Signed personal media URLs are bearer capabilities valid for 15 minutes and not user-bound. That may be an intentional download design; use no-store/private caching as appropriate, avoid referrer/log leakage, and decide whether access revocation must invalidate issued URLs. Organization content already performs live membership/assignment checks. Use constant-time comparison for HMACs as defense in depth.
- Privileged Admin actions merit phishing-resistant MFA or an identity-provider step-up, plus recent-auth checks and audit alerts. No MFA was identified, but this alone was not labeled an account takeover.
- Keep auth/session responses non-cacheable. Ensure logs never include reset codes, OAuth secrets, temporary passwords, signed URLs, or SQL parameter values containing PII. Test mail output uses stdout intentionally; verify production `MAIL_PROVIDER` does not do so.
- Continue using parameterized Drizzle operations. Dynamic sort columns must be selected from a static allowlist; never introduce `sql.raw(userInput)`. SQL injection and authorization are separate concerns: the reproduced BOLA bugs use parameterized queries.
- Keep OpenAPI synchronized with Zod through schema generation or contract tests. Require explicit audience/permission metadata on new routes, with registration-time checks and deny-by-default behavior.

## Validation and regression plan

Existing command run:

```sh
cd backend
npm test -- --maxWorkers=1 test/auth.test.ts test/admin.test.ts \
  test/fleet.test.ts test/vehicle-shares.test.ts test/account-security.test.ts
```

Result: **5 files, 41 tests passed**. These passing tests do not cover the new negative cases.

Temporary probe uses the repository's `createTestApp`, PGlite, synthetic accounts/vehicles, and `app.inject`. It never uses the configured production database. Results:

| Probe | Observed |
|---|---|
| Foreign plan ID posted under attacker's vehicle | 201, victim plan fields returned |
| Foreign plan referenced by attacker's service | 201, victim schedule changed |
| Old Admin token after demotion | 200 on Admin dashboard |
| Old token after password change | 200 on `/v1/me` |
| Add unrelated existing account as Fleet manager | 201 without target acceptance |
| Fleet globally deactivates that member | 200; victim personal API then 401 |
| Buyer creates a post-sale service; former Fleet owner reads transfer history | 201 on create; 200 history response includes buyer's private notes |
| Ordinary owner token on Admin dashboard | 403 |
| Public-marked reset route without auth | 401, blocked by plugin hook |
| Parallel refresh with same token on PGlite | 200/401; real PostgreSQL race still needs targeted testing |

Add durable regression tests for:

1. Every object route under anonymous, owner A, owner B, view-only share, write-own share, revoked share, Fleet A/B admin, manager, mechanic, assigned/unassigned driver, workshop, and platform Admin principals.
2. Existing UUIDs in create bodies, all nested reference IDs, and body/URL ID disagreement. Test personal routes against organization-owned records as well as other personal users.
3. Role demotion, password change, global deactivation/reactivation, membership removal, and vehicle transfer with previously minted credentials.
4. New buyer records never appearing in seller history, including backdated services and edits after transfer.
5. Foreign reference errors roll back all writes. Use real PostgreSQL concurrency tests for refresh, share acceptance, role mutation, assignment/ownership change, and quota checks.
6. Rate-limit feature-flag independence, pagination enforced in SQL, operation limits, safe CSV cells, actual browser response headers, and built mobile release transport/backup behavior.

## Remediation order

**Before further production rollout:** repair findings 1–4; remove cross-owner history disclosure (5); make abuse limits unconditional (6). Invalidate affected sessions when deploying role/revocation fixes and examine existing audit/access records for suspicious repeated foreign IDs and unexpected role changes. Do not infer a historical breach merely from vulnerable code.

**Next:** fix password/session lifecycle and concurrency, bound sync/database work, harden share capabilities, and replace legacy CSV export escaping. Consolidate duplicated personal/organization authorization logic so every route to the same records enforces the same invariant.

**Then:** verify production ingress/CORS/headers and secrets, implement the chosen browser-token architecture, test mobile release and backup behavior, and add the negative authorization matrix to CI.
