# Fleet Analytics v1 — implementation plan

Date: 2026-10-19
Status: Implemented locally. Currency is confirmed once by an administrator; changing it requires an explicit migration. See `architecture/fleet-analytics.md` for the implementation and rollout contract.

## Goal and placement

Add **Overview → Analytics** (`/analytics`) to Fleet Portal. Give Fleet Admins and Managers a trustworthy view of recorded operating costs and vehicle efficiency. Keep Dashboard as the operational summary. Mechanics and Drivers cannot access organization-wide analytics, including APIs and exports.

Drivvo is a product reference, not a formula specification: https://www.drivvo.com/en/fleet-management/. Its public site describes fleet and vehicle costs, monthly comparisons, cost per km, fuel economy and exports. DCO's formulas and data-quality rules below are deliberate product decisions.

## Confirmed scope

- Costs and efficiency only. No income ledger, revenue, profit, depreciation, acquisition costs or forecast maintenance costs.
- One page with shared date-range and multi-vehicle filters. Default: all eligible vehicles.
- Default date range: last 12 calendar months including the current month. Presets: This month, Last month, Last 3 months, Last 12 months, Custom.
- Monthly charts. Mark the current month incomplete; cap calculations at today.
- One organization currency; no conversion or mixed-currency totals in v1.
- Display distance in kilometres, costs per km, liquid-fuel consumption in L/100 km and EV energy in kWh/100 km. Normalize stored distance before calculation; do not assume every stored odometer is already km.
- Historical costs from archived/transferred vehicles remain eligible when attributable to the organization. Show status labels and offer Active vehicles only.
- Click a month, category or vehicle to inspect the underlying filtered records, with links to details.
- CSV exports of the filtered vehicle comparison and underlying expense records. No PDF.
- No new automatic inefficient-vehicle alerts. Existing lemon-flag functionality is not a basis for this page's efficiency rankings.

## Page contents

1. Filter bar: date presets/custom range, vehicle multi-select, Active vehicles only.
2. Summary metrics: recorded operating costs, recorded distance, cost/km, cost/day; show previous-period comparisons where valid.
3. Monthly operating costs: stacked columns by category; no income/profit series.
4. Expense distribution: category chart with amounts and percentages. Include all supported expense categories, not only fuel, maintenance and parts.
5. Efficiency trends: separate compatible liquid-fuel and electric series, with measured/estimated labels and eligible weighted averages.
6. Cost timelines: cost/km and cost/day in separate clearly labelled views; avoid implying that different units share a numeric scale.
7. Vehicle comparison table: vehicle/status, operating costs, recorded distance, cost/km, cost/day, eligible fuel/energy efficiency and data coverage. Sortable; missing metrics do not rank as zero.
8. Drill-down records: date, vehicle, category, description, amount, entered by, and record-detail link. Preserve page filters and the clicked dimension.

## Calculation contracts

### Operating costs

Use the expense ledger as the single accounting source. Service and fuel records contribute through their linked expenses exactly once. Use incurred/service dates, not sync/upload time. Pending/rejected review submissions contribute nothing; accepted submissions use their underlying record dates. Corrections and deletions update results.

Label the metric **Recorded operating costs**. Zero is appropriate only when eligible expense records genuinely sum to zero; it is not a substitute for missing distance or efficiency data.

### Recorded distance and cost/km

- Use valid dated odometer readings within the selected period. Require at least two usable readings and positive distance.
- Never extrapolate to period boundaries or treat an undated current odometer as a dated boundary reading.
- Reject or split invalid/reset/decreasing odometer sequences rather than taking an unrestricted max-minus-min.
- Show the measured start/end dates and incomplete coverage.
- Cost/km = eligible costs within the measured interval divided by that interval's recorded km.
- Full-period operating costs remain separate; do not divide a whole month's costs by a short measured interval.
- Fleet cost/km = sum of eligible matched-interval costs / sum of corresponding recorded km, not an unweighted average of vehicle rates.
- Monthly points repeat these rules for each month. Period totals and monthly distance sums need not match when monthly boundaries lack readings; explain this in definitions rather than inventing distance.
- Missing or insufficient readings produce Unavailable and exclusion from efficiency rankings.

### Cost/day

- Fleet daily spend = selected eligible operating costs / elapsed calendar days in the selected period, including idle days and ending today when applicable.
- Vehicle cost/day uses calendar days during which the vehicle belonged to the organization within the selected period, including idle and archived days while still owned.
- Organization tenure, not Driver assignment days, controls this denominator. Multiple simultaneous Driver assignments must not multiply days.
- Define one organization reporting timezone for determining today, inclusive calendar dates and tenure boundaries; confirm an existing setting or establish one during contract implementation.

### Liquid-fuel efficiency

Extend the shared refuel form, API, database, sync and review payloads with Full tank / Partial fill. Historical/older-client entries remain Unknown, never silently Full.

A valid full-to-full interval starts at a confirmed full tank and ends at another confirmed full tank with increasing odometer readings. Sum intervening partial fills and the ending fill; exclude the starting fill's quantity. Consumption = litres / interval km × 100. Unknown entries, incompatible units or invalid readings must not produce a confident full-to-full value.

