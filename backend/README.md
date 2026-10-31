# AutoX API

Phase 1 REST API (`/v1`) for the AutoX platform.

Contract: [`architecture/openapi.yaml`](../architecture/openapi.yaml). Stack: [`docs/adr/backend-stack.md`](../docs/adr/backend-stack.md).

## Local

```bash
cp .env.example .env
docker compose up -d postgres
npm install
npm run db:migrate
npm run dev
npm test
```

API listens on `http://localhost:8080/v1`. Health: `GET /v1/health`.

**Swagger UI:** `http://localhost:8080/docs` — served from [`architecture/openapi.yaml`](../architecture/openapi.yaml) (single source of truth, never generated). Click **Authorize**, paste an access token (from `POST /auth/login`), then use **Try it out**. Dev only — disabled when `APP_ENV=prod`. Override the spec location with `OPENAPI_SPEC_PATH` if needed.

Bootstrap admin comes from `BOOTSTRAP_ADMIN_EMAIL` / `BOOTSTRAP_ADMIN_PASSWORD`. Rotate after first login.

## Azure (deploy later)

IaC is in `azure.yaml` and `infra/`. First deploy:

```bash
azd auth login
azd env new dev
azd env set POSTGRES_PASSWORD '<url-safe-password>'
azd env set JWT_ACCESS_SECRET '<32+ chars>'
azd env set JWT_REFRESH_SECRET '<32+ chars>'
azd env set MEDIA_SIGNING_KEY '<32+ chars>'
azd env set BOOTSTRAP_ADMIN_EMAIL 'admin@example.com'
azd env set BOOTSTRAP_ADMIN_PASSWORD '<rotate-immediately>'
# then: azd up
```

ACS Email domain verification is manual after the Communication Service exists. Until then, local `MAIL_PROVIDER=stdout` is enough.

## Pre-launch subscription cleanup

Migration `0033_test_account_billing_cleanup.sql` runs once on backend startup
(or with `npm run db:migrate`). It moves existing unmanaged personal test
accounts to subscription-managed Free and completes billing migration for
existing organizations. Active subscription terms, Google Play purchases, and
promotional gifts continue to provide access. Organizations without an active
term become read-only; account and vehicle records are retained.

No admin review or manual SQL is needed. To give a test account paid access,
record a direct or complimentary subscription in the admin portal. The migration
has a completion marker so subsequent restarts do not repeat this cleanup.
