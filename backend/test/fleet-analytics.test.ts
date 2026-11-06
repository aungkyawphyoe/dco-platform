import { describe, expect, it } from 'vitest';
import { calculateAnalytics, calculatePeriod, csvCell, previousPeriod, type ReportingRecord, type ReportingVehicle } from '../src/lib/fleet-analytics.js';
const vehicle: ReportingVehicle = { id: 'a', name: 'Car', plate: 'ABC', status: 'active', fuel: 'petrol', mileageUnit: 'km', tenures: [{ start: '2025-01-01', end: null }] };
const period = { from: '2026-01-01', to: '2026-01-31' };
const fuel = (date: string, odo: number, amount = 20, status = 'full', id = 'a'): ReportingRecord => ({ id: crypto.randomUUID(), vehicle_id: id, kind: 'fuel_log', payload: { logged_on: date, odometer: odo, amount, unit: 'L', kind: 'refuel', fill_status: status, fuel_type_name: 'Diesel', cost: amount * 2 } });
const cost = (date: string, amount: number, id = 'a'): ReportingRecord => ({ id: crypto.randomUUID(), vehicle_id: id, kind: 'expense', payload: { incurred_on: date, category: 'fuel', amount } });
describe('Fleet Analytics calculations', () => {
  it('uses matched costs and weighted distance without double counting fuel logs', () => {
    const r = calculatePeriod([vehicle, { ...vehicle, id: 'b' }], [fuel('2026-01-05',100),fuel('2026-01-25',300),cost('2026-01-02',1000),cost('2026-01-20',100),fuel('2026-01-01',0,20,'full','b'),fuel('2026-01-31',100,20,'full','b'),cost('2026-01-20',100,'b')],period);
    expect(r.total_cost).toBe(1200); expect(r.distance_km).toBe(300); expect(r.cost_per_km).toBeCloseTo(200/300); expect(r.vehicles[0].coverage).toBe('Partial date coverage');
  });
  it('includes partial fills only between full tank anchors', () => {
    const logs = [fuel('2026-01-01',0,50),fuel('2026-01-10',100,10,'partial'),fuel('2026-01-20',400,20),fuel('2026-01-30',500,10,'partial')];
    expect(calculatePeriod([vehicle],logs,period).vehicles[0].efficiency.value).toBe(7.5);
    logs[1].payload.fill_status = 'unknown';
    expect(calculatePeriod([vehicle],logs,period).vehicles[0].efficiency.value).toBeNull();
  });
  it('does not combine incompatible fuels or rank hybrids as petrol cars', () => {
    const logs = [fuel('2026-01-01',0),fuel('2026-01-10',100),fuel('2026-01-20',200),fuel('2026-01-30',300)];
    logs[2].payload.fuel_type_name = logs[3].payload.fuel_type_name = 'Petrol';
    expect(calculatePeriod([vehicle],logs,period).vehicles[0].efficiency.value).toBeNull();
    expect(calculatePeriod([{...vehicle,fuel:'hybrid_plugin'}],logs,period).efficiency).toEqual([]);
  });
  it('labels electric charging estimates and excludes missing reading intervals', () => {
    const logs = [fuel('2026-01-01',0),fuel('2026-01-10',100),fuel('2026-01-20',200)];
    logs.forEach(l => { l.payload.kind='charge'; l.payload.unit='kWh'; });
    const e = calculatePeriod([{...vehicle,fuel:'electric'}],logs,period).vehicles[0].efficiency;
    expect(e.value).toBe(20); expect(e.label).toBe('Estimated charging energy');
    logs[1].payload.odometer = null;
    expect(calculatePeriod([{...vehicle,fuel:'electric'}],logs,period).vehicles[0].efficiency.value).toBeNull();
  });
  it('rejects resets and ownership gaps, normalizes miles, and keeps missing values null', () => {
    const logs = [fuel('2026-01-01',100),fuel('2026-01-31',200)];
    expect(calculatePeriod([{...vehicle,mileageUnit:'mi'}],logs,period).distance_km).toBeCloseTo(160.9344);
    expect(calculatePeriod([vehicle],[],period).cost_per_km).toBeNull();
    logs[1].payload.odometer=50;
    expect(calculatePeriod([vehicle],logs,period).distance_km).toBeNull();
    expect(calculatePeriod([{...vehicle,tenures:[{start:'2026-01-01',end:'2026-01-10'},{start:'2026-01-20',end:null}]}],logs,period).distance_km).toBeNull();
  });
  it('uses ownership days, matching elapsed calendar comparisons, and no zero baselines', () => {
    expect(calculatePeriod([{...vehicle,tenures:[{start:'2026-01-15',end:null}]}],[cost('2026-01-20',170)],period).vehicles[0].cost_per_day).toBe(10);
    expect(previousPeriod({from:'2026-03-01',to:'2026-03-19',calendar:true})).toEqual({from:'2026-02-01',to:'2026-02-19'});
    expect(previousPeriod({from:'2026-03-01',to:'2026-03-19'})).toEqual({from:'2026-02-10',to:'2026-02-28'});
    expect(calculateAnalytics([vehicle],[],period).changes.total_cost).toBeNull();
  });
  it('takes hybrid energy costs from linked ledger entries and identifies unclassified legacy fuel spend', () => {
    const log = fuel('2026-01-10',100,20);
    const expense = cost('2026-01-10',45);
    expense.payload.source_kind = 'fuel_log'; expense.payload.source_id = log.id;
    const row = calculatePeriod([{...vehicle,fuel:'hybrid_plugin'}],[log,expense,cost('2026-01-12',5)],period).vehicles[0];
    expect(row.liquid_cost).toBe(45); expect(row.unclassified_energy_cost).toBe(5); expect(row.efficiency.value).toBeNull();
  });
  it('breaks fuel intervals on decreasing partial readings and ambiguous same-day fills', () => {
    const logs = [fuel('2026-01-01',0),fuel('2026-01-10',200,10,'partial'),fuel('2026-01-15',100,10,'partial'),fuel('2026-01-20',300)];
    expect(calculatePeriod([vehicle],logs,period).vehicles[0].efficiency.value).toBeNull();
    const ambiguous = [fuel('2026-01-01',0),fuel('2026-01-20',300),fuel('2026-01-20',350)];
    expect(calculatePeriod([vehicle],ambiguous,period).vehicles[0].efficiency.value).toBeNull();
  });
  it('escapes spreadsheet formula injection and CSV delimiters', () => {
    expect(csvCell('=SUM(A1)')).toBe('"\'=SUM(A1)"'); expect(csvCell('a,"b"')).toBe('"a,""b"""'); expect(csvCell(-5)).toBe('"-5"');
  });
  it('splits maintenance by service item and reports unallocated spend', () => {
    const service: ReportingRecord = { id: 's1', vehicle_id: 'a', kind: 'service_record', payload: {
      serviced_on: '2026-01-10', total_cost: 100,
      items: [{ name: 'Oil change', line_cost: 40 }, { name: 'oil change', line_cost: 20 }, { name: 'Brake pads', line_cost: 25 }],
    } };
    const linked: ReportingRecord = { id: 'e1', vehicle_id: 'a', kind: 'expense', payload: {
      incurred_on: '2026-01-10', category: 'maintenance', amount: 100, source_kind: 'service_record', source_id: 's1',
    } };
    const manual: ReportingRecord = { id: 'e2', vehicle_id: 'a', kind: 'expense', payload: { incurred_on: '2026-01-11', category: 'maintenance', amount: 30 } };
    expect(calculatePeriod([vehicle], [service, linked, manual], period).service_types).toEqual({
      'Oil change': 60, 'Brake pads': 25, Unallocated: 45,
    });
    // Line costs are informational. Over-allocated records are scaled to the
    // authoritative maintenance total instead of overflowing the chart.
    const over: ReportingRecord = { id: 's2', vehicle_id: 'a', kind: 'service_record', payload: {
      serviced_on: '2026-01-12', total_cost: 100, items: [{ name: 'Engine', line_cost: 150 }],
    } };
    const overExpense: ReportingRecord = { id: 'e3', vehicle_id: 'a', kind: 'expense', payload: {
      incurred_on: '2026-01-12', category: 'maintenance', amount: 100, source_kind: 'service_record', source_id: 's2',
    } };
    expect(calculatePeriod([vehicle], [over, overExpense], period).service_types).toEqual({ Engine: 100 });
  });
});
