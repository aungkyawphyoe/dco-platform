# API contract (index)

Canonical machine file: [`openapi.yaml`](openapi.yaml) (OpenAPI 3.0.3).

- Base path: `/v1`
- Auth: Bearer access JWT. Refresh is a separate call.
- Audiences: `dco-owner` (mobile), `dco-admin` (`/v1/admin/*`).
- Resource ids: client-generated UUID on create (`id` in the body). Duplicate create with the same id is idempotent.
- Errors: `{ "error": { "code": "string", "message": "string", "details": {} } }`
- Sync: `POST /v1/sync/push` then `GET /v1/sync/changes?cursor=`
- Media: metadata on the parent resource; bytes via `/v1/media`
- Hosting: Azure Container Apps. This contract does not depend on a hostname.

Implement against this file, not against FRD prose. If an FRD and this file disagree on an HTTP shape, update both in the same change.
