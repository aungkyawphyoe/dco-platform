# Public API rate limits

Public `/v1` business routes are limited before body parsing, including invalid payloads and invalid tokens. Limits are always enabled, independently of `AUTH_CODES_ENABLED`. All API replicas use atomic PostgreSQL counters in `auth_limits`. This change addresses finding 6 of the 23 October security assessment; other assessment findings are separate work.

## Policy

All rates count attempts, including successes. Windows start at the first request; blocked requests do not extend them. Every public business route shares a per-client-IP aggregate cap of **600 requests/minute**, plus the following per-route IP cap. Routes use the registered path template: changing query parameters, media IDs, or OAuth provider values does not create a fresh budget. GET and POST callbacks share a budget.

| Public route | IP limit |
|---|---|
| Signup | 10/hour |
| Login | 120/minute, plus 20/account/hour |
| Forgot password | 20/hour, plus 5/email/hour |
| Reset password | 20/hour |
| Verify email | 60/hour |
| Refresh | 300/minute |
| Logout | 60/minute |
| Social start | 30/hour |
| Social callback | 60/minute |
| Social complete | 60/hour |
| Recovery code issuance | 30/hour, plus existing email cooldown/hourly limits |
| Recovery code confirmation | 60/hour, plus existing expensive-hash/attempt limits |
| Google Play notifications | 600/minute; Google identity verification is still required |
| Pricing, signed media downloads, and other/new public business routes | 120/minute |

Email and username login aliases use the same account-ID counter. Unknown identifiers use normalized text. Authenticated legacy verification resend is now always limited to 5/account/hour. Existing stricter social/code/account security limits remain in effect.

Health and readiness are explicit exceptions: health must work when the database is down, and readiness performs its own database probe. Protect these at the ingress; the application limiter does not protect them. Development Swagger documentation, CORS preflight, unknown routes, and authenticated business routes are outside this public-route policy. Distributed volumetric attacks require ingress/WAF protection even on limited routes because the application must receive a request and access its shared counter.

## Client contract

Exhausted budgets return HTTP **429**, `error.code=rate_limited`, `details.retry_after`, `Retry-After` in seconds, and `Cache-Control: no-store`. Browser CORS exposes `Retry-After`. Clients should stop automatic retries until the indicated delay, add jitter, and retain refresh/session credentials. A database counter failure returns **503** with a generic error and a 30-second Retry-After; requests do not bypass protection.

Admin and Fleet login/session proxies preserve 429/503 and Retry-After without clearing cookies. Their API clients surface temporary refresh failure instead of continuing with an unauthenticated request. Flutter preserves stored credentials on a rate-limited/unavailable restore and propagates 429/503 from request-time refresh. Existing unrelated session-restoration behavior is unchanged.

## Deployment and operations

- Apply `0028_rate_limit_cleanup.sql` with the existing migration/startup flow. It adds an expiration index; no new service or secret is required.
- Expired counters are pruned in batches of at most 1,000 every minute. Lock skipping supports multiple replicas; only one cleanup job per replica runs at a time. Monitor table growth and cleanup failures during sustained distributed traffic.
- Keys are hashed; counters store neither raw emails/IPs nor tokens. Counter increments saturate after exhaustion instead of growing indefinitely.
- `AUTH_TRUST_PROXY_HOPS` defaults to zero. Set it only to the verified ingress topology and ensure the API cannot be reached through a shorter/untrusted path. Never blindly forward caller-supplied `X-Forwarded-For`. Test a real deployment: clients behind a shared NAT or portal server share IP budgets; account budgets remain separate.
- The login IP cap is intentionally per-minute because portal logins originate from a shared server address. Watch 429s before changing thresholds in `backend/src/lib/rate-limit.ts`; do not turn rate limiting off to resolve NAT contention.
- Pub/Sub retries rejected notifications; monitor Google Play delivery backlog and tune the notification budget to legitimate volume before high-scale rollout.
- Fixed-window limits can permit a burst across a window boundary. Keep edge burst/body/concurrency protections in place. Thresholds are initial operational policy, not a measured capacity guarantee.
- This patch changes local code only. Verify deployed edge limits, probe exposure, forwarding behavior, and workload capacity during rollout.

## Regression coverage

Backend tests cover email-code on/off, pre-validation rejection, login aliases, recovery across IPs, all public route categories, route-template key stability, multiple app instances sharing a database, forwarding-header spoofing, parallel counter increments, expiration/cleanup, and fail-closed behavior. Portal contract tests cover 429/503 status/header preservation and credentials retained during backoff. Mobile tests cover throttled session restoration versus invalid refresh credentials.

Validation on 23 October 2026: full backend suite 113/113 passed; final focused rate-limit suite 10/10 passed (including one subsequently added new-route regression). Both portal contract suites passed 13/13, and the four Flutter session-backoff tests and eight existing network-error tests passed. Backend build, both portal TypeScript checks, OpenAPI client generation, and targeted Flutter analysis passed. Multi-instance counter tests used shared PGlite; production ingress/load testing remains a deployment check.
