# DCO Platform — Deployment Guide

## Overview

Three Next.js 15 apps + one Fastify API deployed to Azure Container Apps:

| App | Container App | Domain | Port | Purpose |
|-----|---------------|--------|------|---------|
| **API** | `dco-api-24739` | api.autoxmm.com | 8080 | Fastify REST API |
| **Admin Web** | `dco-admin-web` | admin.autoxmm.com | 3000 | Admin portal (BFF, httpOnly cookies) |
| **Fleet Portal** | `dco-fleet-portal` | fleet.autoxmm.com | 3000 | Fleet management (JWT `dco-fleet`) |
| **Marketing Site** | `dco-site` | www.autoxmm.com | 3000 | Public site (no auth) |

All apps share ACR `dcoacr24739`, run in `dco-env-24739` (Southeast Asia), Consumption workload profile.

---

## Prerequisites

- Azure CLI (`az`) logged in, subscription `58ba6f9b-1144-44cb-92c7-18e4bda5a6e2`
- Resource group: `dco-rg`
- ACR: `dcoacr24739`
- Container Apps env: `dco-env-24739`

---

## Build & Deploy Pattern (All Apps)

```bash
# 1. Build & push to ACR
az acr build --registry dcoacr24739 --image <repo>:<tag> --image <repo>:latest .

# 2. Deploy new revision
az containerapp update --name <container-app> --resource-group dco-rg --image dcoacr24739.azurecr.io/<repo>:<tag>

# 3. Verify
curl -s https://<app>.wonderfulplant-4ba5225f.southeastasia.azurecontainerapps.io/health
```

---

## Per-App Details

### 1. API (Fastify) — `dco-api-24739`

**Source:** `/backend`

**Build:**
```bash
cd backend
az acr build --registry dcoacr24739 --image dco-api:v1.7.1 --image dco-api:latest .
```

**Deploy:**
```bash
az containerapp update --name dco-api-24739 --resource-group dco-rg --image dcoacr24739.azurecr.io/dco-api:v1.7.1
```

**Required env/secrets (managed in portal or `az containerapp update`):**
- Secrets (Key Vault / Container App secrets):
  - `database-url` — Postgres `postgres://...?sslmode=require`
  - `jwt-access-secret` — 64-char hex
  - `jwt-refresh-secret` — 64-char hex
  - `media-signing-key` — 32+ char
- Env vars:
  - `APP_ENV=prod`
  - `PORT=8080`
  - `JWT_OWNER_AUD=dco-owner`
  - `JWT_ADMIN_AUD=dco-admin`
  - `JWT_ACCESS_TTL=15m`
  - `JWT_REFRESH_TTL=720h`
  - `MAIL_PROVIDER=stdout`
  - `MAIL_FROM=noreply@localhost`
  - `MEDIA_DRIVER=local`
  - `LICENSE_KID=lic-2026-10-09`
  - `LICENSE_ED25519_KEY=<base64 private key>`
  - `LICENSE_TTL_DAYS=365`
  - `BOOTSTRAP_ADMIN_EMAIL=admin@example.com`
  - `BOOTSTRAP_ADMIN_PASSWORD=<rotate after first deploy>`
  - `PUBLIC_API_URL=https://api.autoxmm.com/v1`
  - `CORS_ORIGINS=https://admin.autoxmm.com,https://fleet.autoxmm.com,https://www.autoxmm.com`

**Migration:** Runs automatically on startup via `migrate.ts` (executes `0000_init.sql` through latest). Or manual:
```bash
DATABASE_URL="<prod-url>" npm run db:migrate
```

**License key generation (one-time, store in Key Vault):**
```bash
npm run license:key
# Outputs LICENSE_KID, LICENSE_ED25519_KEY, and mobile keyring JSON
```

---

### 2. Admin Web (Next.js 15) — `dco-admin-web`

**Source:** `/web`

**Build:**
```bash
cd web
npm run gen:api   # generates types from architecture/openapi.yaml
npm run build
az acr build --registry dcoacr24739 --image dco-admin-web:v1.0.0 --image dco-admin-web:latest .
```

**Deploy:**
```bash
az containerapp update --name dco-admin-web --resource-group dco-rg --image dcoacr24739.azurecr.io/dco-admin-web:v1.0.0
```

**Auth:** BFF via Route Handlers (`/api/auth/*`) → httpOnly cookies (`dco_admin_access`, `dco_admin_refresh`). Proxies to API with `Audience: dco-admin`.

**Env vars:**
- `NEXT_PUBLIC_API_BASE_URL=https://api.autoxmm.com/v1`
- `API_BASE_URL=https://api.autoxmm.com/v1` (server-side)

