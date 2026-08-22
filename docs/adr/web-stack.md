# ADR: Web admin portal stack

**Status:** Accepted
**Date:** 2026-08-22
**Closes:** Web framework decision in `docs/implementation-readiness.md`

## Context

The web surface is internal staff only: login, dashboard counts, user management, partner records (`product/frd/admin.md`, routes in `docs/app-shell.md` "Web admin IA"). It is online-only and never touches the mobile sync engine. The backend contract is REST `/v1` + JWT with audiences `dco-owner` / `dco-admin` (`architecture/openapi.yaml`). Hosting is Azure Container Apps (`docs/adr/azure-hosting.md`). Visual tokens are shared via `docs/theme/garage-minimal-dark.json`.

The API returns tokens in the JSON response body only — there is no cookie support on Fastify. Two separate Container App FQDNs make cross-domain cookies unusable.

## Decision

| Concern | Choice |
|---------|--------|
| Framework | Next.js 15 (App Router, TypeScript) |
| Rendering | Mostly client components; server components for guarded shells |
| Data fetching | TanStack Query against Fastify `/v1/admin/*` with Bearer access token |
| Validation | Zod, aligned to the OpenAPI contract |
| Types | Generated from `architecture/openapi.yaml` via `openapi-typescript` |
| Styling | Tailwind consuming CSS vars generated from `garage-minimal-dark.json` |
| Fonts | `next/font/google`: Barlow, IBM Plex Sans, IBM Plex Mono (self-hosted at build) |
| Session storage | httpOnly cookies set by a Next.js Route Handler BFF (`/api/auth/*`) |
| Access token | Memory-only in the browser; silent renewal through the BFF |
| Tests | Vitest + MSW against the OpenAPI contract |
| Hosting | Second Azure Container App in the existing environment; standalone Node build |

### Session model (BFF)

```
Browser ── same-origin ──► Next /api/auth/login ── server-side ──► POST /v1/auth/login
        ◄── Set-Cookie dco_admin_access (15m, httpOnly)
                      dco_admin_refresh (30d, httpOnly, Secure, SameSite=Lax)
Browser ── Bearer from memory ──► Fastify /v1/admin/*  (CORS allows web origin)
```

The browser never holds the refresh token in JS; cookies are first-party because the BFF is same-origin. On reload, middleware sees the refresh cookie and hydrates a session before protected render.

One small backend addition was required: `POST /auth/logout` now also accepts `{refresh_token}` without a bearer token so the BFF can revoke server-side after the access token has expired.

## Consequences

- `web/` is a second standalone Node package in this monorepo.
- No SSR benefit is assumed for data; Next.js was chosen for its router, middleware guards, route handlers as BFF, and first-class fonts/images.
- Deploy order matters: the web container receives `API_BASE_URL` from the api service's `apiUrl` output.
- `CORS_ORIGINS` must include the web FQDN for direct Bearer calls to `/v1/admin/*`.
- Admin analytics events (`admin_signed_in`, …) remain client-side concerns per `product/frd/admin.md`.
- Vite + React SPA was rejected mainly because it cannot host the same-origin BFF that makes httpOnly refresh tokens practical without backend cookie work.

## Alternatives considered

- Vite + React SPA + localStorage — simplest build; rejected on refresh-token exposure in JS.
- Backend Set-Cookie sessions on Fastify directly — cross-site cookies between two Container App domains; needs CSRF handling; more backend change.
- Azure Static Web Apps hosting — fine for an SPA, but the chosen session model requires a Node server, so a Container App matches `docs/adr/azure-hosting.md` anyway.
