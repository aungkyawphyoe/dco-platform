# Customer fleet feature review and implementation plan

Date: 22 November 2026

Status: Approved as a review and planning reference. The four items remain investigation priorities. This document does not authorize implementation, promise delivery, or set a release date.

## Source of truth

- [Customer fleet feature improvements](customer-fleet-feature-improvements.md) records the original customer requests and why they matter.
- [PR-0 discovery](customer-fleet-feature-pr0-discovery.md) records repository evidence, public research, product-owner decisions, and unresolved customer evidence.
- A feature FRD records the approved behavior contract. The incident draft is [Fleet incident cases](../../product/frd/fleet-incidents.md). Other feature FRDs remain gated on PR-0 evidence.
- [Implementation plan](customer-fleet-feature-implementation-plan.md) records PR order, dependencies, touched files, and implementation verification. It links to behavior requirements rather than copying them.

The implementation plan and this review do not override the discovery record or an approved feature FRD. Historical decisions stay in the original request log only when marked superseded.

## Review summary

Investigate the four capabilities separately. Their owners, data, permissions, and lifecycles differ. Do not build one shared fleet-operations feature to cover all four.

Keep the investigation order from the original request. For delivery, validate expense identity and reconciliation before building features that consume expense data. Feature order after PR-0 depends on evidence and technical dependencies.

## Trade-offs

| Feature | Benefit | Cost or risk | Recommendation |
| --- | --- | --- | --- |
| Contract tracking | Turns stored agreements into owned follow-up work and reduces missed renewals. | Adds agreement and reminder lifecycles, renewal history, and sensitive document access. It can duplicate document expiry metadata. | Reuse document storage. Add agreement records only if the validated workflow needs provider, owner, term history, or renewal actions. |
| ERP-ready expenses | Improves reconciliation through a reusable spreadsheet output. | Stable identity, corrections, deletions, currencies, duplicate source costs, and historical ownership affect export correctness. A connector creates ongoing accounting expectations. | Start with the selected itemized CSV. Compare its columns and correction behavior with real customer data. Keep ERP-specific APIs and connectors deferred. |
| Incident-to-repair linking | Connects one event and evidence to zero or more repairs. | Adds case lifecycle and privacy rules beside existing issue reports and work orders. Repair estimates can be mistaken for actual costs or claims. | Keep the incident separate from work orders. Do not present it as claims processing. Use the incident FRD for its current draft contract. |
| Planned driver assignment changes | Makes upcoming assignment changes visible without prematurely changing access. | Adds schedule conflicts, return delays, cancellation, and event-time attribution concerns. The assignment model is many-to-many. | Keep each change scoped to one driver/vehicle pair. Preserve every other active assignment. Use “driver assignment change” to distinguish it from showroom ownership transfer. |

## Evidence gates

Before implementation, resolve the evidence listed in [PR-0 discovery](customer-fleet-feature-pr0-discovery.md). The current gates include agreement and ERP samples, identification of the organization records policy, and live workflow demonstrations. Do not treat product-owner choices without customer examples as proof of customer demand.

The decision log and discovery record preserve current product choices. Feature behavior and acceptance criteria must move into focused FRDs before implementation. The implementation plan links to those contracts after PR-0 closes.

## Cross-cutting implementation requirements

- The backend enforces organization membership, roles, ownership, and lifecycle transitions. Client visibility does not grant access.
- Reuse organization, vehicle, expense, work-order, and document identities where they already express the required data.
- Make reminders, exports, incident/work-order links, and assignment changes safe to retry.
- Define record ownership and retention before creating new data. Preserve audit history without storing unnecessary sensitive content.
- Specify migrations, authorization, and error states in the applicable FRD and API contract before feature work.
- Verify the actual Fleet Portal and Driver app flows. Source inspection alone does not prove runtime behavior.

## Deferred scope

Do not add outbound leasing, insurance claims, insurer communication, liability decisions, recovery accounting, ERP write-back, payment synchronization, or vendor-specific ERP connectors under these priorities. Reopen those areas only with a separate validated workflow and product decision.

## Basis and limits

This review uses the source decision, repository documentation, and the PR-0 source review. It does not claim a code audit, security audit, runtime verification, or customer validation. Odoo references inform discovery only. They do not prove gaps or establish customer requirements.