**Notes:**
- `next.config.ts` rewrites `/api/auth/*` to API
- Uses design tokens from `docs/theme/garage-minimal-{dark,light}.json` via Tailwind v4

---

### 3. Fleet Portal (Next.js 15) — `dco-fleet-portal`

**Source:** `/fleet-portal`

**Build:**
```bash
cd fleet-portal
npm run gen:api
npm run build
az acr build --registry dcoacr24739 --image dco-fleet-portal:v1.0.0 --image dco-fleet-portal:latest .
```

**Deploy:**
```bash
az containerapp update --name dco-fleet-portal --resource-group dco-rg --image dcoacr24739.azurecr.io/dco-fleet-portal:v1.0.0
```

**Auth:** BFF login posts `surface: "fleet"` → API returns `dco-fleet` JWT. Cookies: `dco_fleet_access`, `dco_fleet_refresh`.

**Env vars:**
- `NEXT_PUBLIC_API_BASE_URL=https://api.autoxmm.com/v1`
- `API_BASE_URL=https://api.autoxmm.com/v1`

---

### 4. Marketing Site (Next.js 15) — `dco-site`

**Source:** `/site`

**Build:**
```bash
cd site
npm run gen:theme   # copies design tokens to Tailwind config
npm run build
az acr build --registry dcoacr24739 --image dco-site:v1.0.0 --image dco-site:latest .
```

**Deploy:**
```bash
az containerapp update --name dco-site --resource-group dco-rg --image dcoacr24739.azurecr.io/dco-site:v1.0.0
```

**No auth.** Public pages: `/`, `/personal`, `/fleet`, `/pricing`, `/faq`.

**Env vars:**
- `NEXT_PUBLIC_API_BASE_URL=https://api.autoxmm.com/v1` (for pricing fetch)
- `NEXT_PUBLIC_APP_STORE_URL=https://apps.apple.com/...`
- `NEXT_PUBLIC_PLAY_STORE_URL=https://play.google.com/...`

**Pricing page:** Server-fetches `GET /v1/pricing` with fallback to `src/content/pricing-fallback.ts`.

**Design tokens:** `docs/theme/garage-minimal-{dark,light}.json` → Tailwind v4 via `gen:theme`.

---

## Custom Domains

| App | Custom Domain | Binding |
|-----|---------------|---------|
| API | api.autoxmm.com | SniEnabled, managed cert |
| Admin | admin.autoxmm.com | SniEnabled, managed cert |
| Fleet | fleet.autoxmm.com | SniEnabled, managed cert |
| Site | www.autoxmm.com | SniEnabled, managed cert |
| Site | autoxmm.com | Disabled (redirect via Cloudflare/Pages) |

Managed certs provisioned in `dco-env-24739` (`mc-dco-env-24739-...`).

---

## Verification Checklist

After each deploy:

```bash
# API
curl -s https://api.autoxmm.com/v1/health      # {"status":"ok"}
curl -s https://api.autoxmm.com/v1/ready        # {"status":"ready"}

# Admin Web
curl -s https://admin.autoxmm.com/health        # 200 (static page)

# Fleet Portal
curl -s https://fleet.autoxmm.com/health        # 200

# Marketing Site
curl -s https://www.autoxmm.com/                # 200
```

---

## Rollback

```bash
# List revisions
az containerapp revision list --name <app> --resource-group dco-rg

# Set traffic to previous revision
az containerapp ingress traffic set --name <app> --resource-group dco-rg --revision-weight <old-revision>=100
```

---

## Common Issues

| Issue | Fix |
|-------|-----|
| `ECONNREFUSED` on migrate | Use `DATABASE_URL="<prod>" npm run db:migrate` from local; prod PG blocks public access |
| 401 on new endpoint | Check `publicPaths` in `auth.ts` or `config: { public: true }` on route |
| License 500 | Missing `LICENSE_ED25519_KEY` env var; run `npm run license:key` |
| CORS error | Update `CORS_ORIGINS` secret + redeploy API |
| Build fails (types) | Run `npm run gen:api` in web/fleet-portal after API OpenAPI changes |

---

## Secrets Rotation

1. Generate new values (JWT secrets, DB password, license key)
2. Update in Azure Portal → Container Apps → Secrets
3. `az containerapp update --name <app> --resource-group dco-rg` (no image change needed)
4. New revision picks up secrets automatically

---

## CI/CD (Future)

GitHub Actions workflow should:
1. Build & push each app to ACR on merge to `main`
2. Run `az containerapp update` for each app
3. Run smoke tests against new revision before 100% traffic shift