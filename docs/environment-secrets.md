# Environment and secrets (draft)

**Status:** Draft. Do not treat values here as real credentials. Azure VPS provisioning is **later** — this file only names what that machine will need.

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

Placeholders only. Store in a secret manager or the VPS env file (`chmod 600`), not in git.

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
| `MAIL_PROVIDER` | API | Draft: unset. Candidates: Azure Communication Services, Postmark, SES. |
| `MAIL_API_KEY` | API | Provider secret. |
| `MAIL_FROM` | API | e.g. `noreply@<domain>` |
| `MEDIA_DRIVER` | API | Draft: `local` in local env; `azure_blob` in stage/prod later. |
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
| `VITE_API_BASE_URL` (or stack equivalent) | Per env |
| No signing keys in the browser bundle | |

---

## Who holds signing keys

| Key | Holder | Not held by |
|-----|--------|-------------|
| JWT access / refresh secrets | API process env on the VPS (later) | Flutter app, admin JS, git, chat logs |
| TLS cert private key | Reverse proxy on the VPS | Application code |
| Blob account key / managed identity | API (managed identity preferred on Azure) | Clients |
| Mail API key | API | Clients |
| Store signing keys (Play / Apple) | Human operator / CI later | This repo |

Local dev may use generated secrets in an ignored `.env`. Prod keys are generated on the VPS or in Azure Key Vault when that guide is written.

---

## Email

MVP needs verification and password-reset mail (`product/frd/auth.md`). Provider is **not chosen**. Until then, `local` may log the link to stdout.

---

## Media bucket

MVP needs object storage for photos and PDFs. Draft:

- `local`: disk directory under the API working dir (gitignored).
- `stage` / `prod`: Azure Blob in the same subscription as the VPS.

The data model stores `blob_key`, not a vendor URL, so the driver can change.

---

## Azure VPS (later)

When you are ready, a follow-up setup should cover:

1. Region, VM size, disk, NSG (22/80/443 only as needed).
2. DNS + TLS reverse proxy in front of the API.
3. Docker Compose or systemd unit, migrations on deploy.
4. Env file or Key Vault references for the table above.
5. Backups for the database; Blob lifecycle for media.
6. How to rotate JWT secrets without kicking every user off (dual-key window).

Do not start that work until the backend stack ADR picks language and database.

---

## Checklist before first deploy

- [ ] Distinct secrets per env
- [ ] `.env` and `*.pem` in `.gitignore`
- [ ] Bootstrap admin password rotated
- [ ] Mail from-address verified at the provider
- [ ] Blob container not public-listable
- [ ] CORS locked to the admin origin
