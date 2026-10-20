/** Fleet reporting uses dated, organization-attributed snapshots, never live
 * records from a later owner's garage. All money comes from the expense ledger. */
export type ReportingVehicle = { id: string; name: string; plate: string; status: string; fuel: string; mileageUnit: string; tenures: { start: string; end: string | null }[] };
export type ReportingRecord = { id: string; vehicle_id: string; kind: string; payload: Record<string, unknown> };
export type Period = { from: string; to: string; calendar?: boolean };
const DAY = 86400000;
export const day = (date: string) => date.slice(0, 10);
const time = (date: string) => Date.parse(`${day(date)}T00:00:00Z`);
export const shiftDay = (date: string, n: number) => new Date(time(date) + n * DAY).toISOString().slice(0, 10);
export const days = (from: string, to: string) => Math.max(0, Math.round((time(to) - time(from)) / DAY) + 1);
const num = (v: unknown) => v == null || v === '' ? null : Number.isFinite(Number(v)) ? Number(v) : null;
const sum = (values: number[]) => values.reduce((a, b) => a + b, 0);
const inside = (date: string, p: Period) => date >= p.from && date <= p.to;
export function reportingToday(timezone: string, now = new Date()) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
}
export function previousPeriod(p: Period): Period {
  // Calendar presets start on day one; compare equivalent calendar spans,
  // clipping the final day for shorter months. Custom ranges use equal days.
  if (p.calendar && p.from.endsWith('-01')) {
    const start = new Date(`${p.from}T00:00:00Z`), end = new Date(`${p.to}T00:00:00Z`);
    const count = (end.getUTCFullYear() - start.getUTCFullYear()) * 12 + end.getUTCMonth() - start.getUTCMonth() + 1;
    const beforeStart = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() - count, 1));
    const beforeEndMonth = end.getUTCMonth() - count;
    const last = new Date(Date.UTC(end.getUTCFullYear(), beforeEndMonth + 1, 0)).getUTCDate();
    const beforeEnd = new Date(Date.UTC(end.getUTCFullYear(), beforeEndMonth, end.getUTCDate() === new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth()+1,0)).getUTCDate() ? last : Math.min(end.getUTCDate(), last)));
    return { from: beforeStart.toISOString().slice(0, 10), to: beforeEnd.toISOString().slice(0, 10) };
  }
  return { from: shiftDay(p.from, -days(p.from, p.to)), to: shiftDay(p.from, -1) };
}
function recordDate(r: ReportingRecord) {
  return day(String(r.payload.incurred_on ?? r.payload.serviced_on ?? r.payload.logged_on ?? ''));
}
export function expenseRows(records: ReportingRecord[], p: Period) {
  return records.filter(r => r.kind === 'expense' && inside(recordDate(r), p)).map(r => ({
    id: r.id, vehicle_id: r.vehicle_id, date: recordDate(r), category: String(r.payload.category),
    amount: num(r.payload.amount) ?? 0, description: String(r.payload.notes ?? r.payload.category ?? ''),
    entered_by: String(r.payload.entered_by ?? 'Unknown'),
    source_kind: r.payload.source_kind == null ? null : String(r.payload.source_kind),
    source_id: r.payload.source_id == null ? null : String(r.payload.source_id),
  }));
}
function reading(r: ReportingRecord, vehicle: ReportingVehicle) {
  const value = num(r.payload.odometer);
  return value == null || value < 0 ? null : value * ((r.payload.odometer_unit ?? vehicle.mileageUnit) === 'mi' ? 1.609344 : 1);
}
function distanceWindow(records: ReportingRecord[], vehicle: ReportingVehicle, p: Period) {
  if (vehicle.tenures.filter(t => t.start <= p.to && (!t.end || t.end >= p.from)).length > 1) return { km: null, from: null, to: null, reason: 'Multiple ownership intervals' };
  const readings = records.filter(r => r.kind !== 'expense' && inside(recordDate(r), p) && reading(r, vehicle) != null)
    .map(r => ({ date: recordDate(r), km: reading(r, vehicle)! })).sort((a, b) => a.date.localeCompare(b.date) || a.km - b.km);
  // Same-day readings cannot establish a chronological order; use the largest
  // reading for that day. Any decrease across days makes this window invalid.
  const dates = new Map<string, number>();
  for (const r of readings) dates.set(r.date, Math.max(dates.get(r.date) ?? 0, r.km));
  const values = [...dates].map(([date, km]) => ({ date, km }));
  if (values.length < 2) return { km: null, from: null, to: null, reason: 'Not enough dated readings' };
  if (values.some((r, i) => i > 0 && r.km < values[i - 1].km)) return { km: null, from: null, to: null, reason: 'Odometer decreased; check readings' };
  const first = values[0], last = values.at(-1)!;
  if (last.km <= first.km) return { km: null, from: first.date, to: last.date, reason: 'No recorded distance' };
  return { km: last.km - first.km, from: first.date, to: last.date, reason: first.date === p.from && last.date === p.to ? null : 'Partial date coverage' };
}
function efficiency(records: ReportingRecord[], v: ReportingVehicle, p: Period) {
  if (v.fuel === 'hybrid_plugin') return { value: null, unit: null, label: 'Combined energy cost only', km: 0, quantity: 0, group: null };
  const electric = v.fuel === 'electric';
  const logs = records.filter(r => r.kind === 'fuel_log' && inside(recordDate(r), p))
    .sort((a, b) => recordDate(a).localeCompare(recordDate(b)) || (reading(a, v) ?? 0) - (reading(b, v) ?? 0));
  let anchor: ReportingRecord | null = null, quantity = 0, totalQuantity = 0, km = 0, group: string | null = null;
  const groups = new Set<string>();
  let lastOdometer: number | null = null;
  const dateCounts = new Map<string, number>();
  for (const log of logs) dateCounts.set(recordDate(log), (dateCounts.get(recordDate(log)) ?? 0) + 1);
  for (const log of logs) {
    const r = log.payload, amount = num(r.amount), odo = reading(log, v);
    const validUnit = electric ? r.unit === 'kWh' && r.kind === 'charge' : r.unit === 'L' && r.kind === 'refuel';
    const identity = electric ? 'electric' : String(r.fuel_type_name).trim().toLowerCase();
    if (dateCounts.get(recordDate(log))! > 1) { anchor = null; quantity = 0; lastOdometer = null; continue; }
    if (!validUnit || amount == null || amount <= 0 || (!electric && !['full', 'partial'].includes(String(r.fill_status)))) { anchor = null; quantity = 0; lastOdometer = null; continue; }
    if (anchor && identity !== group) { anchor = null; quantity = 0; }
    if (anchor && (odo != null && lastOdometer != null && odo < lastOdometer || v.tenures.some(t => t.end && t.end >= recordDate(anchor!) && t.end < recordDate(log)))) { anchor = null; quantity = 0; }
    if (odo != null) lastOdometer = odo;
    if (anchor) quantity += amount;
    const closes = electric || r.fill_status === 'full';
    if (!closes) continue;
    if (anchor && odo != null) {
      const delta = odo - reading(anchor, v)!;
      // Same-day ordering and odometer decreases are not reliable intervals.
      if (delta > 0 && recordDate(log) > recordDate(anchor)) { km += delta; totalQuantity += quantity; groups.add(identity); }
    }
    anchor = odo == null ? null : log; group = identity; quantity = 0;
  }
  if (groups.size > 1) return { value: null, unit: null, label: 'Mixed fuel types', km: 0, quantity: 0, group: null };
  return { value: km > 0 ? totalQuantity / km * 100 : null, unit: electric ? 'kWh/100 km' : 'L/100 km',
    label: electric ? 'Estimated charging energy' : 'Full-to-full consumption', km, quantity: totalQuantity, group: groups.values().next().value ?? null };
}
function ownedDays(v: ReportingVehicle, p: Period) {
  const intervals = v.tenures.map(t => ({ from: t.start > p.from ? t.start : p.from, to: t.end && t.end < p.to ? t.end : p.to }))
    .filter(t => t.from <= t.to).sort((a, b) => a.from.localeCompare(b.from));
  let total = 0, last = '';
  for (const t of intervals) { const from = last && t.from <= last ? shiftDay(last, 1) : t.from; total += days(from, t.to); if (t.to > last) last = t.to; }
  return total;
}
export function calculatePeriod(vehicles: ReportingVehicle[], records: ReportingRecord[], p: Period) {
  const costs = expenseRows(records, p);
  const categories: Record<string, number> = {};
  for (const r of costs) categories[r.category] = (categories[r.category] ?? 0) + r.amount;
  const rows = vehicles.map(v => {
    const own = records.filter(r => r.vehicle_id === v.id), spend = costs.filter(r => r.vehicle_id === v.id);
    const window = distanceWindow(own, v, p);
    const matched = window.km == null ? [] : spend.filter(r => r.date >= window.from! && r.date <= window.to!);
    const intervalCost = sum(matched.map(r => r.amount)), total = sum(spend.map(r => r.amount));
    const ownershipDays = ownedDays(v, p);
    const energyKinds = new Map(own.filter(r => r.kind === 'fuel_log').map(r => [r.id, r.payload.kind]));
    const energyCost = (kind: string) => sum(spend.filter(r => r.source_kind === 'fuel_log' && energyKinds.get(r.source_id!) === kind).map(r => r.amount));
    return { ...v, total_cost: total, distance_km: window.km, measured_from: window.from, measured_to: window.to,
      coverage: window.reason, coverage_days: window.km == null ? 0 : days(window.from!, window.to!),
      period_days: days(p.from, p.to), cost_per_km: window.km == null ? null : intervalCost / window.km,
      matched_cost: intervalCost, cost_per_day: ownershipDays ? total / ownershipDays : null, ownership_days: ownershipDays,
      energy_cost_per_km: window.km == null ? null : sum(matched.filter(r => r.category === 'fuel').map(r => r.amount)) / window.km,
      liquid_cost: energyCost('refuel'), electric_cost: energyCost('charge'),
      unclassified_energy_cost: sum(spend.filter(r => r.category === 'fuel').map(r => r.amount)) - energyCost('refuel') - energyCost('charge'),
      efficiency: efficiency(own, v, p) };
  });
  const distance = sum(rows.map(r => r.distance_km ?? 0)), total = sum(costs.map(r => r.amount));
  const efficiencyGroups: Record<string, { quantity: number; km: number; unit: string; label: string }> = {};
  for (const row of rows) {
    const e = row.efficiency;
    if (e.group && e.unit && e.km > 0) {
      const group = efficiencyGroups[e.group] ??= { quantity: 0, km: 0, unit: e.unit, label: e.label };
      group.quantity += e.quantity; group.km += e.km;
    }
  }
  return { period: p, total_cost: total, distance_km: distance || null, cost_per_km: distance > 0 ? sum(rows.map(r => r.matched_cost)) / distance : null,
    cost_per_day: days(p.from, p.to) ? total / days(p.from, p.to) : null, categories, vehicles: rows,
    coverage_complete: rows.length > 0 && rows.every(r => r.coverage === null),
    efficiency: Object.entries(efficiencyGroups).map(([fuel, e]) => ({ fuel, ...e, value: e.quantity / e.km * 100 })) };
}
export function calculateAnalytics(vehicles: ReportingVehicle[], records: ReportingRecord[], p: Period) {
  const current = calculatePeriod(vehicles, records, p), previous = calculatePeriod(vehicles, records, previousPeriod(p));
  const months = [];
  let from = p.from;
  while (from <= p.to) {
    const end = new Date(Date.UTC(Number(from.slice(0, 4)), Number(from.slice(5, 7)), 0)).toISOString().slice(0, 10);
    const to = end < p.to ? end : p.to;
    const report = calculatePeriod(vehicles, records, { from, to });
    months.push({ month: from.slice(0, 7), from, to, total_cost: report.total_cost, cost_per_km: report.cost_per_km,
      cost_per_day: report.cost_per_day, categories: report.categories, efficiency: report.efficiency });
    from = shiftDay(to, 1);
  }
  const change = (value: number | null, baseline: number | null) => value == null || baseline == null || baseline === 0 ? null : (value - baseline) / baseline * 100;
  return { ...current, previous_period: previous.period, changes: {
    total_cost: change(current.total_cost, previous.total_cost),
    cost_per_km: current.coverage_complete && previous.coverage_complete ? change(current.cost_per_km, previous.cost_per_km) : null,
    cost_per_day: change(current.cost_per_day, previous.cost_per_day),
  }, months };
}
export function csvCell(value: unknown) {
  const raw = value == null ? '' : String(value);
  const safe = typeof value === 'string' && /^[\s]*[=+\-@\t\r]/.test(raw) ? `'${raw}` : raw;
  return `"${safe.replaceAll('"', '""')}"`;
}
