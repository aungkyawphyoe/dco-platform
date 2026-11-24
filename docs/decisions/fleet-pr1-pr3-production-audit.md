# Fleet PR-1 through PR-3 production audit

Reviewed the changes since `3a97e26`, including the PR-3 mobile and portal working-tree changes. PR-4 remains on hold. This review covers source, schema, migrations, deployment files, and the local static checks listed below.

## Release findings

### P1. Analytics totals mix currencies while the portal says they are excluded

The analytics calculation sums every expense returned for the period. Amounts tagged with different currencies are added without conversion. The backend warning describes that behavior, but the portal tells users that foreign-currency amounts are excluded from every total and comparison. The expense CSV also marks all active expense rows as included in the total. As a result, a dashboard amount can look like a single currency total even when its inputs span several currencies.

Keep original amounts and currencies in the itemized export. Apply the fleet-currency rule consistently to totals, comparison charts, and the inclusion flag, or explicitly revise and approve the reporting contract. [Calculation](../../backend/src/lib/fleet-analytics.ts#L147) · [Portal calculation notes](../../fleet-portal/src/app/(fleet)/analytics/page.tsx#L1271) · [CSV inclusion flag](../../backend/src/modules/fleet-analytics.ts#L114)

### P1. Expense export inherits current-link ownership and has incomplete change semantics

The analytics capture trigger and deletion marker use the vehicle's current organization link rather than the source record's ownership period. Historical corrections after a transfer are therefore unsafe at the projection boundary. Ordinary-user reachability was not established. Separately, a correction can move an expense outside a previously exported date or category filter with no marker in the old selection. A stable ID helps if the consumer reads both selections. It does not make an incremental re-export complete.

Make source ownership periods authoritative for projection writes, audit existing projection discrepancies, and define the CSV as a replaceable scoped snapshot unless an incremental change contract is implemented. [Capture trigger](../../backend/drizzle/0038_analytics_service_items.sql#L7) · [Deletion migration](../../backend/drizzle/0048_expense_export_deletions.sql#L3) · [Prior backend review](fleet-backend-pr1-pr3-review.md#findings)

### P1 if reminder delivery is in release scope. The documented scheduler command cannot run in the production image

The backend image installs only production dependencies and ships compiled files in `dist`. The documented command calls `tsx` with a `src` path. Neither is present in that image. The reminder is a standalone process, and repository deployment files do not configure a scheduler for it. Deploying the API and portal alone leaves agreement reminders unsent.

Use the compiled worker as the scheduler entry point and check delivery in the deployed environment. The worker also holds database locks during provider I/O and can retry an accepted send after a failed commit. That limitation needs to be addressed or explicitly accepted before promising reliable delivery. [Image](../../backend/Dockerfile#L10) · [Command](../../backend/package.json#L19) · [Worker transaction](../../backend/src/lib/fleet-agreement-reminders.ts#L20)

### P2. Accident evidence can be orphaned or silently omitted after an ambiguous retry

The mobile form uploads photos before creating the incident. Failed or abandoned submissions can leave unlinked, quota-consuming media. If the incident is committed but the response is lost, the form permits edits, then retries with the same ID. The server returns the original record when the ID, reporter, organization, and vehicle match. It does not compare the new description, event time, or photo list. The client can announce success for the original report while the driver's changes were never saved.

Treat the ID as the identifier of one immutable submission attempt. Compare the retry payload with the first accepted payload or give the client a way to confirm the first outcome before editing. Pair this with pending evidence expiry and atomic attachment. [Mobile submission](../../mobile/lib/features/fleet/presentation/screens/driver_report_issue_screen.dart#L185) · [Server replay](../../backend/src/modules/fleet-incidents.ts#L148)

### P2. Agreements can silently detach evidence while editing coverage

Unchecking any covered vehicle clears the selected document, including when the document belongs to a vehicle that remains covered. Saving then writes a null document reference. Term history only shows an opaque document ID, so there is no direct way to open an attachment from the detail dialog.

Retain the attachment's vehicle identity in the form and clear it only when that vehicle is removed or the user explicitly removes the attachment. Provide a document action under the agreement's authorization rules. [Coverage controls](../../fleet-portal/src/app/(fleet)/agreements/page.tsx#L242) · [Term history](../../fleet-portal/src/app/(fleet)/agreements/page.tsx#L135)

## Architecture assessment

- Keep the unified Driver Report Issue form. The routing boundary is the selected type. Accident creates an incident, and the other choices create work orders. The two backend records have different lifecycles. A combined persistence model would force repair state onto incident reviews.
- Keep the combined Reports feed as a presentation model. Its current work-order, inspection, and incident readers remain authoritative. Incident pagination mixes loaded cases with the other records and resorts as pages arrive. If strict server-side cursor order across all three sources becomes necessary, introduce a read projection then.
- Keep the portal's full-width tables and native dialogs. The list and detail responsibilities are clear. Agreement terms and coverage rows, and incident cases and repair links, are sound relational boundaries. Prioritize correctness at those boundaries over dividing the pages into more components.
- The startup replay guards address the two observed add/drop cycles. The runner still replays historical SQL. A production-shaped restore rehearsal is the missing evidence for the patched fuel migration and repeated startup. The live database was not inspected in this review.
- The prior lower-priority findings remain open, including agreement edit revisions, incident review history on reopen, and stronger database enforcement for tenant-scoped references.

## Verification and release recommendation

Backend TypeScript, Fleet Portal TypeScript and targeted ESLint, targeted Dart analysis, and the diff whitespace check passed. This pass did not run the deployed browser or Driver app, execute the revised migration against a restored database, or send a real reminder.

Hold the affected finance reporting and reminder behavior until their release findings have a decision and a verified fix or an explicit scope deferral. For PR-3, prioritize the evidence retry path and confirm the merged Driver form, photo access, combined Reports feed, and portal dialogs before releasing the corresponding clients.

## Remediation

- Analytics totals and vehicle summaries use the fleet currency. Itemized exports preserve source amounts and currency tags. Finance should replace each previous export for the same filter selection. [Reporting and reconciliation contract](../../architecture/fleet-analytics.md)
- Migration 0050 attributes accounting mirrors, projection updates, and expense deletion markers to source ownership periods. It keeps provably mismatched legacy rows out of reports and guards the legacy startup SQL against reinstalling the old triggers. The reporting contract contains the read-only query for inspecting existing production projections, including legacy derived expenses with missing attribution.
- Migration 0051 records an immutable submission fingerprint. Identical incident retries return the accepted case. Changed submissions return a conflict. The media cleanup worker removes unlinked incident uploads after 24 hours and rechecks eligibility before deleting.
- Agreement coverage edits retain attachments on vehicles that remain covered. Agreement term history can download scoped files after a transfer.
- The reminder command runs compiled JavaScript and connects without replaying database migrations. Reminder email rollout remains deferred. The production scheduler, provider delivery, and send retries after an ambiguous provider response remain open.

Before production rollout, rehearse migration replay on a restored production database and inspect the ownership discrepancy query. The browser and Driver app walkthroughs and real reminder delivery check remain pending. PR-4 remains on hold.
