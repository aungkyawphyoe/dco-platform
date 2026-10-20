# Documents and Storage

## Status and authority

Product decisions approved through the document-storage design interview on 20 October 2026. This specification supersedes the earlier vehicle-only document scope and its completed-status claim. These additions are approved requirements, not a claim that implementation is complete.

Related references: [pricing](../../docs/pricing.md), [organization realignment](mobile-personal-driver-realignment-plan.md), and [vehicle sharing](vehicle-sharing-plan.md). Existing assignment-based download authorization and local cache revocation remain required.

## Ownership and scope

Vehicle documents include insurance, registration, invoice, warranty, receipt, and other. Each ordinary document contains one primary image or PDF and belongs to exactly one vehicle. Insurance files do not create insurance-policy records.

Personal documents belong to a user independently of the selected vehicle. A driving license is a personal document with front and optional back images grouped into one current license. Other personal-document workflows are not added by this specification.

Personal vehicle files consume the vehicle owner's account allowance. Fleet vehicle files consume the organization's allowance, regardless of uploader. Fleet files remain with the organization when a driver leaves. Personal licenses remain user-owned and never become fleet property automatically.

## Documents screen and metadata

Documents is accessible through the existing navigation and vehicle entry points. Show the active vehicle's documents and a separate Personal Documents section for the signed-in user's license. Personal Documents remains accessible without an active vehicle.

Rows show name, category, thumbnail or PDF icon, stored size, date added, optional expiry date, and upload state. Linked service/fuel records are navigable from the document. Vehicle uploads disclose that documents are visible to people with shared access to that vehicle.

Required fields: file, name (default filename, maximum 120 characters), category. Optional fields: notes and expiry date. Ordinary categories are insurance, registration, invoice, warranty, receipt, and other. Driving License is a dedicated personal category, not a category available for vehicle uploads. Expiry dates are displayed; automatic expiry reminders are deferred.

Images open in a full-screen viewer; PDFs open in the platform document viewer. Preserve accessible upload, error, and empty states.

## Uploads and attachments

Accept JPEG, PNG, HEIC images and PDF files only. Compress images before storing the application-managed local copy and uploading, preserving readable document text. PDFs remain unchanged. Enforce a maximum of 15 MB per file after compression, both client-side and server-side. Validate actual file content as well as declared type.

Register Service and Fuel Log support multiple attachments. Offer Upload file and Choose from Documents. Existing-document selection is restricted to the same vehicle and excludes personal documents. Service uploads default to Invoice; fuel uploads default to Receipt, with category editable.

Each new attachment becomes a separate vehicle document. One document can link to multiple service/fuel records for that vehicle. All entry points reference the same stored file, which is charged once; linking never creates another billed copy.

Newly selected files remain temporary until the form is saved. Cancelling a changed form requires confirmation and discards its temporary files, without touching documents selected from the vault. Saving offline creates local records and document links with Pending upload state.

## Driving license

Adding a license is optional when saving user details. A license requires a front image; its back image is optional. The profile and Personal Documents reference the same license. Only the current version is retained.

Replacing either side preserves the old image until its replacement is uploaded successfully. Deleting the license from either entry point requires confirmation and removes it from both. Both stored images count toward the user's allowance.

Licenses are excluded from vehicle sharing and fleet access. Sharing with a fleet requires a future explicit consent feature; it is not part of this release.

## Permissions

| Actor | View/download | Create | Edit/replace/delete |
|---|---|---|---|
| Personal owner | Own vehicle documents and own license | Yes | Yes |
| Shared personal-vehicle recipient | All documents on shared vehicle; no owner's license | No | No |
| Assigned fleet driver | All documents on currently assigned vehicles | Yes, for assigned vehicles | Own uploads only, until an admin correction locks them |
| Fleet admin | Organization vehicle documents; no personal licenses | Yes | Full organization vehicle-document CRUD, audited |
| Platform support role | Authorized support access, audited | No on behalf of user | No editing/replacing |
| Privileged platform deletion role | As separately authorized | No on behalf of user | Delete with reason, audit record, and owner notification |

Personal-license access by platform staff requires a separate sensitive-document permission. It is not included in routine support access.

Fleet admin edits/replacements lock the document against subsequent driver changes. Check permissions consistently through Documents, log attachment actions, profile actions, and direct API requests. Attachment unlinking must not bypass admin locks. Removing an assignment revokes access to its documents; revoke account-scoped local caches using the assignment manifest. Reauthorize organization downloads against current access on every request.

## File lifecycle

Removing an attachment from a log unlinks it only. Deleting a log preserves its documents and removes their links. Vehicle archiving retains documents.

Explicit document deletion is permanent, with no user-facing Trash. Its confirmation identifies affected logs and explains that those records remain. Delete the file from all linked views, subject to authorization and locks. Release storage only after successful deletion; a queued offline deletion does not immediately increase server allowance. Platform deletion also requires a reason and owner notification.

