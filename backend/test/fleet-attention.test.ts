import { describe, expect, it } from 'vitest';
import { maintenanceState, workOrderStalled } from '../src/lib/fleet-attention.js';
describe('Fleet attention rules', () => {
  it('marks either reached threshold overdue, including the due day', () => {
    expect(maintenanceState('2026-11-03', '2026-11-03', 501)).toBe('overdue');
    expect(maintenanceState('2026-11-03', '2026-12-30', 0)).toBe('overdue');
    expect(maintenanceState('2026-11-03', null, -1)).toBe('overdue');
  });
  it('includes upcoming boundaries without inventing missing schedules', () => {
    expect(maintenanceState('2026-11-03', '2026-12-03', null)).toBe('upcoming');
    expect(maintenanceState('2026-11-03', '2026-12-04', 500)).toBe('upcoming');
    expect(maintenanceState('2026-11-03', '2026-12-04', 501)).toBeNull();
    expect(maintenanceState('2026-11-03', null, null)).toBeNull();
  });
  it('uses three elapsed days without a promise, otherwise the promise takes precedence', () => {
    const now = new Date('2026-11-03T12:00:00Z');
    expect(workOrderStalled(now, new Date('2026-10-31T12:00:00Z'))).toBe(true);
    expect(workOrderStalled(now, new Date('2026-10-31T12:00:01Z'))).toBe(false);
    expect(workOrderStalled(now, new Date('2026-10-01'), '2026-11-03')).toBe(false);
    expect(workOrderStalled(now, now, '2026-11-02')).toBe(true);
  });
});
