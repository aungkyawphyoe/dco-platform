# DCO API

Phase 1 REST API (`/v1`) for the Digital Car Ownership platform.

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
