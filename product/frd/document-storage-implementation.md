# Document storage implementation progress

Approved design: [Documents and Storage](documents.md).

## Checkpoint 1 — storage foundation

Implemented on `codex/document-storage`:

- Media records persist owning organization and vehicle scope; existing document/receipt references are backfilled without copying file bytes.
- Personal and organization storage usage endpoints use existing plan allowances. Primary document, receipt, and license bytes count once. Profile/vehicle photos are excluded from this document allowance.
- Direct uploads serialize quota admission on the owning account or organization. Idempotent retries do not spend additional allowance. File signatures restrict document uploads to supported images/PDFs and license uploads to images.
- Uploads and document media references validate vehicle scope. Organization media remains behind current membership/assignment checks.
- Personal shared-vehicle recipients cannot mutate documents. Driving licenses are removed from other users' detail responses and denied by the cross-user license endpoint.
- Document deletion queues retriable object cleanup; charged bytes remain until the object has been deleted. Usage refresh retries pending cleanup.
- Mobile sends vehicle scope and a stable upload ID, retains rejected files, and displays pending/waiting-for-space status. Documents shows cached storage usage and the personal license independently of vehicle selection.
- The PDF action now uses a PDF file picker. Camera/gallery images use quality/dimension compression and a post-compression size check.

## Remaining before release

- Multiple attachments on service/fuel records, same-vehicle document picker, reusable links, unlinking, and affected-record deletion confirmation.
- Complete replacement lifecycle, including smaller replacements while over quota, old-version cleanup, and preservation across offline failures.
- Full license lifecycle: required front/optional back, optional expiry, removal from either entry point, replacement cleanup, and offline image availability.
- Fleet portal document UI and platform support permissions, audited access/deletion, reason capture, and owner notifications.
- Temporary-file cancellation cleanup and robust abandoned-upload reconciliation.
- Localized storage messages, personal upgrade navigation when available, and broader device/accessibility verification.
- Production rollout and existing-data reconciliation. No deployment has been performed.

The first checkpoint is not the completed feature. Coordinate backend/mobile rollout: new document and receipt uploads require `purpose` and `vehicle_id`. Older clients that omit these fields must be upgraded before enabling this contract in production.
