# Decision document ownership after cleanup

Status: Findings addressed in the request log, review plan, and implementation plan. PR-0 evidence and FRDs remain the sources for current decisions and feature behavior.

## Document roles

- `docs/decisions/customer-fleet-feature-improvements.md` records the original customer request, investigation rationale, and deferred scope.
- `docs/decisions/customer-fleet-feature-pr0-discovery.md` records repository evidence, research, product-owner decisions, and unresolved customer evidence.
- `docs/decisions/customer-fleet-feature-review-and-plan.md` records trade-offs, recommendations, cross-cutting requirements, and evidence gates.
- Focused feature FRDs record approved behavior and acceptance criteria. The incident FRD is still a draft and is not ready for implementation.
- `docs/decisions/customer-fleet-feature-implementation-plan.md` records PR order, dependencies, file scope, implementation steps, and verification. It links to decision records and FRDs instead of restating the product contract.

The discovery record and incident FRD both mention incident decisions for different reasons. Discovery preserves what the product owner decided and what evidence remains open. The FRD expresses that decision as a proposed behavior contract. Other features remain gated on PR-0 evidence before their FRDs become authoritative.

## Corrections made

- Removed the stale question about whether driver changes replace one assignment pair or all drivers. The decision is one pair.
- Replaced the stale expense-format questions with the current CSV, itemization, currency, correction-marker, and export-role choices. ERP sample mapping remains open.
- Removed the single-Fleet-Manager handoff implication. Either organization admin or manager may review and close an incident.
- Narrowed incident retention wording. Cases remain with the vehicle and follow organization records policy after vehicle exit. The governing policy and duration remain to be identified.
- Changed proposed driver-workflow naming to “driver assignment change” to distinguish it from showroom ownership transfer.
- Reduced copied product behavior in the review and implementation plans. Both point to the discovery record or feature FRD.

## Remaining duplication and open work

The incident decision appears in the discovery record and the incident FRD. Keep this distinction between an auditable decision and its feature contract. Do not copy the full incident requirements into the implementation plan again.

The incident FRD still needs the governing records policy and a representative workflow. The other feature contracts remain gated on customer or product evidence.
