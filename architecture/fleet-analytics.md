# Fleet Analytics v1

The portal page is `/analytics`, under Overview. `backend/src/lib/fleet-analytics.ts` owns calculations shared by JSON and CSV. `backend/src/modules/fleet-analytics.ts` owns authentication, filters, and organization-scoped data loading. This page is distinct from the legacy operational Dashboard's lifetime KPIs.

## Access and configuration

Only active Enterprise organization admins/managers with Fleet Portal tokens can read reports, records, settings, and exports. The organization settings supply the fleet currency as an ISO code. Fleet admins can set the reporting timezone with an IANA identifier. A conditional update rejects a timezone save if the fleet currency changed since the settings were read.

## API

All paths start `/v1/organizations/:id/analytics`:

- `GET /settings`: `{currency: string|null, timezone: string}`.
- `PUT /settings`: `{timezone, currency?}`. The optional currency must match the current fleet currency.
- `GET /report`: totals, weighted rates, prior-period changes, category totals, monthly points, comparison rows, vehicle catalog and coverage warnings.
- `GET /records`: `{total, page, items}`; 50 expenses per page. Each item includes a retained linked fuel/service detail when present.
- `GET /export`: UTF-8 CSV with BOM. `kind=vehicles|expenses`; formula-like string cells are escaped.

Report, records and export require `from`/`to` ISO calendar dates. Maximum 1,096 inclusive days; future end dates are capped at today in the reporting timezone. Optional `vehicles` is a comma-separated UUID list (maximum 500), `active=true` restricts current unarchived vehicles. Foreign vehicle IDs return 404. `category` filters expense drill-down/export; `page` selects drill-down page. `calendar=true` selects calendar-aligned comparisons, otherwise the previous equal-length range is used. Current-month comparisons match elapsed days; completed months compare complete months.

Currency missing returns 409; invalid filters return 422. Missing measurement data is `null`, never zero. CSV repeats period/currency/timezone/vehicle-filter metadata on each data row and includes measured dates and coverage for comparison rows.

## Attribution and history

Migration `0022_fleet_analytics.sql` adds durable organization tenure and record snapshots. Database triggers cover every existing expense/service/fuel writer, including approved reviews and work-order completion. Pending and rejected reviews are not ledger entries. Organization costs use only expenses, so linked fuel/service costs are not counted twice.

Migration 0022 seeded legacy snapshots once using the recorded organization acquisition date. Migration 0050 attributes new rows, corrections, and deletion markers to the source record’s ownership period. It leaves earlier snapshots in place and excludes any snapshot whose recorded period or surviving source attribution contradicts its organization or vehicle. Historical transfers without captured attribution are reported as unavailable. The baseline marker prevents subsequent application startups from importing later owners' records. Migration replay is tested.

When an organization link is removed, its tenure closes and vehicle metadata freezes. Writes in a later ownership period cannot change the former organization’s snapshots. Corrections and deletions of older source records update only the organization recorded on those sources. Snapshot odometer units remain attached to readings, protecting calculations when the new owner changes vehicle units. Multiple ownership intervals inside one range suppress distance rates rather than bridging time outside the organization. Active vehicle names/status read from the authorized current link; transferred vehicles use their frozen metadata.

## Measurements

Distance uses dated fuel/service odometers, normalized to km. It requires two distinct days and positive distance; decreases suppress the range. Same-day readings use the maximum odometer for that day. Cost/km includes only ledger costs within the measured dates. Fleet cost/km is total eligible matched cost / total eligible km. Whole-period and monthly measurements can differ when readings do not cover month boundaries.

Full-to-full liquid consumption excludes the opening fill and includes intervening partial fills plus the closing fill. Unknown fill states, incompatible units/types, decreasing odometers and ambiguous multiple fuel events on the same day break the interval. The form defaults to Unknown rather than assuming full. Weighted averages retain separate fuel types.

EV estimates use the same opening-event-excluded quantity convention between dated charging odometers. They describe charging energy, not battery consumption. Hybrids report separate liquid/electric spend and combined energy cost/km, with no separate-distance inference or petrol/EV efficiency ranking.

Fleet cost/day divides by elapsed calendar days. Vehicle cost/day divides by the union of organization tenure days. Assignment multiplicity has no effect. Previous-period rates are suppressed when baselines are zero or date coverage is incomplete.

## Rollout

Deploy the backend migration/API before the portal and mobile update. Migration execution follows the existing startup migration path. Admins confirm reporting currency on first visit. No production deployment is part of this implementation task. A report exceeding 100,000 scoped records is rejected explicitly rather than returning truncated totals.


### Expense CSV reconciliation

Expense rows sort by transaction date descending and expense ID ascending. The CSV uses the same category selection as the expense records view and returns identical headers for empty and populated reports. The row's `currency` is the original currency, while `reporting_currency` is organization metadata. A blank original currency or revision indicates that the reporting snapshot lacks that value. Totals, comparisons, and vehicle summaries include only expenses in the fleet currency. Itemized rows outside that currency stay visible with `included_in_total=false`.

The current export includes the snapshot `revision` and `change_status`. A revision above one or a recorded admin correction produces `corrected`. Other existing rows are marked `current`. The CSV includes deletion markers for attributable organization expenses deleted after migration 0050 and any retained markers created under migration 0048. Markers use the original transaction date and expense ID, the last revision plus one, and a `deleted_at` timestamp. They have a blank amount and `included_in_total=false`. Treat each download as a complete replacement for its date, vehicle, active-status, and category selection. A correction can move a record outside the previous selection. Replace the old selection and reload any other affected selection. Standard analytics reports and records exclude deletion markers.

Before repairing existing projection rows, use this read-only query to find expense snapshots whose ownership period disagrees with the snapshot or the live source. The query also follows explicit fuel and service links on legacy expenses. Reconcile any flagged legacy mirror before using its historical totals. Rows with no surviving attribution require separate evidence.

```sql
SELECT r.id, r.kind, r.org_id AS snapshot_org, p.org_id AS source_org,
       r.vehicle_id AS snapshot_vehicle, p.vehicle_id AS source_vehicle
FROM analytics_records r
LEFT JOIN expenses e ON r.kind = 'expense' AND e.id = r.id
LEFT JOIN fuel_logs f ON e.source_kind = 'fuel_log'
  AND f.id = e.source_id AND f.vehicle_id = e.vehicle_id
LEFT JOIN service_records s ON e.source_kind = 'service_record'
  AND s.id = e.source_id AND s.vehicle_id = e.vehicle_id
CROSS JOIN LATERAL (
  SELECT COALESCE((r.payload->>'ownership_period_id')::uuid,
                  e.ownership_period_id, f.ownership_period_id, s.ownership_period_id) AS period_id
) evidence
LEFT JOIN vehicle_ownership_periods p ON p.id = evidence.period_id
WHERE r.kind IN ('expense', 'expense_deleted')
  AND evidence.period_id IS NOT NULL
  AND (p.org_id IS DISTINCT FROM r.org_id OR p.vehicle_id IS DISTINCT FROM r.vehicle_id
       OR (e.ownership_period_id IS NULL AND COALESCE(f.ownership_period_id, s.ownership_period_id) IS NOT NULL));
```
