# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

Product is in MVP definition. `product/mvp-scope.md` is the Phase 1 contract. `product/frd/` holds FRDs for Dashboard, Garage, Auth, Maintenance, Documents, Expenses, Sync, Notifications, and Admin. `docs/design-system.md` and `docs/theme/garage-minimal-dark.json` are the shared Flutter + web visual tokens.

Must-have implementation docs are in place: `architecture/system.md`, `architecture/data-model.md`, `architecture/iam.md`, `architecture/openapi.yaml`, `docs/app-shell.md`, `docs/environment-secrets.md` (draft). Admin wireframes live on `wireframes/dco-mobile-wireframes.tldraw` (A1–A6).

Mobile Flutter app is scaffolded in `mobile/` (Garage Minimal Dark theme, email/password auth, four-tab shell). Agent contract: [`mobile/AGENTS.md`](mobile/AGENTS.md). Backend is Fastify + Drizzle + PostgreSQL (`docs/adr/backend-stack.md`) on Azure Container Apps (`docs/adr/azure-hosting.md`). Web framework ADR is still open.

The working plan is: mobile app (Flutter) is the primary surface (Dashboard after login; bottom nav Garage / Maintenance / Expenses / Settings), backend REST API + DB serves mobile and web, web portal handles admin user management and partner onboarding.

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

- Mobile: Flutter owner app, offline-first, JWT audience `dco-owner`
- Backend: REST `/v1` + JWT (Fastify, PostgreSQL, `aud` `dco-owner` / `dco-admin`)
- Web: admin portal (framework not chosen)