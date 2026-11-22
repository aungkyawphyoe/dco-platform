# Customer fleet feature PR-0 discovery record

Date: 22 November 2026

Status: In progress. Repository behavior and public reference material have been reviewed. Customer agreement examples and live workflow demonstrations remain open. The first expense delivery is an Excel-compatible report, not an ERP connector. Do not start feature implementation from this record yet.

Source decisions: [Customer fleet feature improvements](customer-fleet-feature-improvements.md) and [implementation plan](customer-fleet-feature-implementation-plan.md).

## PR-0 outcome so far

The source decision confirms four investigation priorities. No customer agreement sample, ERP import sample, or real incident/assignment workflow has been provided. The product owner selected an itemized CSV that opens in Excel as the first expense output. Its role, currency, correction-marker, and renewal-owner/reminder decisions are recorded below; the final column contract and reconciliation semantics still need a sample.

This pass checked the source documents and relevant local implementation. It did not run the Fleet Portal or Driver app, validate tenant isolation, inspect production data, or interview the customer.

The current repository already provides substantial foundations. PR-1 through PR-4 must extend those foundations only where customer evidence identifies a gap.

## Existing behavior confirmed in source

### Contract tracking and expiry alerts

- Vehicle documents have an optional `expires_on` field. The document FRD says document expiry reminders are deferred.
- The notification FRD defines local reminders and server email reminders for maintenance plan items. Its email reminders are owner-only and exclude organization fleet vehicles.
- The document FRD defines organization ownership and role-based access for fleet documents.
- No contract or insurance-policy entity, term history, agreement owner, or fleet agreement reminder workflow was found in the reviewed data model and source paths.

**Planning consequence:** A contract reminder cannot be added by simply reusing the personal maintenance email flow. PR-1 needs an organization-scoped recipient and delivery policy, or it must ship an agreement due list without automatic delivery if discovery chooses that scope. Attachments should reference existing organization documents.

## Public research for the agreement workflow

There is no customer-provided agreement sample, so public references can inform a discovery template but cannot establish the customer's fields, owner, or reminder timing.