Use complete intervals within the selected date range. Do not prorate an interval crossing a filter boundary. Show coverage and Not enough data when no valid interval exists. Weighted fleet rates use eligible litres and measured km, grouped by compatible fuel/vehicle type.

### Electric efficiency

Include charging costs and recorded kWh in v1. Display **Estimated charging energy per 100 km**, not measured battery consumption: state of charge is not recorded, and charging losses/storage changes affect the result.

Use valid, compatible charging quantities and dated odometer intervals. Define inclusion/exclusion of boundary charge events consistently and test it. Show insufficient-data states for missing quantities or distance. Do not claim that a logged charging interval represents exact energy used while driving.

### Plug-in hybrids

Show liquid-fuel spending and electricity spending separately. Show combined energy cost/km using both costs within the same measured interval. Do not infer separate petrol/electric driving distance or rank hybrids with petrol-only/EV-only efficiency.

### Previous-period comparisons

Compare with the preceding equivalent period. For month-to-date, use the same elapsed days of the previous month, clipping where the calendar has fewer days. Apply equivalent elapsed-period handling to other presets and document custom-range boundaries.

Suppress percentage change when the baseline is zero, unavailable or lacks comparable coverage. Show a neutral unavailable explanation rather than infinity or a fabricated percentage. Cost/km comparisons use matched intervals in both periods and expose those dates.

## Historical ownership and currency prerequisites

Current cost calculations are vehicle-lifetime calculations; they cannot be reused unchanged for filtered analytics. Current organization membership links and transfer audit rows also do not, by themselves, establish durable ownership of every financial record after a vehicle changes hands.

Before including transferred vehicles, implement or verify durable organization attribution and historical vehicle tenure. Prevent a former organization from seeing subsequent owners' records, even if those records are backdated. Preserve only authorized historical record details for drill-down/export. Backfill conservatively from evidence; do not invent ownership or acquisition dates.

The current schema stores money amounts without a per-record currency field, and organization settings are an extensible JSON object. Implemented policy: Fleet Admin selects/confirms it once; existing amounts are not converted; changing it after financial records exist requires an explicit migration rather than relabelling past money.

## Data/API implementation

- Inventory current portal analytics, report endpoints, accounting triggers, transfer history, units and money formatting. Reconcile conflicting FRD definitions as part of implementation.
- Add a backend analytics calculation module with shared normalized filters and metric definitions used by summary, charts, comparisons, drill-down and CSV. No duplicated frontend formulas.
- Require org_admin/org_manager and organization scoping on all endpoints. Drill-down/export must not broaden permissions to private personal records or other organizations.
- Return metric values alongside availability reason, measured dates, coverage, unit/currency, applied filters and generation time. Nullable rates distinguish missing data from actual zero.
- Paginate underlying records. Bound custom ranges and aggregate queries; prevent per-vehicle N+1 loading.
- Preserve one result contract across the portal and exports. CSV includes selected period, vehicles, currency, km units and metric coverage; protect spreadsheet cells against formula injection.
- Extend refuel fields end-to-end, including mobile offline persistence/outbox, corrections and old-client compatibility. Do not implement a separate Driver logging form.
- Audit existing personal/mobile efficiency formulas, which currently use partial-fill approximations. Do not silently describe those old calculations as full-to-full; document any follow-up alignment separately from this Fleet Portal feature.

## Delivery sequence

1. Finalize currency and reporting-context prerequisites; reconcile analytics contracts and legacy migration policy.
2. Add fuel fill-status capture and historical ownership/tenure support with safe migrations and authorization tests.
3. Implement server calculations, normalized filters and period comparisons with fixture-based tests.
4. Implement Analytics page under Overview, including charts, vehicle table, loading/empty/error/data-quality states and shared filters.
5. Add authorized drill-down and CSV exports from the same calculation/query layer.
6. Validate totals against underlying records, mobile ledger and exports; test deployed-like data before release.

## Acceptance checks

- Admin/Manager access succeeds; Mechanic/Driver/direct unauthorized requests fail, including exports.
- Linked fuel/service expenses are counted once; all ordinary categories appear; review submissions do not affect totals until accepted.
- Selecting vehicles/date range changes all charts/table/drill-down/CSV consistently.
- Archived/transferred historical costs remain stable; later-owner data never leaks into former-org reports.
- Missing distance, zero distance, odometer resets, mixed stored units and sparse dates never yield fabricated rates or a best-vehicle ranking.
- Cost/km uses the same dates for numerator and denominator; fleet aggregation is distance-weighted.
- Full/partial/unknown liquid fills behave correctly; EV estimates are labelled; hybrids never receive unsupported propulsion efficiency.
- Day counts handle incomplete months, leap years, vehicle entry/exit and overlapping Driver assignments.
- Previous-period comparisons handle missing coverage, zero baselines and unequal month lengths.
- Currency labels agree across page, drill-down, records and CSV; historical values are not silently relabelled.
- CSV filters, values and availability reasons match the displayed results; record links remain authorized.
- Personal/Driver shared logging, offline sync, review and existing operational dashboard continue working.

## Explicit exclusions

Income/profit, trips/GPS distance inference, automated failure diagnosis or Driver scoring, currency conversion, PDF, depreciation, purchase costs, forecasts, new maintenance approval flows and speculative efficiency alerts.
