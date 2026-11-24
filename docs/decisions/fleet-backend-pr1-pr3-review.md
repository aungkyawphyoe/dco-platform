# Fleet backend review for PR-1 through PR-3

Reviewed 22 November 2026. Scope covers the agreement and reminder code, expense CSV changes, incident code in the working tree, and startup SQL relevant to the production failure. This is a static review of repository code and SQL. Production data, provider delivery, migration execution, and concurrent requests were outside this pass. PR-4 is on hold.

## Verdict

The transactional operations and relational structure are a reasonable foundation. The review found gaps in ownership attribution, export reconciliation, attachment lifecycle, and job execution. Prioritize those gaps over additional fleet features.

## Data flow and table design

| Feature | Write path and read model | Assessment |
| --- | --- | --- |
| PR-1 agreements | A portal role check precedes a transaction that writes an agreement, numbered terms, coverage rows, and audit events. A separate worker reads the latest term and records attempts per term and expiry date. | Agreement identity, renewals, and coverage are correctly separated. Unique term numbers and date checks are enforced. Same-organization references depend on the application writer. |
| PR-2 expenses | Expense writes feed the analytics projection. A delete trigger copies selected fields into a marker. The CSV reads that projection using organization, vehicle, and transaction filters. | One expense ledger is appropriate. The JSON projection is a deliberate form of denormalization for reporting. It currently lacks the ownership and change guarantees needed for reliable incremental reconciliation. |
| PR-3 incidents | The API records the case and attribution, binds staged photos, and adds links to work orders. Closure updates the case and writes an audit event. Reads and photo downloads use case visibility checks. | Separating cases, evidence, and repairs is appropriate. The scope columns in the repair junction are intentional redundancy that lets composite foreign keys enforce tenant and vehicle consistency. Evidence staging and cleanup need a defined lifecycle. |
| Startup | Every backend start runs the SQL files in a fixed order. Legacy migrations were re-creating previously retired columns. | The two new guards address the known replay loops. The runner still has a large replay surface without a general migration ledger. |

## Findings

### P1. Analytics writes derive ownership from the current vehicle link

The reporting contract promises historical organization attribution. The existing analytics trigger chooses an organization from the current vehicle link, and the new deletion trigger uses that same link to select the record to mark. Neither uses the expense's immutable ownership period. If a historical expense can be updated or deleted after transfer through an administrative, maintenance, or future write path, the marker can be skipped for the original organization. The inherited projection can also write a historical record into the current organization's projection on update. This is a database-level dependency in PR-2. Exposure through an ordinary user route has not been established.

Use immutable ownership-period attribution for projection writes and deletion markers. Before changing existing rows, inspect whether any projection already differs from source attribution. Cover transfer, late correction, and delete cases. [Current analytics capture](../../backend/drizzle/0038_analytics_service_items.sql#L7) · [Deletion capture](../../backend/drizzle/0048_expense_export_deletions.sql#L14)

### P1. Re-exporting the old filters cannot reconcile a moved expense

The CSV selects rows by the latest transaction date and category. A correction that changes either can remove the expense from a previously exported period or category. No deletion marker is written because the source row still exists. The same ID and revision can be found under the new filters, but a consumer re-exporting only the old selection sees neither a correction nor a reversal.

Keep the current CSV as a filtered snapshot and define its reconciliation semantics explicitly. If consumers require incremental corrections across filter boundaries, provide a bounded change feed or emit a marker for the previous selection along with the corrected row. The reporting contract also needs to define whether `included_in_total` means inclusion in a reporting-currency total or just an active expense row. [Export filters and markers](../../backend/src/modules/fleet-analytics.ts#L108) · [Spend aggregation](../../backend/src/lib/fleet-analytics.ts#L148)

### P2. Abandoned incident photo uploads consume organization quota

Clients upload evidence to permanent organization storage before creating the case. A cancelled or failed submission can leave the uploaded media without a case link. The storage code protects linked photos, but the upload path does not register abandoned uploads for cleanup. An ordinary retry with the same ID can reuse an upload while the draft remains open, but leaving the screen can strand it.

Add an explicit pending upload state with expiry and a cleanup worker. Link the evidence and clear pending state in the case transaction. Coordinate cleanup with linking under a lock. Define retention for attached evidence separately. [Media upload](../../backend/src/modules/media.ts#L114) · [Incident attach transaction](../../backend/src/modules/fleet-incidents.ts#L163) · [Storage cleanup](../../backend/src/lib/storage.ts#L73)

### P2. Reminder delivery holds database locks across provider I/O

The reminder worker locks the agreement, organization, and recipient while waiting for a network send and provider polling. Slow delivery can delay agreement edits or member deactivation. If the provider accepts a message and the database commit fails, a retry can send it again. The notice key prevents repeat sends after commit. The repository documents an hourly invocation, but contains no fleet agreement scheduler configuration in the inspected deployment files.

Use a durable delivery claim with a short transaction and a retry lease. Send outside the transaction, use provider idempotency where available, and explicitly handle ambiguous delivery outcomes. Add scheduling and monitoring to deployment. [Reminder transaction](../../backend/src/lib/fleet-agreement-reminders.ts#L20) · [Provider call](../../backend/src/lib/mail.ts#L163) · [Job setup](../../backend/README.md#L55)

### P2. Agreement edits can overwrite changes made by another reviewer

The update locks the agreement and checks the expected term number. Editing the current term does not advance that number, so two reviewers editing the same term can both succeed and the later save replaces the earlier term and coverage. A database lock serializes the writes but cannot detect stale input.

Use a revision or conditional update token for term editing. Keep the independent term number for renewals. [Term update](../../backend/src/modules/fleet-agreements.ts#L191)

### P2. Reopening discards the previous incident review note

Closure writes the review note to the case. Reopening clears it and the audit event retains reviewer and timestamp only. A second review can no longer retrieve the first note. Confirm whether notes are part of retained review history. If they are, store review and reopen events with a clear retention policy and expose the permitted history.

[Closure and reopening](../../backend/src/modules/fleet-incidents.ts#L200)

### P2. Several tenant and retention rules depend on API-only validation

Agreement references use standalone foreign keys. A second writer could point a responsible member or document at a different organization. Incident repair links enforce scope in SQL, while incident photo links enforce organization, vehicle, ownership, and purpose only during case creation. The API checks are meaningful. The schema has no equivalent invariant for maintenance scripts, imports, or future writers. Agreement attachments also use `ON DELETE SET NULL`, so retention of an agreement term does not preserve its supporting document.

Use tenant-scoped constraints for stable references wherever possible and define ownership-period and retention rules for evidence on transfer. Reuse one validated write path for rules that cannot be expressed as foreign keys. [Agreement references](../../backend/drizzle/0046_fleet_agreements.sql#L7) · [Incident reference constraints](../../backend/drizzle/0049_fleet_incidents.sql#L27) · [Agreement reference validation](../../backend/src/modules/fleet-agreements.ts#L37)

## Remediation order

1. Resolve projection ownership and define what a CSV re-export guarantees across changes to date and category.
2. Close the incident upload and review history lifecycle gaps. Confirm whether a work order may belong to multiple cases before adding a uniqueness rule. The current junction only prohibits duplicate pairs.
3. Add agreement edit revisions and durable reminder delivery.
4. Rehearse startup against a disposable copy of the production schema. Compare attribute-slot counts before and after repeated startup, check the known fuel collision, and confirm the target revision is serving traffic. Plan a migration ledger separately from the immediate replay guards.
