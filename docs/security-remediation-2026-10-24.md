# Security remediation — 24 October 2026

This follows the baseline [security assessment](security-assessment-2026-10-23.md). Changes are local on `codex/security-rate-limits`; no service or device deployment has been performed.

## Findings and implemented controls

| Finding | Result | Implementation |
|---|---|---|
| 1. Duplicate-create BOLA | Fixed | Personal writes run in a transaction. Existing record IDs must match the authorized vehicle and author permissions before any idempotent response. Applies to plan items, services, parts, fuel logs, expenses and documents, including sync calls. |
| 2. Foreign linked records | Fixed | Service plans, parts and receipt media must belong to the same authorized vehicle. Plan rows are locked during service writes. Invalid references roll back the request. |
| 3. Stale Admin role | Fixed | Role changes increment auth version; every authenticated request compares live account role and version. Deactivation increments version too, preventing old tokens becoming valid after reactivation. |
| 4. Fleet control of personal accounts | Fixed with a compatibility change | Status changes affect membership, never global users. Login and Fleet/driver access enforce active membership. Existing-account enrollment is rejected until a consent flow exists; new dedicated accounts remain supported. Existing managers/mechanics cannot be converted to drivers. |
| 5. Buyer data after transfer | Fixed | Each new transfer stores immutable service and vehicle snapshots in its transaction. History/list endpoints use those snapshots. Legacy transfers have empty history and unavailable vehicle details; there is no live-data fallback. |
| 6. Conditional public rate limits | Fixed previously | See [public API rate limits](public-api-rate-limits.md). |
| 7. Access after password change | Fixed | Password changes atomically increment auth version and revoke refresh tokens. Fleet and Flutter establish a fresh session after success. Attempts are rate-limited per user. |
| 8. Refresh replay race | Fixed | User row lock plus conditional token consumption and successor issuance in one transaction. Only one redemption can succeed. This is single-use rotation, not a new token-family compromise detection system. |
| 9. Unbounded personal sync | Fixed | Maximum 100 push operations; change pulls use SQL LIMIT 200 and a nonnegative safe-integer cursor. Nested record arrays are capped at 100 before reference queries. Payload IDs cannot override the envelope ID. |
| 10. Share-code guessing | Fixed | Cryptographically secure uniform code generation, plus shared database-backed per-user (30/hour) and per-IP (60/hour) budgets across lookup, join, accept and decline. |
| 11. CSV formulas | Fixed | Legacy Fleet exports reuse the existing formula-neutralizing CSV serializer. |
| 12. Browser token exposure / missing headers | Fixed | Both portals use a same-origin server proxy. Access/refresh tokens stay in HttpOnly cookies; login/session JSON contains an authentication flag only. Writes require an exact Origin match. Proxy bodies are bounded, destination paths constrained, redirects disabled, and only selected headers forwarded. Nonce CSP, HSTS, no-store, anti-framing and other headers added. |
| 13. Mobile backup / local-file exposure | Mitigated; native verification outstanding | Android cloud/device backup exclusions and allowBackup=false; iOS support/documents directories excluded from backup and file protection configured before Flutter starts. iOS credentials are device-bound Keychain items. SQLite and document files are still ordinary app-private files: this change does not add SQLCipher or per-document encryption. Device encryption, lock-screen policy and compromised-device risk remain deployment considerations. |
| 14. Cleartext release configuration | Fixed in source; native verification outstanding | Release configuration requires HTTPS; Android release cleartext is disabled (debug override retained), ATS disallows arbitrary loads. Dio suppresses bearer headers on other origins and does not follow redirects. Default certificate validation remains enabled; pinning is not asserted or required for this fix. |
| 15. Obsolete reset route | Removed | Deleted `/admin/reset-users`; it was not publicly exploitable in the baseline. |

Additional hardening: only explicit route metadata can bypass authentication; HS256 and required JWT claims are pinned; media HMAC comparisons are constant-time; API responses containing private data are non-cacheable. Production configuration refuses identical/short JWT keys, short media keys, overlapping client audiences, non-HTTPS public URLs, non-exact HTTPS CORS origins, and stdout mail delivery.

## Deployment and compatibility

1. Apply `0029_security_boundaries.sql` before running the new backend. The startup migration runner includes it and remains replay-safe. It adds membership status and transfer snapshots; it does not change existing users' global status or reconstruct historical records from current buyer data.
2. Validate production settings before rollout: four distinct audiences; distinct random JWT secrets of at least 32 characters; media key at least 32 characters; HTTPS public URL; exact HTTPS CORS origins; configured ACS delivery. Do not print secret values. Old production defaults that logged mail now fail startup.
3. Deploy each portal's server routes and client assets together. Keep the externally visible host/origin consistent through the reverse proxy. Configure ingress request-size/time limits in addition to the proxy's 16 MiB streaming cap. Per-IP auth budgets see the portal server unless a separately trusted forwarding design is configured; do not trust browser-supplied forwarding headers.
4. Existing personal users cannot be enrolled by Fleet administrators without consent. The current workflow requires a new dedicated email. Building invitations with explicit acceptance is a separate product enhancement. Existing accepted memberships keep working; suspending one preserves personal login.
5. Previously globally deactivated users stay deactivated: the database cannot distinguish an earlier legitimate platform-admin action from a Fleet action. Review any restoration through the platform-admin workflow. Do not bulk-reactivate accounts.
6. Historical transfer snapshots are intentionally unavailable. Restore historical information only from independently verified pre-transfer backups/audits. New transfers freeze the seller's view, including against later edits/deletes and subsequent owners.
7. Password changes invalidate every old session. Refresh races return one success and one 401; clients must serialize refresh within a session. Cross-tab coordination and deployment-scale load/concurrency remain useful operational checks.
8. Mobile: supply an HTTPS API URL for release; perform Android backup/restore, device transfer and cleartext rejection checks, plus iOS backup/file protection and callback checks on hardware. Ordinary SQLite/document storage still relies on platform isolation and device encryption. App-level encrypted-database migration is not part of this patch and remains optional hardening for stronger device-compromise requirements.

## Validation

- Backend: all 119 tests in 25 files passed, including new BOLA, nested reference, sync limit, refresh reuse, stale Admin, local suspension, transfer privacy and share-limit regressions. A separate production configuration test passed (120 tests total). TypeScript build passed.
- Portals: 16 security/session tests against each portal (32 total), including CSRF, token secrecy, proxy credential/header control, blocked paths and oversized requests. Both production builds passed; Fleet required a retry for its existing Google Fonts download. A local production login response had 15 script tags matching its CSP nonce, with HSTS and private/no-store headers.
- Flutter: 14 targeted transport, session-backoff and network-error tests passed. Analysis of six changed Dart/test files found no issues.
- Database migrations were tested from empty state and replayed by the existing migration suite. PGlite provides local coverage; a multi-connection PostgreSQL concurrency test is still required before production rollout.
- No production penetration test, native hardware backup test, or app-store build was performed. No claim is made that every dependency or deployment setting is vulnerability-free.

CSP follows the [Next.js nonce guidance](https://nextjs.org/docs/app/guides/content-security-policy); layouts render dynamically and their theme initialization script receives the same nonce as the framework scripts. Inline styles remain allowed for the existing component styling; inline scripts do not.
