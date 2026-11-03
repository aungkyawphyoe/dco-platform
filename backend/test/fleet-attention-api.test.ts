import { expect, it } from 'vitest';
import { eq } from 'drizzle-orm';
import { analyticsFixture } from './analytics-fixture.js';
import { documents, planItems, workOrders, organizationMembers, organizationVehicles, inspections, inspectionTemplates } from '../src/db/schema.js';

it('prioritizes current organization records, excludes upcoming duplicates, and preserves role boundaries', async () => {
  const { app, db, client, headers, orgId, vehicleId, userId } = await analyticsFixture();
  const id = () => crypto.randomUUID();
  try {
    const templateId = id();
    await db.insert(documents).values({ id: id(), vehicleId, name: 'Insurance policy', category: 'insurance', expiresOn: '2000-01-01' });
    await db.insert(documents).values({ id: id(), vehicleId, name: 'Old receipt', category: 'receipt', expiresOn: '2000-01-01' });
    await db.insert(planItems).values([
      { id: id(), vehicleId, name: 'Overdue oil', nextDueMileage: '12000', enabled: true },
      { id: id(), vehicleId, name: 'Upcoming tires', nextDueMileage: '12500', enabled: true },
      { id: id(), vehicleId, name: 'Disabled', nextDueMileage: '1', enabled: false },
    ]);
    await db.insert(workOrders).values([
      { id: id(), orgId, vehicleId, reportedBy: userId, odometerKm: 12000, issueType: 'breakdown', description: 'Brake system failure', urgency: 'critical', updatedAt: new Date('2000-01-01') },
      { id: id(), orgId, vehicleId, reportedBy: userId, odometerKm: 12000, issueType: 'other', description: 'Old open order', urgency: 'low', updatedAt: new Date('2000-01-01') },
      { id: id(), orgId, vehicleId, reportedBy: userId, odometerKm: 12000, issueType: 'other', description: 'Resolved brake repair', urgency: 'critical', status: 'completed' },
    ]);
    await db.insert(inspectionTemplates).values({ id: templateId, orgId, name: 'Daily check' });
    await db.insert(inspections).values({ id: id(), orgId, vehicleId, driverId: userId, templateId, inspectionType: 'pre_trip', status: 'failed', completedAt: new Date('2000-01-01') });
    const url = `/v1/organizations/${orgId}/analytics/attention`;
    const response = await app.inject({ url, headers });
    expect(response.statusCode, response.body).toBe(200);
    const items = response.json().items;
    expect(items.map((item: { group: string }) => item.group)).toEqual(['urgent', 'urgent', 'overdue', 'stalled', 'review']);
    expect(items.some((item: { title: string }) => item.title === 'Disabled')).toBe(false);
    await db.insert(inspections).values({ id: id(), orgId, vehicleId, driverId: userId, templateId, inspectionType: 'pre_trip', status: 'completed', completedAt: new Date() });
    expect((await app.inject({ url, headers })).json().items.some((item: { title: string }) => item.title.startsWith('Failed inspection'))).toBe(false);
    expect((await app.inject({ url: `/v1/organizations/${id()}/analytics/attention`, headers })).statusCode).toBe(403);
    await db.update(organizationMembers).set({ role: 'org_manager' }).where(eq(organizationMembers.userId, userId));
    const manager = await app.inject({ url, headers });
    expect(manager.statusCode).toBe(200);
    expect(manager.json().items.some((item: { title: string }) => item.title === 'Expired insurance')).toBe(false);
    await db.update(organizationMembers).set({ role: 'org_mechanic' }).where(eq(organizationMembers.userId, userId));
    expect((await app.inject({ url, headers })).statusCode).toBe(403);
    await db.update(organizationMembers).set({ role: 'org_admin' }).where(eq(organizationMembers.userId, userId));
    await db.delete(organizationVehicles).where(eq(organizationVehicles.vehicleId, vehicleId));
    expect((await app.inject({ url, headers })).json()).toMatchObject({ vehicle_count: 0, open_work_orders: 0, items: [] });
  } finally { await app.close(); await client.close(); }
}, 30000);
