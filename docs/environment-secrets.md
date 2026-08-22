# Environment and secrets

**Status:** Draft placeholders. Do not treat values here as real credentials. Azure secrets live in Key Vault (`docs/adr/azure-hosting.md`). Local uses an ignored `.env`.

---

## Environments

| Name | Purpose | API | Clients |
|------|---------|-----|---------|
| `local` | Developer laptop | localhost | Flutter debug, admin on localhost |
| `dev` | Shared sandbox (optional) | `api-dev.*` | Internal builds |
| `stage` | Pre-prod | `api-stage.*` | Store-like builds, staff admin |
| `prod` | Real users | `api.*` | Store + admin |

Each environment has its **own** JWT keys, database, blob container, and mail from-address. Never reuse prod refresh-token secrets in local.

---

## Secret inventory

Placeholders only. Store in Key Vault (Azure) or a local ignored `.env` (`chmod 600`), not in git.

| Variable | Who uses it | Notes |
|----------|-------------|--------|
| `APP_ENV` | API | `local` \| `dev` \| `stage` \| `prod` |
| `DATABASE_URL` | API | Connection string. Local may be Docker Postgres. |
| `JWT_ACCESS_SECRET` | API | Signs owner + admin access tokens. Rotate by minting a new key and dual-verifying for one TTL. |
| `JWT_REFRESH_SECRET` | API | Separate from access secret. |
| `JWT_ACCESS_TTL` | API | Draft: `15m` |
| `JWT_REFRESH_TTL` | API | Draft: `720h` (30 days) |
| `JWT_OWNER_AUD` | API / mobile | Draft: `dco-owner` |
| `JWT_ADMIN_AUD` | API / web | Draft: `dco-admin` |
| `BOOTSTRAP_ADMIN_EMAIL` | API once | Seed first admin. Remove or disable after first login. |
| `BOOTSTRAP_ADMIN_PASSWORD` | API once | Single-use. Rotate immediately. |
| `MAIL_PROVIDER` | API | `stdout` (local) or `acs` (Azure Communication Services Email). |
| `MAIL_API_KEY` | API | ACS connection string or key when `MAIL_PROVIDER=acs`. |
| `MAIL_FROM` | API | e.g. `noreply@<domain>` |
| `MEDIA_DRIVER` | API | `local` on a laptop; `azure_blob` on Azure. |
| `AZURE_STORAGE_CONNECTION_STRING` | API | When Blob is on. |
| `AZURE_BLOB_CONTAINER` | API | Separate containers per env. |
| `MEDIA_SIGNING_KEY` | API | For short-lived download URLs if not using native Blob SAS. |
| `CORS_ORIGINS` | API | Admin web origin(s) only. Mobile does not need CORS. |
| `SENTRY_DSN` or equivalent | API / clients | Optional until first slice ships. |
| `PUSH_PROVIDER_*` | API | Register device tokens now; **do not send campaigns**. Keys can wait. |

Mobile (`--dart-define` or flavor config, not committed secrets):

| Variable | Notes |
|----------|--------|
| `API_BASE_URL` | Per flavor |
| `JWT_OWNER_AUD` | Must match server |

Web admin:

| Variable | Notes |
|----------|--------|
| `NEXT_PUBLIC_API_BASE_URL` | Per env, includes the `/v1` prefix (see `docs/adr/web-stack.md`) |
| No signing keys in the browser bundle | |

---

## Who holds signing keys

| Key | Holder | Not held by |
|-----|--------|-------------|
| JWT access / refresh secrets | Key Vault → Container Apps | Flutter app, admin JS, git, chat logs |
| TLS cert private key | Container Apps ingress | Application code |
| Blob account key / managed identity | API (managed identity preferred on Azure) | Clients |
| Mail API key | API | Clients |
| Store signing keys (Play / Apple) | Human operator / CI later | This repo |

Local dev may use generated secrets in an ignored `.env`. Prod keys are generated in Azure Key Vault.

---

## Email

MVP needs verification and password-reset mail (`product/frd/auth.md`). Provider: **stdout** locally; **Azure Communication Services Email** on Azure.

---

## Media bucket

MVP needs object storage for photos and PDFs. Draft:

- `local`: disk directory under the API working dir (gitignored).
- `stage` / `prod`: Azure Blob in the same subscription as the Container App.

The data model stores `blob_key`, not a vendor URL, so the driver can change.

---

## Azure (Container Apps)

IaC: `azure.yaml` + `infra/`. First deploy (`azd up`) should cover:

1. Subscription and region (`azd env`).
2. Key Vault secrets for the table above.
3. Migrations on container start (or a release job).
4. Blob lifecycle for media; PostgreSQL backups.
5. JWT rotation with a dual-key window so existing access tokens still verify.

Local: `backend/.env` + Docker Compose Postgres. See `docs/adr/azure-hosting.md`.

---

## Checklist before first deploy

- [ ] Distinct secrets per env
- [ ] `.env` and `*.pem` in `.gitignore`
- [ ] Bootstrap admin password rotated
- [ ] Mail from-address verified at the provider
- [ ] Blob container not public-listable
- [ ] CORS locked to the admin origin
