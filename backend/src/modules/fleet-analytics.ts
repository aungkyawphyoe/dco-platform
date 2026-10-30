import { sql } from 'drizzle-orm';
import type { FastifyPluginAsync, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { AppError } from '../lib/errors.js';
import { calculateAnalytics, csvCell, days, expenseRows, previousPeriod, reportingToday, type ReportingRecord, type ReportingVehicle } from '../lib/fleet-analytics.js';
import { requireFleetPortal } from './auth.js';
import { assertPasswordChangeClear, getOrganizationAccess } from './fleet.js';

const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(v => !Number.isNaN(Date.parse(v)) && new Date(v).toISOString().slice(0, 10) === v, 'Invalid date');
const query = z.object({ from: date, to: date, calendar: z.enum(['true', 'false']).default('false'), vehicles: z.string().optional(), active: z.enum(['true', 'false']).default('false'), category: z.string().max(80).optional(), page: z.coerce.number().int().min(1).default(1), kind: z.enum(['vehicles', 'expenses']).default('vehicles') });
type Settings = { currency: string | null; timezone: string };
const settingsOf = (s: unknown, currency: string | null): Settings => {
  const value = (s as Record<string, unknown>).analytics as Partial<Settings> | undefined;
  return { currency, timezone: value?.timezone ?? 'UTC' };
};
export const fleetAnalyticsPlugin: FastifyPluginAsync = async app => {
  async function access(request: FastifyRequest, admin = false) {
    requireFleetPortal(request);
    const id = z.string().uuid().parse((request.params as { id: string }).id);
    await assertPasswordChangeClear(app.db, request.authUser!.sub);
    const result = await getOrganizationAccess(app.db, request.authUser!.sub, id, admin ? ['org_admin'] : ['org_admin', 'org_manager']);
    return { id, ...result };
  }
  app.get('/organizations/:id/analytics/settings', async request => {
    const { organization } = await access(request);
    return settingsOf(organization.settings, organization.currency);
  });
  app.put('/organizations/:id/analytics/settings', async request => {
    const { id, organization } = await access(request, true);
    const body = z.object({ currency: z.string().optional(), timezone: z.string().max(100) }).parse(request.body);
    if (body.currency !== undefined && body.currency !== organization.currency) throw new AppError(409, 'currency_mismatch', 'Reporting uses the fleet currency. Change it in organization settings if it is still unlocked.');
    try { reportingToday(body.timezone); } catch { throw new AppError(422, 'invalid_timezone', 'Choose a valid reporting timezone'); }
    const result = await app.db.execute(sql`UPDATE organizations SET settings=jsonb_set(settings, '{analytics}', ${JSON.stringify({ timezone: body.timezone })}::jsonb)
      WHERE id=${id} AND currency IS NOT DISTINCT FROM ${organization.currency} RETURNING currency`);
    if (!result.rows.length) throw new AppError(409, 'currency_mismatch', 'Fleet currency changed. Refresh and try again.');
    return { currency: result.rows[0].currency, timezone: body.timezone };
  });

  async function load(request: FastifyRequest) {
    const { id, organization } = await access(request);
    const settings = settingsOf(organization.settings, organization.currency);
    if (!settings.currency) throw new AppError(409, 'analytics_currency_required', 'An administrator must select the fleet currency in organization settings first');
    const q = query.parse(request.query), today = reportingToday(settings.timezone);
    const period = { from: q.from, to: q.to > today ? today : q.to, calendar: q.calendar === 'true' };
    if (period.from > period.to || days(period.from, period.to) > 1096) throw new AppError(422, 'invalid_period', 'Choose a past or current period of up to three years');
    const tenures = await app.db.execute(sql`SELECT t.vehicle_id, t.started_at, t.ended_at,
      CASE WHEN o.id IS NOT NULL AND t.ended_at IS NULL THEN to_jsonb(v) ELSE t.vehicle END AS vehicle
      FROM analytics_tenures t LEFT JOIN organization_vehicles o ON o.id=t.id
      LEFT JOIN vehicles v ON v.id=o.vehicle_id WHERE t.org_id=${id} ORDER BY t.started_at`);
    const byId = new Map<string, ReportingVehicle>();
    for (const row of tenures.rows) {
      const v = row.vehicle as Record<string, unknown>, vehicleId = String(row.vehicle_id);
      const existing = byId.get(vehicleId);
      const item: ReportingVehicle = { id: vehicleId, name: String(v.name), plate: String(v.license_plate), fuel: String(v.fuel_type), mileageUnit: String(v.mileage_unit),
        status: row.ended_at ? 'transferred' : v.archived ? 'archived' : 'active', tenures: existing?.tenures ?? [] };
      item.tenures.push({ start: reportingToday(settings.timezone, new Date(String(row.started_at))), end: row.ended_at ? reportingToday(settings.timezone, new Date(String(row.ended_at))) : null });
      byId.set(vehicleId, item);
    }
    const ids = q.vehicles === undefined ? null : z.array(z.string().uuid()).min(1).max(500).parse(q.vehicles.split(','));
    if (ids?.some(key => !byId.has(key))) throw new AppError(404, 'vehicle_not_found', 'A selected vehicle is not available in this organization');
    const vehicles = [...byId.values()].filter(v => (!ids || ids.includes(v.id)) && (q.active !== 'true' || v.status === 'active'));
    // One bounded query for all records; no per-vehicle requests. Snapshots are
    // organization-scoped even after the underlying vehicle changes owner.
    const start = previousPeriod(period).from;
    const vehicleScope = vehicles.length ? sql`r.vehicle_id IN (${sql.join(vehicles.map(v => sql`${v.id}`), sql`, `)})` : sql`false`;
    const result = await app.db.execute(sql`SELECT r.*, COALESCE(u.display_name,u.email,'Unknown') AS author
      FROM analytics_records r LEFT JOIN users u ON u.id::text=COALESCE(r.payload->>'created_by',r.payload->>'user_id')
      WHERE r.org_id=${id} AND ${vehicleScope}
      AND COALESCE(r.payload->>'incurred_on',r.payload->>'serviced_on',r.payload->>'logged_on') BETWEEN ${start} AND ${period.to}
      LIMIT 100001`);
    if (result.rows.length > 100000) throw new AppError(422, 'report_too_large', 'This fleet requires a larger reporting allocation. Contact support.');
    const selected = new Set(vehicles.map(v => v.id));
    const records: ReportingRecord[] = result.rows.filter(r => selected.has(String(r.vehicle_id))).map(r => ({ id: String(r.id), vehicle_id: String(r.vehicle_id), kind: String(r.kind), payload: { ...(r.payload as Record<string, unknown>), entered_by: r.author } }));
    const historical = await app.db.execute(sql`SELECT count(*)::int AS count FROM transferred_vehicles x WHERE x.org_id=${id} AND NOT EXISTS(SELECT 1 FROM analytics_tenures t WHERE t.org_id=x.org_id AND t.vehicle_id=x.vehicle_id)`);
    // Keep fuel/service readings for distance and efficiency; only the expense
    // ledger contributes money. Historical foreign costs remain in drilldowns.
    const costRecords = records.filter(r => r.kind !== 'expense' || r.payload.currency === settings.currency);
    const excluded = expenseRows(records, period).filter(r => r.currency !== settings.currency).length;
    return { settings, q, today, period, vehicles, records, costRecords, excluded, catalog: [...byId.values()], historical: Number(historical.rows[0]?.count ?? 0) };
  }
  app.get('/organizations/:id/analytics/report', async request => {
    const data = await load(request);
    return { ...calculateAnalytics(data.vehicles, data.costRecords, data.period), ...data.settings, today: data.today, catalog: data.catalog,
      warnings: [...(data.excluded ? [`${data.excluded} expenses in other currencies are excluded from totals. View records or export to see original amounts.`] : []), 'Only attributable organization records are included. Earlier records without ownership evidence are excluded.', ...(data.historical ? [`${data.historical} earlier vehicle transfers have no retained reporting history.`] : [])] };
  });
  app.get('/organizations/:id/analytics/records', async request => {
    const data = await load(request);
    const rows = expenseRows(data.records, data.period).filter(r => !data.q.category || r.category === data.q.category).sort((a,b) => b.date.localeCompare(a.date) || a.id.localeCompare(b.id));
    return { total: rows.length, page: data.q.page, items: rows.slice((data.q.page - 1) * 50, data.q.page * 50).map(r => ({ ...r, included_in_total: r.currency === data.settings.currency, vehicle: data.vehicles.find(v => v.id === r.vehicle_id)?.name,
      detail: data.records.find(x => x.id === r.source_id && x.kind === r.source_kind)?.payload ?? null })) };
  });
  app.get('/organizations/:id/analytics/export', async (request, reply) => {
    const data = await load(request);
    const common = { period_from: data.period.from, period_to: data.period.to, currency: data.settings.currency, reporting_currency: data.settings.currency, timezone: data.settings.timezone, distance_unit: 'km', vehicle_filter: data.q.vehicles ?? 'all', active_only: data.q.active, category_filter: data.q.category ?? 'all' };
    const report = calculateAnalytics(data.vehicles, data.costRecords, data.period);
    const rows = data.q.kind === 'vehicles' ? report.vehicles.map(v => ({ ...common, vehicle: v.name, plate: v.plate, status: v.status, total_cost: v.total_cost, liquid_cost: v.liquid_cost, electric_cost: v.electric_cost, unclassified_energy_cost: v.unclassified_energy_cost, energy_cost_per_km: v.energy_cost_per_km, recorded_km: v.distance_km, matched_cost: v.matched_cost, cost_per_km: v.cost_per_km, cost_per_day: v.cost_per_day, measured_from: v.measured_from, measured_to: v.measured_to, coverage: v.coverage ?? 'Complete', efficiency: v.efficiency.value, efficiency_unit: v.efficiency.unit, efficiency_method: v.efficiency.label })) : expenseRows(data.records, data.period).filter(r => !data.q.category || r.category === data.q.category).map(r => ({ ...common, ...r, included_in_total: r.currency === data.settings.currency, vehicle: data.vehicles.find(v => v.id === r.vehicle_id)?.name }));
    const headers = rows.length ? Object.keys(rows[0]) : [...Object.keys(common), ...(data.q.kind === 'vehicles' ? ['vehicle', 'plate', 'status', 'total_cost', 'liquid_cost', 'electric_cost', 'unclassified_energy_cost', 'energy_cost_per_km', 'recorded_km', 'matched_cost', 'cost_per_km', 'cost_per_day', 'measured_from', 'measured_to', 'coverage', 'efficiency', 'efficiency_unit', 'efficiency_method'] : ['id', 'vehicle_id', 'date', 'category', 'amount', 'description', 'entered_by', 'source_kind', 'source_id', 'included_in_total', 'vehicle'])];
    const csv = [headers.map(csvCell).join(','), ...rows.map(r => headers.map(h => csvCell((r as Record<string, unknown>)[h])).join(','))].join('\r\n');
    return reply.header('content-disposition', `attachment; filename="fleet-${data.q.kind}-${data.period.from}-${data.period.to}.csv"`).type('text/csv; charset=utf-8').send('\uFEFF' + csv);
  });
};
