# API contract (index)

**Showroom handover — 12 November 2026:** [Plan](../product/frd/showroom-handover-plan.md) supersedes the immediate-transfer workflow. OpenAPI and generated clients describe backend handover draft/update/cancel/review/complete operations and the delegated manager permission. The legacy `POST /organizations/{id}/vehicles/{vehicleId}/transfer` returns `410 handover_required`. Fleet Portal and personal-mobile handover journeys, platform-admin correction, and delivery retry remain pending.

Canonical machine file: [`openapi.yaml`](openapi.yaml) (OpenAPI 3.0.3).

- Base path: `/v1`
- Auth: Bearer access JWT. Refresh is a separate call.
- Audiences: `dco-owner` (mobile), `dco-admin` (`/v1/admin/*`), `dco-fleet` (fleet portal), `dco-workshop` (verified workshop accounts). Driver routes under `/v1/drivers/*` accept owner **or** fleet tokens and require an active driver assignment.
- Resource ids: client-generated UUID on create (`id` in the body). Duplicate create with the same id is idempotent.
- Errors: `{ "error": { "code": "string", "message": "string", "details": {} } }`
- Sync: `POST /v1/sync/push` then `GET /v1/sync/changes?cursor=`
- Media: metadata on the parent resource; bytes via `/v1/media`
- Hosting: Azure Container Apps. This contract does not depend on a hostname.

Implement against this file, not against FRD prose. If an FRD and this file disagree on an HTTP shape, update both in the same change.