- Odoo 19 lets an organization configure a number of days before contract end for an alert and names a `Responsible` person on each contract as the recipient. Its vehicle form also includes a future driver and an assignment date. This is a product example, not a required behavior for this portal. [Odoo Fleet vehicle and contract fields](https://www.odoo.com/documentation/19.0/applications/hr/fleet/new_vehicle.html)
- The UK Cabinet Office contract management guidance recommends tracking key dates and obligations, clarifying responsibilities, and maintaining a current management plan. It does not establish a universal renewal reminder interval. [Contract Management Plan](https://assets.publishing.service.gov.uk/media/69b828d1fdbfc4d58fc8d046/NISTA_Contract_Management_Guidance_CMP.pdf)
- An Alabama state insurance guide lists common motor policy proof fields such as insurer, policy number, insured name, effective date, expiry date, and vehicle identifiers where the policy is vehicle-specific. A fleet card may use a fleet designation instead. Those are jurisdiction-specific proof-of-insurance requirements, not a universal data mandate. [Alabama OIVS User Guide](https://www.revenue.alabama.gov/wp-content/uploads/2025/02/OIVSUserGuide021025.pdf)

**Discovery template to validate, not a product decision:** agreement type; insurer/provider; policy or agreement reference; named insured or contracting organization; covered vehicle(s) or fleet; effective and end dates; responsible organization member; original agreement or policy schedule; renewal state; and reminder preference. Do not collect coverage limits, claims details, or policyholder personal data unless a validated workflow needs them.

Public research supports assigning one accountable contract owner and making expiry dates visible. It does not establish a universal reminder interval. The product owner later selected 30, 60, or 90 day presets plus a custom value. Validate those options against a real agreement before implementation.

### ERP-ready expense records

- The `expenses` table already has a UUID primary key, vehicle, category, amount, currency, incurred date, receipt reference, `sourceKind`, `sourceId`, revision, admin correction actor, and ownership-period attribution.
- Fleet analytics exposes organization-scoped records and CSV export. Expense rows include source identity and whether they count in totals. The analytics design excludes unattributed history and avoids counting linked service/fuel records twice.
- Analytics access is documented for organization admins and managers. The current organization roles do not include a separate finance role.
- The analytics CSV is a product report with period, reporting currency, filters, and summary context. It is not yet a verified ERP import contract. No ERP sample, external accounting reference, deletion protocol, or idempotent import agreement is recorded.

**Planning consequence:** Do not add another expense table, stable ID, report endpoint, or migration before comparing the sample ERP import with existing rows and `/analytics/export`. PR-2 should add only the missing mapping or correction signal demonstrated by that comparison. PR-0 must decide whether current admin/manager access is sufficient for finance exports.

### Incident-to-repair linking

- Driver issue reports create organization work orders with vehicle, reporter, report time, odometer, issue type, urgency, description, and photo references.
- Drivers see their own work orders. Fleet Portal access is role-filtered.
- Work orders move through reported, in-progress, completed, or cancelled states. Completion requires a cost and creates a service record. Cancelling an open work order requires a reason.
- The reviewed work-order model has no incident parent or incident-to-many-repairs relation.

**Planning consequence:** The product owner has selected a separate incident case, reporter roles, required fields, access, closure, and reopening behavior. Confirm evidence retention details and the handoff to work orders in a real event walkthrough. Do not make incident closure depend on repair completion or cost.

**Product decisions, 22 November 2026:** Keep an incident as a separate case that can have zero or more repair work orders. Fleet Admins and Fleet Managers close it after review, regardless of whether linked repairs remain open. Drivers and Fleet Portal managers can file incidents. The report requires vehicle, event time, category, and description. Event time defaults to now and can be edited. Photos are optional. Do not require location or involved-person fields in the initial report. Use separate incident categories: accident, breakdown, damage, and other. All active drivers assigned to the vehicle and mechanics assigned to any linked work order can view case details and photos; organization roles `org_admin` and `org_manager` have organization-wide access and may close cases. Review note is optional; the system records reviewer and closure time. Only Fleet Admins and Fleet Managers can edit a submitted case. Reopening a closed case requires an explicit Fleet Admin/Manager action and creates an audit event; edits to the closed case require reopening first. After closure, cases/photos remain with the vehicle; if it exits the organization, retain them under its records policy. Identify the actual policy and validate a representative workflow before implementation. Suggest driver assignments active at event time and allow a manager to correct attribution.

### Planned driver assignment changes

- Driver assignments are many-to-many. A driver can hold multiple vehicle assignments, and a vehicle can have multiple drivers.
- The active uniqueness constraint prevents a duplicate active organization/driver/vehicle pair. It does not require one active driver per vehicle.
- The current Fleet API creates an assignment immediately and ends it by unassigning it. No future-effective driver assignment was found in the reviewed contract and source.
- The product also uses “handover” for showroom ownership transfer. A driver assignment change is a separate workflow.

**Planning consequence:** Define the planned assignment change at the assignment-pair level. Completion must not revoke other valid assignments. Keep the term “handover” for showroom ownership transfer.

**Product decisions, 22 November 2026:** The assignment-pair change has a scheduled effective time in the organization timezone, but assignment access changes only after a Fleet Admin or Fleet Manager confirms the vehicle was returned. If return is late, the old assignment remains active until a manager resolves the change. Either role can cancel before completion; cancellation leaves current assignments unchanged. Other active drivers assigned to the vehicle remain assigned. The Driver app shows the upcoming vehicle and time as read-only. Block a conflicting assignment change at scheduling or completion until a manager resolves it.

## Decisions that still need customer or product-owner evidence

| Feature | Evidence needed to close PR-0 | Current status |
| --- | --- | --- |
| Contract tracking | No customer agreement sample is available. Each agreement may cover one or selected vehicles. It has a named responsible member; email reminder goes to that person with admin visibility; required lead time is selected per agreement from presets (30/60/90 days) or a custom day value. If the owner is deactivated, an admin must assign a replacement and reminders pause meanwhile. Use organization timezone. Renewal retains prior term history. When a vehicle leaves, retain agreement/history under organization records policy. Still needed: validate presets/custom bounds against examples and identify the governing records policy | Partly resolved |
| ERP-ready expenses | CSV that opens in Excel; one row per expense; preserve each source currency without conversion; include correction revision and deletion/reversal markers; export by `org_admin` and `org_manager`. Existing export already includes IDs, source identity, amount, currency, date, and category. Still needed: reconciliation sample, final column contract, date conventions, and source semantics for correction markers | Partly resolved |
| Incident linking | Separate case with zero or more repairs; both Fleet Admins and Fleet Managers close after review regardless of repair status; drivers and Fleet Portal managers can report. Required fields, optional photos, event-time default/editing, categories, and access roles are decided. Submitted cases are editable only by Fleet Admins/Managers; closed cases require explicit audited reopening before edits. Reviewer and closure time are recorded; note is optional. Driver attribution is suggested from event-time assignment history and manager-correctable. Photos and case records stay with the vehicle after closure and, when the vehicle leaves the organization, are retained under the organization records policy. Still needed: identify the governing records policy and validate a representative workflow | Partly resolved |
| Driver assignments | Assignment-pair change has scheduled effective time in organization timezone; Fleet Admin or Manager confirms return; late return keeps old assignment active; either role can cancel with no assignment changes; other assignments remain intact; Driver app shows upcoming vehicle/time read-only; conflicting schedule/completion is blocked pending manager resolution | Partly resolved |
| Overall demand | Named user and business for each feature, frequency, current workaround, expected outcome, and evidence that the workflow merits implementation | Open |

Avoid sending unredacted agreements, invoices, driver details, or incident evidence into this planning record. A redacted schema or representative row is sufficient for contract design.

## Live workflow checks

These checks remain open because no app was run during this source review.

- [ ] Fleet Portal: show current vehicle documents and expiry display; confirm whether a staff member can identify and act on renewals today.
- [ ] Fleet Portal: export a representative reporting period and compare its rows, IDs, currencies, corrections, and totals with the ERP owner's sample import.
- [ ] Driver app and Fleet Portal: walk one incident through report, review, repair creation, completion or cancellation, and independent closure. Confirm who can report and see evidence.
- [ ] Fleet Portal and Driver app: walk one assignment change through planning, late return, cancellation, completion, and access revocation. Include a vehicle with more than one active driver assignment if that is valid customer practice.

## Gate to close PR-0

Close PR-0 only after the customer evidence table is resolved for features still in scope, each live workflow is demonstrated, and the FRDs state the resulting user, role, data owner, lifecycle, success measure, exclusions, and acceptance behavior. Update the implementation plan to remove or narrow any feature that fails its evidence gate. Only then settle API and data-model changes.

## Evidence inspected

- `backend/src/db/schema.ts`: `expenses`, `driver_assignments`, and `work_orders` data shapes.
- `backend/src/modules/fleet-analytics.ts`: organization-scoped records and CSV export.
- `backend/src/modules/fleet.ts`: driver issue submission, work-order transitions, and assignment create/end routes.
- `product/frd/documents.md`: fleet document ownership, access, and expiry reminder deferral.
- `product/frd/notifications.md`: maintenance-only email reminder policy and fleet exclusion.
- `architecture/fleet-analytics.md`: reporting attribution, CSV/API scope, and currency caveats.
- `architecture/data-model.md`: many-to-many assignments and work-order model.
- `architecture/openapi.yaml`: current assignment and fleet reminder contracts.
- [Odoo Fleet documentation](https://www.odoo.com/documentation/19.0/applications/hr/fleet/new_vehicle.html): public example of contract owners, configurable end-date alerts, future drivers, and assignment dates.
- [UK Cabinet Office Contract Management Plan](https://assets.publishing.service.gov.uk/media/69b828d1fdbfc4d58fc8d046/NISTA_Contract_Management_Guidance_CMP.pdf): public guidance on contract roles, key dates, and obligations.
- [Alabama OIVS User Guide](https://www.revenue.alabama.gov/wp-content/uploads/2025/02/OIVSUserGuide021025.pdf): jurisdiction-specific public example of commercial vehicle insurance proof fields.

