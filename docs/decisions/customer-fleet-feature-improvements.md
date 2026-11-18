# Decision log: customer fleet feature improvements

Date: 18 November 2026

Status: Four investigation priorities agreed following Odoo exploration; implementation scope remains unapproved.

Scope: Contract tracking, ERP-ready expense records, incident-to-repair linking, and planned driver handovers take priority. Earlier customer decisions remain below; outbound leasing and insurance claims are deferred. No implementation commitment or delivery date.

## Agreed priorities for further investigation

The product owner agreed to investigate these four candidates first, in the order below. This is an investigation priority, not a commitment to build or a delivery schedule. Odoo documentation informed the proposals; these are not verified gaps against the latest implementation.

### Priority 1: Contract tracking and expiry alerts

**Odoo reference:** Vehicle-linked contracts identify a responsible person and support configurable email alerts before expiry. [Vehicle and contract documentation](https://www.odoo.com/documentation/19.0/applications/hr/fleet/new_vehicle.html)

**Proposed improvement:** Make vehicle agreements actionable beyond file storage: agreement type, provider, start/end dates, responsible person, attachment, renewal deadline, and reminder status. Start with insurance-policy and maintenance-agreement tracking; recording policy dates does not include claims handling.

**Why investigate first:** It connects existing vehicle documents to clear follow-up work and could help both businesses avoid missed renewals.

**Validation gate:** Review real agreements, identify who owns renewals, agree alert timing and delivery channels, and check overlap with existing document-expiry and reminder capabilities. Define renewal/history behavior before introducing a separate contract entity.

**Boundary:** This does not include outbound lease agreements, customer billing, deposits, or vehicle-return workflows.

### Priority 2: ERP-ready expense records

**Odoo reference:** With Odoo Accounting, vendor bills can create Fleet service records, which link back to the bill and indicate its status. This is an integration between Odoo apps, not proof of an equivalent external ERP connector. [Service documentation](https://www.odoo.com/documentation/19.0/applications/hr/fleet/service.html)

**Proposed improvement:** Make each expense traceable, consistently structured, and suitable for reconciliation: stable ID, organization and vehicle, category, original amount/currency, transaction date, source record, supporting document, and an optional external accounting reference. Define correction and deletion handling so exports can be repeated safely.

**Why investigate now:** This develops the customer's request to read expenses into a reusable data foundation. It replaces the earlier API-first feature proposal; CSV versus a read-only API remains a delivery choice to validate with the ERP owner.

**Validation gate:** Obtain an example import format and reconcile a representative period. Confirm that service/fuel source records and derived expenses are not counted twice, repeated imports do not duplicate entries, and corrections remain traceable. See Decision 2 for the retained customer context and integration boundaries.

### Priority 3: Incident-to-repair linking

**Odoo reference:** Its documented accident workflow uses categorized service records and supporting attachments. Repairs involving several vendors use separate records. [Accident documentation](https://www.odoo.com/documentation/19.0/applications/hr/fleet/accidents.html)

**Proposed improvement:** Investigate one incident linked to multiple work orders or repair records, with shared evidence, event date, vehicle, driver at the time, review status, and a consolidated repair-cost view. Separate estimates from actual costs. An incident should be closable without inventing a paid repair.

**Why investigate now:** This builds on existing issue reports and connects follow-up work without duplicating evidence across repairs.

**Validation gate:** Demonstrate the existing reporting flow, then map one real incident involving multiple repairs. Confirm whether an explicit incident record is necessary, who reviews it, how closure works, and who may access its evidence.

**Boundary:** Neither our current offering nor this proposal includes insurance-claim processing, insurer integrations, liability decisions, or recovery accounting.

### Priority 4: Planned driver handovers

**Odoo reference:** A vehicle can have a current driver, future driver, and availability date, with an explicit action to apply the driver change. [Driver assignment documentation](https://www.odoo.com/documentation/19.0/applications/hr/fleet/new_vehicle.html)

**Proposed improvement:** Schedule the next driver without prematurely replacing the current assignment. Investigate planned handover time, pending/completed/cancelled states, conflict checks, and preservation of assignment history and event-time driver attribution.

**Why investigate now:** It could improve ferry-fleet operations by making upcoming responsibility changes visible.

**Validation gate:** Walk through a real driver change, including cancellation, late return, and an unavailable replacement vehicle. Confirm how this fits existing assignment rules. Do not expand this into shift scheduling, route dispatch, or lease management without separate evidence.

## Odoo comparison boundaries and deferred scope

- **Outbound lease management remains deferred as a whole.** Odoo's documented vehicle contracts and lease costs do not establish a complete outbound leasing business workflow. Our existing `leased` status also does not establish agreement, deposit, billing, or return management. The contract-tracking priority above does not reopen this feature.
- **Insurance claims remain out of scope.** Odoo's documented accident workflow is service-record based and does not establish complete claims management. Our system does not offer insurance-claim processing either; incident-to-repair linking must not be presented as claims support.

Other Odoo ideas observed—driver/vehicle cost comparisons, vehicle acquisition Kanban, and reusable model specifications—remain lower-priority reference ideas, not agreed investigation priorities. [Cost analysis](https://www.odoo.com/documentation/19.0/applications/hr/fleet/cost_analysis.html), [Fleet features](https://www.odoo.com/app/fleet-features), [Vehicle models and defaults](https://www.odoo.com/documentation/19.0/applications/hr/fleet/new_vehicle.html).

## Previous customer decisions

The following retains the original discovery context, updated to reflect the priorities and deferrals above.

### Confirmed customer context

- The company ferry fleet and showroom are separate businesses.
- These were capability questions, not requirements blocking a purchase.
- ERP integration currently means reading expenses from our system. The ERP product and exact data contract are unknown.
- Leasing means leasing vehicles out to customers or drivers.
- The customer did not explain the required tenant/domain arrangement or incident workflow.
- It is not yet established which business requested each capability, or whether both need it.

### Decision 1: Treat these as discovery opportunities

**Disposition:** Record demand without promising delivery. The customer did not set a buying priority. The product owner subsequently agreed the investigation order above; no budget or release date was agreed.

**Recommendation:** Demonstrate existing capabilities first. Ask each business to identify a real workflow it cannot complete today. Advance a feature when a named user, example workflow, and measurable outcome are available.

**Reason:** A question about feature availability is weaker evidence than a recurring operational problem. Building all four now would create substantial product and support scope without validated demand.

### Decision 2: Prepare ERP-ready expense records

**Confirmed need:** The customer currently wants their ERP to read expenses. The ERP product, integration owner, and exact format are unknown.

**Current foundation:** Organization analytics provides reporting, expense records, and CSV export. These application endpoints are not evidence of a supported external ERP integration contract.

**Updated decision:** Replace the standalone read-only expense API proposal with Priority 2, ERP-ready expense records. First validate record quality, traceability, and reconciliation; then choose an export or integration mechanism. Keep accounting entries, approvals, and payments in the ERP.

Before implementation, agree on:

- ERP name/version, integration owner, and an example import payload.
- Itemized expenses versus summaries; vehicle, category, date range, and cost-center mapping.
- Stable record IDs, source-record identity, external accounting references, and correction/deletion behavior.
- Original amount and currency, event date versus update time, and historical ownership boundaries. Never treat mixed-currency totals as accounting-ready amounts.
- If an API is justified: a documented versioned contract, organization-scoped read-only credentials, pagination and update cursors, credential rotation/revocation, audit visibility, and rate limits. Avoid a bespoke API per customer.

**Deferred:** ERP write-back, payment synchronization, automatic journal posting, webhooks, and vendor-specific connectors. An external API is not committed by this decision.

**Validation gate:** Reconcile a representative period against source expenses and test duplicate-free re-import and corrections. Use existing CSV export for discovery if its fields meet the customer's needs.

### Decision 3: Separate business data from branding and hosting

**Confirmed need:** The businesses are separate. The requested technical isolation level is unknown.

**Current foundation:** Organization-scoped records and membership checks exist. This inspection is not an isolation audit or a guarantee that every route enforces the boundary correctly.

**Recommendation:** Use a separate organization for each business, with explicit membership and no implicit cross-business reporting. Verify authorization boundaries before representing this as a security guarantee.

Treat these as distinct offerings:

| Option | What it solves | Proposed disposition |
| --- | --- | --- |
| Separate organization | Business data and staff-access boundaries | Use the existing model; validate isolation |
| Customer-owned domain | Branded access address | Consider only if branding is the actual need |
| Dedicated database/deployment | Infrastructure isolation and operational control | Defer until a concrete requirement and support budget exist |

A custom domain does not provide stronger data isolation by itself. If selected, plan domain ownership verification, TLS, login/callback behavior, session boundaries, and domain removal. Never treat the request hostname alone as authorization.

**Validation gate:** Ask what they need to achieve: a branded URL, separate administrators/data, specific hosting control, or dedicated infrastructure. Confirm who owns DNS and pays for ongoing operations. Do not bundle dedicated hosting into a branding request.

### Decision 4: Defer outbound lease management

**Confirmed customer interest:** Leasing vehicles to customers or drivers, not leasing from suppliers. Hire purchase was not confirmed.

**Current foundation:** A `leased` lifecycle status exists for the taxi-fleet template. It does not provide a full leasing workflow.

**Decision:** Leave the complete feature for now. Do not include agreement administration, billing schedules, deposits, handover/returns, overdue returns, collections, financing, or hire purchase in the current investigation priorities.

**Revisit only when:** A concrete customer workflow and business priority justify it. At that point, inspect a real agreement from reservation to return, confirm existing rental/assignment overlap, and establish the boundary with ERP accounting. Lease revenue must remain distinct from expenses.

### Decision 5: Demonstrate issue reporting before adding an incident module

**Confirmed need:** The customer asked about incident reporting; the desired follow-up is unknown.

**Current foundation:** Work orders capture issue type, description, urgency, photos, and a resolution lifecycle. Accident/breakdown reporting is represented in the fleet specification. Work-order completion can create a service record.

**Recommendation:** Show the existing report-to-repair workflow first. If it satisfies their need, improve discoverability and missing fields rather than create a second reporting system.

If the customer needs broader accident case management, introduce an incident record only after validating that distinction. An incident may need event time/location, involved people, evidence, review, and links to repairs; closing an incident must not require pretending every event was a paid repair. Priority 3 now governs investigation of incident-to-repair linking. Insurance claims and recovery accounting remain explicitly out of scope and are not current capabilities.

**Deferred:** Claims processing, insurer integrations, liability decisions, and recovery accounting.

**Validation gate:** Ask the customer to walk through one recent incident: who reported it, what evidence was required, who acted next, and what counted as closed. Establish who can access sensitive evidence and how long it should be retained.

## Next discovery steps

Follow the four agreed priorities above: contract tracking and expiry alerts, ERP-ready expense records, incident-to-repair linking, then planned driver handovers. Demonstrate existing capabilities and check current implementation gaps within each investigation before proposing new modules.

Clarify tenant/domain expectations after those priorities unless new customer evidence changes the order. Do not schedule outbound leasing or insurance claims for this round. Before approving implementation, revisit customer value, frequency, willingness to pay, and implementation/support cost.

## Evidence and limits

Source inspection on 18 November 2026:

- [Fleet analytics endpoints](../../backend/src/modules/fleet-analytics.ts): organization reporting, expense rows, CSV export, and currency caveats.
- [Fleet module](../../backend/src/modules/fleet.ts): organization membership/vehicle routes, leased lifecycle state, work-order creation and transitions.
- [Fleet operations](../../backend/src/modules/fleet-operations.ts): expense-backed cost totals and reporting operations.
- [Fleet requirements](../../product/frd/fleet-management.md): issue-report scenarios and historical scope decisions.

Some older requirements and as-built documents conflict with later changes. Current source was used to ground the capability statements above; no runtime, tenant-isolation, or end-to-end integration verification was performed. Recommendations are not assertions that these new features already exist.

Odoo exploration used its official feature listing and Odoo 19 documentation linked above. The landing page timed out; no hands-on trial was performed. Odoo integration-dependent features should not be represented as standalone Fleet capabilities.
