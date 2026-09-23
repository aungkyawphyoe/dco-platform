# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

Product is production-ready. `product/production-scope.md` is the active scope contract; `product/mvp-scope.md` is the closed Phase 1 record (includes Family Sharing). `product/frd/` holds FRDs for Dashboard, Garage, Auth, Maintenance, Documents, Expenses, Sync, Notifications, Admin, and Family Sharing. `docs/design-system.md` and `docs/theme/garage-minimal-dark.json` are the shared Flutter + web visual tokens.

Implementation docs are in place: `architecture/system.md` (Accepted), `architecture/data-model.md` (Binding), `architecture/iam.md` (Binding), `architecture/openapi.yaml`, `docs/app-shell.md`, `docs/environment-secrets.md`. Admin wireframes live on `wireframes/dco-mobile-wireframes.tldraw` (A1–A7).

Mobile Flutter app is implemented in `mobile/` (Garage Minimal Dark theme, email/password auth, four-tab shell, offline-first sync, family sharing, local-only Notes). Agent contract: [`mobile/AGENTS.md`](mobile/AGENTS.md). Backend is Fastify + Drizzle + PostgreSQL (`docs/adr/backend-stack.md`) on Azure Container Apps (`docs/adr/azure-hosting.md`). Web admin is Next.js 15 (`docs/adr/web-stack.md`) — BFF httpOnly-cookie session, admin dashboard, user management, partner onboarding, family read-only dashboard.

The working plan is: mobile app (Flutter) is the primary surface (Dashboard after login; bottom nav Garage / Maintenance / Expenses / Settings), backend REST API + DB serves mobile and web, web portal handles admin user management, partner onboarding, and family dashboard for Primary Owners.

## Intended project layout

`dco-platform` is planned as a full-stack product spanning web, mobile, and a backend service. The directory structure encodes the intended shape:

- `backend/` — server / API layer
- `web/` — web frontend
- `mobile/` — Flutter owner app (see `mobile/AGENTS.md`)
- `architecture/` — system design / architectural docs
- `product/` — product definitions, requirements
- `prompt/` — prompt definitions or spec-driven artifacts
- `docs/` — documentation
- `wireframes/` — UI wireframes / design mockups

## How to operate here

### Mobile (Flutter)

From `mobile/`:

```bash
flutter pub get
dart run build_runner build
flutter run
flutter test
```

Stack: Flutter, Riverpod, GoRouter, Drift/SQLite, Dio, Freezed. Theme: Garage Minimal Dark. Full rules: `mobile/AGENTS.md`.

### Backend (Fastify)

From `backend/`:

```bash
npm install
npx drizzle-kit migrate
npm run dev
npm test
```

Stack: Node 22, Fastify, Drizzle, PostgreSQL, Zod, Vitest. Contract: `architecture/openapi.yaml`. Theme is not used on the API.

### Web admin (Next.js)

From `web/`:

```bash
npm install
npm run dev
npm test
```

Stack: Next.js 15 App Router, TanStack Query, Tailwind + tokens from `docs/theme/garage-minimal-dark.json`, types generated from `architecture/openapi.yaml`. Session: httpOnly cookies via Route Handler BFF (`/api/auth/*`); see `docs/adr/web-stack.md`.

- Mobile: Flutter owner app, offline-first, JWT audience `dco-owner`
- Backend: REST `/v1` + JWT (Fastify, PostgreSQL, `aud` `dco-owner` / `dco-admin`)
- Web: admin portal (Next.js 15, JWT audience `dco-admin` via BFF)