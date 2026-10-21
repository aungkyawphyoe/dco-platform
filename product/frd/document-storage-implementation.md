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

## Checkpoint 2 — multiple log attachments

- Service and fuel forms now share an attachment editor: camera, gallery, PDF, or an existing same-vehicle document. New files default to Invoice/Receipt and their names/categories can be edited before saving.
- Log and document/outbox writes save in one local transaction. Unsaved attachment cancellation requires confirmation and discards only newly copied files.
- Document links persist in mobile schema 24 and backend `document_links`, with same-vehicle/record permission checks and cascading link removal. Legacy service receipts migrate once without duplicate bytes.
- Removing a file from a form unlinks it. Explicit document deletion checks affected records and clears legacy receipt pointers. Documents lists linked records for navigation and deletion confirmation.
- Backend link and migration tests, plus mobile offline linking/rollback tests, cover the new data lifecycle. Device UI verification is still pending.

## Checkpoint 3 — Fleet document management

- Fleet admins can upload images/PDFs, download, edit document metadata, and permanently delete files from vehicle details. The panel displays organization storage usage and lists affected log attachments before deletion.
- Writes use record revisions; successful admin document mutations create transactional audit events. A backend integration test covers audit records, stale revisions, admin correction locks, and portal role restrictions.
- Portal TypeScript and targeted ESLint checks pass. Browser/device verification and file replacement remain pending.

## Remaining before release

- Complete replacement lifecycle, including smaller replacements while over quota, old-version cleanup, and preservation across offline failures.
- Full license lifecycle: required front/optional back, optional expiry, removal from either entry point, replacement cleanup, and offline image availability.
- Platform support permissions, audited access/deletion, reason capture, and owner notifications.
- Temporary-file cancellation cleanup and robust abandoned-upload reconciliation.
- Localized storage messages, personal upgrade navigation when available, and broader device/accessibility verification.
- Production rollout and existing-data reconciliation. No deployment has been performed.

The first checkpoint is not the completed feature. Coordinate backend/mobile rollout: new document and receipt uploads require `purpose` and `vehicle_id`. Older clients that omit these fields must be upgraded before enabling this contract in production.
