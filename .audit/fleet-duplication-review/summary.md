# Fleet duplication review

Goal: identify duplicated or conflicting fleet decisions and feature claims in `site/src/app/fleet/` and `docs/` before implementation.

Verdict: **The site-copy and decision-document fixes are in place. Feature implementation remains gated on PR-0 evidence.** The Fleet route contains no fleet business logic. It renders localized marketing content.

## Findings

1. **Resolved: English marketing copy overstated mobile Fleet and buyer-transfer capabilities.** The Fleet page now says Fleet Portal for managers and Driver app for drivers. It no longer promises transfer to buyers with full history. The implementation boundary is in `docs/mvp-as-built.md:65` and `product/frd/showroom-handover-plan.md:3`.

2. **Resolved: active decisions now have separate homes.** The request log preserves rationale, discovery preserves evidence and choices, FRDs define behavior, the review preserves trade-offs, and the implementation plan points to those sources. The stale pair-scope, expense, and incident-review statements were removed. See [decision document ownership](02-decision-docs.md).

3. **Resolved in planning documents: showroom ownership and driver assignment changes use distinct names.** The showroom workflow transfers vehicle ownership. The new workflow changes one driver/vehicle assignment. Use “showroom handover” only for ownership transfer and “driver assignment change” for the proposed workflow.

## Applied cleanup

1. The original request log now preserves context, rationale, and deferred scope.
2. PR-0 discovery now owns repository evidence, research, product choices, and open evidence.
3. The review plan now owns trade-offs and cross-cutting recommendations.
4. The implementation plan now points to discovery and FRDs for product behavior.
5. The incident FRD remains the draft behavior contract. It is not implementation-ready until the governing records policy and customer workflow are confirmed.

## Scope and verification

Reviewed `site/src/app/fleet/page.tsx`, English/Myanmar locale dictionaries, the four customer-fleet decision documents, `docs/mvp-as-built.md`, `product/frd/fleet-management.md`, and `product/frd/showroom-handover-plan.md`. The English marketing copy and decision-document ownership were corrected. No fleet feature logic changed. `git diff --check` passed, and both locale dictionaries parse as JSON.

Decision-document evidence remains in [Decision documents](02-decision-docs.md).