Ordinary file replacement also preserves the old file until its replacement is stored successfully. All linked views then use the replacement. Failed replacement must not lose the previous file.

## Storage and pricing

| Plan | Included storage |
|---|---:|
| Free | 50 MB |
| Lite | 150 MB |
| Standard | 500 MB |
| Fleet | 5 GB |

Use a shared pool per personal account or organization for documents and log attachments; personal licenses consume the personal pool. Charge actual stored primary-file bytes after compression, once per stored file. System-generated thumbnails are not charged. No document-count gate is introduced. Fleet storage add-ons are deferred.

Block uploads that would exceed the allowance. Existing files remain readable/downloadable after exhaustion or downgrade. Permit deletion and replacements that reduce storage, including while over quota. Users can save service/fuel logs without successful attachment upload. Retain rejected offline attachments locally and show Waiting for storage space rather than silently discarding them.

| Role | Full-storage actions |
|---|---|
| Personal owner | Manage storage; Upgrade where a higher personal tier is available |
| Fleet admin | Manage storage; explain that additional storage is not available yet |
| Fleet driver | Show organization usage and Contact your fleet admin; no billing controls |

Personal subscription changes never increase organization storage. The highest personal tier must not advertise an unavailable upgrade. Show current usage, allowance, and actionable failure states.

## Backend implementation requirements

The following are engineering requirements derived from the agreed behavior, not assertions about existing code:

- Separate owning account/organization, uploader, vehicle/personal scope, stored file, and log links. A shared link must not change ownership or billing.
- Support a license aggregate with front/back files and ordinary single-file documents without making license files selectable as vehicle attachments.
- Enforce quota authoritatively on the server with concurrency-safe admission and idempotent upload finalization. Concurrent devices must not overspend the same remaining allowance.
- Reserve capacity for pending uploads, expire abandoned reservations, and reconcile stored bytes. Do not count failed uploads as completed usage.
- Handle replacements using the resulting logical usage so storage-reducing replacements work while over quota. Account for temporary overlap internally without charging both versions permanently.
- Make delete retries idempotent; release charged bytes exactly once following successful file deletion. Maintain retriable cleanup for failed object-store operations.
- Return structured quota errors with owning scope, current usage, allowance, and required bytes. Mobile checks are informative, not the authority.
- Check scope and permissions on metadata, download, replacement, link/unlink, and deletion endpoints. Audit privileged access and fleet mutations without recording file contents.
- Migrate existing vehicle documents without dropping files, changing owners, or counting linked files multiple times. Reconcile baseline usage before enforcing the new gates.

## Implementation sequence

1. Audit current schema, object storage, plan entitlements, sync, and existing portal/mobile flows against this specification. Identify migration and compatibility requirements.
2. Implement file ownership, reusable links, license representation, authoritative quota lifecycle, authorization, and audits in the backend.
3. Add mobile compression/upload handling, service/fuel attachments, personal license integration, Documents views, and role-aware storage states.
4. Add fleet document CRUD and restricted platform-support viewing/deletion with audit and notification behavior.
5. Migrate/reconcile existing files, validate cross-client and offline behavior, and update implementation status only after acceptance checks pass.

## Acceptance scenarios

- One uploaded service invoice appears in its log and Documents; linking it to another same-vehicle log does not increase usage.
- Cross-vehicle and personal-license attachment links are rejected by the backend.
- Image compression preserves readable text; unsupported content and files exceeding the post-compression size limit are rejected.
- Cancelling a draft removes temporary uploads only; saving offline preserves records and attachments across restart.
- Full quota permits saving logs and reading existing files; pending attachments remain visible and retryable after space is freed.
- Concurrent uploads cannot exceed allowance, and retried finalization/deletion cannot double-charge or double-release bytes.
- Downgrading below usage retains existing files and allows deletion or smaller replacements.
- Failed replacements preserve old content; successful replacements update all linked views.
- Unlinking or deleting a log preserves its files; explicit file deletion removes links everywhere and leaves log records intact.
- License creation, replacement, and deletion stay consistent between profile and Personal Documents; vehicle recipients and fleet admins cannot access it.
- Assigned drivers can view all assigned-vehicle documents and mutate only eligible own uploads; admin corrections lock them across every entry point.
- Assignment revocation removes access and cached files while retaining organization ownership and storage usage.
- Platform support cannot edit files; privileged deletion requires a reason and creates the audit/notification records. Sensitive-license access requires its separate permission.

## Deferred

OCR, insurance-policy objects, document annotation, folders, multi-file ordinary documents, license history, automatic expiry reminders, cross-vehicle links, per-document privacy controls for shared vehicles, license sharing with fleets, user-facing Trash, and fleet storage add-ons.
