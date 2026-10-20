# Fleet Analytics v1

The portal page is `/analytics`, under Overview. `backend/src/lib/fleet-analytics.ts` owns calculations shared by JSON and CSV. `backend/src/modules/fleet-analytics.ts` owns authentication, filters, and organization-scoped data loading. This page is distinct from the legacy operational Dashboard's lifetime KPIs.

## Access and configuration

Only active Enterprise organization admins/managers with Fleet Portal tokens can read reports, records, settings, and exports. Only admins can confirm currency/timezone. Currency is an ISO currency code; the timezone is an IANA identifier. First confirmation explicitly treats existing amounts as that currency without conversion. A SQL conditional update prevents concurrent confirmations from changing the locked currency. A later currency change requires an intentional migration.

## API

All paths start `/v1/organizations/:id/analytics`:

- `GET /settings`: `{currency: string|null, timezone: string}`.
- `PUT /settings`: `{currency, timezone, confirm_existing_amounts: true}`.
- `GET /report`: totals, weighted rates, prior-period changes, category totals, monthly points, comparison rows, vehicle catalog and coverage warnings.
- `GET /records`: `{total, page, items}`; 50 expenses per page. Each item includes a retained linked fuel/service detail when present.
- `GET /export`: UTF-8 CSV with BOM. `kind=vehicles|expenses`; formula-like string cells are escaped.

Report, records and export require `from`/`to` ISO calendar dates. Maximum 1,096 inclusive days; future end dates are capped at today in the reporting timezone. Optional `vehicles` is a comma-separated UUID list (maximum 500), `active=true` restricts current unarchived vehicles. Foreign vehicle IDs return 404. `category` filters expense drill-down/export; `page` selects drill-down page. `calendar=true` selects calendar-aligned comparisons, otherwise the previous equal-length range is used. Current-month comparisons match elapsed days; completed months compare complete months.

Currency missing returns 409; invalid filters return 422. Missing measurement data is `null`, never zero. CSV repeats period/currency/timezone/vehicle-filter metadata on each data row and includes measured dates and coverage for comparison rows.

## Attribution and history

Migration `0022_fleet_analytics.sql` adds durable organization tenure and record snapshots. Database triggers cover every existing expense/service/fuel writer, including approved reviews and work-order completion. Pending and rejected reviews are not ledger entries. Organization costs use only expenses, so linked fuel/service costs are not counted twice.

Current organization records are seeded once, conservatively excluding dates before recorded organization acquisition. Historical transfers without captured attribution are reported as unavailable. The baseline marker prevents subsequent application startups from importing later owners' records. Migration replay is tested.

When an organization link is removed, its tenure closes and vehicle metadata freezes. Later-owner writes and backdated writes cannot change the former organization's snapshots. Snapshot odometer units remain attached to readings, protecting calculations when the new owner changes vehicle units. Multiple ownership intervals inside one range suppress distance rates rather than bridging time outside the organization. Active vehicle names/status read from the authorized current link; transferred vehicles use their frozen metadata.

## Measurements

Distance uses dated fuel/service odometers, normalized to km. It requires two distinct days and positive distance; decreases suppress the range. Same-day readings use the maximum odometer for that day. Cost/km includes only ledger costs within the measured dates. Fleet cost/km is total eligible matched cost / total eligible km. Whole-period and monthly measurements can differ when readings do not cover month boundaries.

Full-to-full liquid consumption excludes the opening fill and includes intervening partial fills plus the closing fill. Unknown fill states, incompatible units/types, decreasing odometers and ambiguous multiple fuel events on the same day break the interval. The form defaults to Unknown rather than assuming full. Weighted averages retain separate fuel types.

EV estimates use the same opening-event-excluded quantity convention between dated charging odometers. They describe charging energy, not battery consumption. Hybrids report separate liquid/electric spend and combined energy cost/km, with no separate-distance inference or petrol/EV efficiency ranking.

Fleet cost/day divides by elapsed calendar days. Vehicle cost/day divides by the union of organization tenure days. Assignment multiplicity has no effect. Previous-period rates are suppressed when baselines are zero or date coverage is incomplete.

## Rollout

Deploy the backend migration/API before the portal and mobile update. Migration execution follows the existing startup migration path. Admins confirm reporting currency on first visit. No production deployment is part of this implementation task. A report exceeding 100,000 scoped records is rejected explicitly rather than returning truncated totals.
