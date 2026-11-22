# Customer fleet feature investigation log

Date: 18 November 2026

Status: Four investigation priorities were agreed after Odoo exploration. This log records the original request, rationale, and scope boundaries. It is not an implementation commitment or delivery schedule.

Current product decisions and unresolved evidence live in the [PR-0 discovery record](customer-fleet-feature-pr0-discovery.md). Approved behavior belongs in the relevant feature FRD. Use the [implementation plan](customer-fleet-feature-implementation-plan.md) for delivery order and verification gates.

## Customer context

- The ferry fleet and showroom are separate businesses.
- The customer asked whether the capabilities existed. These were not purchase blockers.
- “ERP integration” means the customer wants its ERP to read expenses. The ERP product and reconciliation format are unknown.
- “Leasing” means leasing vehicles out to customers or drivers.
- The customer did not specify its incident workflow or required tenant/domain arrangement.
- The requesting business and expected value for each capability remain unverified.

## Investigation priorities

The product owner agreed to investigate these four areas in order. Odoo informed the proposals, but its behavior does not prove a gap in AutoX.

### 1. Contract tracking and expiry alerts

**Customer question:** Can fleet agreements be tracked and renewed on time?

**Proposal:** Connect vehicle agreements to accountable follow-up beyond file storage. Begin with insurance policies and maintenance agreements. Policy-date tracking does not include claims handling.

**Why investigate:** Existing vehicle documents could support expiry follow-up and reduce missed renewals.

**Boundary:** Do not add outbound lease agreements, customer billing, deposits, or vehicle returns under this priority.

**Reference:** [Odoo vehicle and contract documentation](https://www.odoo.com/documentation/19.0/applications/hr/fleet/new_vehicle.html) describes responsible owners and configurable expiry email alerts. It is an example, not a customer requirement.

### 2. ERP-ready expense records

**Customer request:** Let the customer’s ERP read expense data from AutoX.

**Proposal:** First validate whether current records can be reconciled and exported reliably. The first output is an itemized CSV that opens in Excel. The current choices and unresolved mapping questions are in the [PR-0 discovery record](customer-fleet-feature-pr0-discovery.md).

**Why investigate:** Stable expense identity and traceable corrections can serve more than one ERP without a customer-specific connector.

**Boundary:** ERP write-back, payment sync, journal posting, and vendor-specific connectors remain deferred.

**Reference:** [Odoo service documentation](https://www.odoo.com/documentation/19.0/applications/hr/fleet/service.html) shows links between Odoo vendor bills and Fleet service records. That integration between Odoo apps is not evidence of an external ERP contract.

### 3. Incident-to-repair linking

**Customer question:** Can one event connect to several repairs or close without a repair?

**Proposal:** Investigate a separate incident case linked to zero or more work orders, with shared event evidence and traceable repair costs. The current product decisions are recorded in the [PR-0 discovery record](customer-fleet-feature-pr0-discovery.md), and the incident behavior draft is in [fleet-incidents.md](../../product/frd/fleet-incidents.md).

**Why investigate:** Existing issue reports and work orders may not cover independent review when one event creates multiple repairs or no repair.

**Boundary:** Insurance claims, insurer communication, liability decisions, and recovery accounting remain out of scope.

**Reference:** [Odoo accident documentation](https://www.odoo.com/documentation/19.0/applications/hr/fleet/accidents.html) describes categorized service records and attachments. It does not establish claims management.

### 4. Planned driver assignment changes

**Customer question:** Can the next driver be scheduled without ending the current assignment too early?

**Proposal:** Investigate a scheduled change for one driver/vehicle assignment pair, preserving assignment history and event-time driver attribution. Current decisions are in the [PR-0 discovery record](customer-fleet-feature-pr0-discovery.md).

**Why investigate:** A visible upcoming change could help ferry-fleet operations.

**Boundary:** Do not expand this into shift scheduling, route dispatch, or lease management.

**Reference:** [Odoo driver assignment documentation](https://www.odoo.com/documentation/19.0/applications/hr/fleet/new_vehicle.html) shows current and future drivers with an availability date. It is not a customer workflow requirement.

## Other requests and deferred scope

### Separate business data from branding and hosting

The customer said the ferry fleet and showroom are separate. The required isolation level is unknown. Separate organizations already provide the intended product boundary, but the earlier source review was not an authorization audit. A custom domain does not provide stronger data isolation. Dedicated databases or deployments need a concrete requirement and support budget.

### Outbound lease management

Odoo’s vehicle contracts and lease costs do not establish an end-to-end outbound leasing workflow. AutoX’s `leased` vehicle status is not a lease product. Defer agreement administration, billing, deposits, returns, overdue returns, collections, financing, and hire purchase until a real workflow justifies them. Keep lease revenue separate from expenses.

### Insurance claims

Incident-to-repair linking is not claims processing. Defer insurer integrations, liability decisions, and recovery accounting.

Other Odoo ideas, including cost comparisons, vehicle acquisition Kanban, and reusable vehicle specifications, remain reference ideas rather than agreed investigation priorities.

## Evidence and limits

The 18 November source review inspected:

- [Fleet analytics](../../backend/src/modules/fleet-analytics.ts) for organization reports, expense rows, CSV export, and currency handling.
- [Fleet routes](../../backend/src/modules/fleet.ts) for membership, vehicle, leased-status, and work-order behavior.
- [Fleet operations](../../backend/src/modules/fleet-operations.ts) for cost totals and reporting.
- [Fleet management requirements](../../product/frd/fleet-management.md) for issue-report scenarios and historical scope.

The review did not run the apps, verify tenant isolation, or test an external ERP import. Odoo exploration used its linked official documentation. It did not include a hands-on trial.
