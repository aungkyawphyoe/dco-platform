import { afterEach, expect, it } from 'vitest';
import { eq } from 'drizzle-orm';
import { createTestApp, testEnv, uuid } from './helpers.js';
import { analyticsFixture } from './analytics-fixture.js';
import { organizationMembers, organizationVehicles, planItems, serviceRecords, transferredVehicles, users } from '../src/db/schema.js';

const cleanup: Array<() => Promise<unknown>> = [];
afterEach(async () => { for (const close of cleanup.splice(0)) await close(); });
type App = Awaited<ReturnType<typeof createTestApp>>['app'];
const auth = (token: string) => ({ authorization: `Bearer ${token}` });
async function owner(app: App) {
  const email = `${uuid()}@test.local`;
  const response = await app.inject({ method: 'POST', url: '/v1/auth/signup', payload: { email, password: 'password1' } });
  expect(response.statusCode).toBe(201);
  return { ...response.json(), email };
}
async function vehicle(app: App, token: string) {
  const id = uuid();
  const response = await app.inject({ method: 'POST', url: '/v1/vehicles', headers: auth(token), payload: {
    id, name: 'Private car', make: 'Toyota', model: 'Corolla', year: 2021, license_plate: id.slice(0, 8), fuel_type: 'petrol', mileage: 100,
  } });
  expect(response.statusCode).toBe(201);
  return id;
}
it('rejects duplicate IDs and foreign service references before any write, including sync', async () => {
  const { app, db } = await createTestApp(); cleanup.push(() => app.close());
  const a = await owner(app), b = await owner(app);
  const av = await vehicle(app, a.access_token), bv = await vehicle(app, b.access_token);
  const planId = uuid();
  const plan = { id: planId, name: 'Private plan', interval_distance: 5000, next_due_mileage: 5100 };
  expect((await app.inject({ method: 'POST', url: `/v1/vehicles/${bv}/plan-items`, headers: auth(b.access_token), payload: plan })).statusCode).toBe(201);
  const collision = await app.inject({ method: 'POST', url: `/v1/vehicles/${av}/plan-items`, headers: auth(a.access_token), payload: plan });
  expect(collision.statusCode).toBe(409);
  expect(collision.body).not.toContain('Private plan');
  const service = { id: uuid(), serviced_on: '2026-10-01', odometer: 6000, total_cost: 100, items: [{ name: 'Oil', plan_item_id: planId }] };
  const badReference = await app.inject({ method: 'POST', url: `/v1/vehicles/${av}/service-records`, headers: auth(a.access_token), payload: service });
  expect(badReference.statusCode).toBe(422);
  expect(await db.select().from(serviceRecords).where(eq(serviceRecords.id, service.id))).toHaveLength(0);
  expect(Number((await db.select().from(planItems).where(eq(planItems.id, planId)))[0].nextDueMileage)).toBe(5100);
  const sync = await app.inject({ method: 'POST', url: '/v1/sync/push', headers: auth(a.access_token), payload: { operations: [{ entity_type: 'service_record', entity_id: service.id, op: 'upsert', client_ts: new Date().toISOString(), payload: { ...service, vehicle_id: av } }] } });
  expect(sync.json().results[0].status).toBe('rejected');
  const valid = { ...service, id: uuid(), items: [{ name: 'Oil' }] };
  expect((await app.inject({ method: 'POST', url: `/v1/vehicles/${av}/service-records`, headers: auth(a.access_token), payload: valid })).statusCode).toBe(201);
  expect((await app.inject({ method: 'POST', url: `/v1/vehicles/${bv}/service-records`, headers: auth(b.access_token), payload: valid })).statusCode).toBe(409);
  const excess = await app.inject({ method: 'POST', url: '/v1/sync/push', headers: auth(a.access_token), payload: { operations: Array(101).fill({ entity_type: 'vehicle', entity_id: av, op: 'archive', payload: {}, client_ts: new Date().toISOString() }) } });
  expect(excess.statusCode).toBe(422);
});
it('revokes stale admin access and only consumes a refresh token once', async () => {
  const { app, db } = await createTestApp(); cleanup.push(() => app.close());
  const a = await owner(app);
  const refreshes = await Promise.all([1, 2].map(() => app.inject({ method: 'POST', url: '/v1/auth/refresh', payload: { refresh_token: a.refresh_token } })));
  expect(refreshes.map(r => r.statusCode).sort()).toEqual([200, 401]);
  await db.update(users).set({ role: 'admin' }).where(eq(users.id, a.user.id));
  const session = await app.inject({ method: 'POST', url: '/v1/auth/login', payload: { email: a.email, password: 'password1' } });
  const root = await app.inject({ method: 'POST', url: '/v1/auth/login', payload: { email: testEnv.BOOTSTRAP_ADMIN_EMAIL, password: testEnv.BOOTSTRAP_ADMIN_PASSWORD } });
  const demotion = await app.inject({ method: 'PATCH', url: `/v1/admin/users/${a.user.id}`, headers: auth(root.json().access_token), payload: { role: 'owner' } });
  expect(demotion.statusCode).toBe(200);
  expect((await app.inject({ method: 'POST', url: '/v1/auth/refresh', payload: { refresh_token: session.json().refresh_token } })).statusCode).toBe(401);
  expect((await app.inject({ method: 'GET', url: '/v1/admin/users', headers: auth(session.json().access_token) })).statusCode).toBe(401);
  expect((await app.inject({ method: 'POST', url: '/v1/admin/reset-users' })).statusCode).not.toBe(200);
});
it('keeps membership suspension local and rejects enrollment or driver conversion of personal identities', async () => {
  const { app, db, orgId, headers } = await analyticsFixture(); cleanup.push(() => app.close());
  const member = await owner(app);
  const capture = await app.inject({ method: 'POST', url: `/v1/organizations/${orgId}/members`, headers, payload: { email: member.email, role: 'org_manager' } });
  expect(capture.statusCode).toBe(409);
  // Existing memberships remain supported, but grant no global account authority.
  await db.insert(organizationMembers).values({ id: uuid(), orgId, userId: member.user.id, role: 'org_manager' });
  const login = await app.inject({ method: 'POST', url: '/v1/auth/login', payload: { email: member.email, password: 'password1', surface: 'fleet' } });
  expect(login.statusCode).toBe(200);
  const convert = await app.inject({ method: 'PATCH', url: `/v1/organizations/${orgId}/members/${member.user.id}`, headers, payload: { role: 'org_driver' } });
  expect(convert.statusCode).toBe(409);
  expect((await app.inject({ method: 'POST', url: `/v1/organizations/${orgId}/members/${member.user.id}/status`, headers, payload: { status: 'deactivated' } })).statusCode).toBe(200);
  expect((await app.inject({ method: 'GET', url: '/v1/me', headers: auth(member.access_token) })).statusCode).toBe(200);
  expect((await app.inject({ method: 'GET', url: `/v1/organizations/${orgId}/vehicles`, headers: auth(login.json().access_token) })).statusCode).toBe(403);
  expect((await db.select().from(users).where(eq(users.id, member.user.id)))[0].status).toBe('active');
});
it('freezes transferred history and vehicle details instead of exposing buyer changes', async () => {
  const { app, db, orgId, vehicleId, headers, userId } = await analyticsFixture(); cleanup.push(() => app.close());
  const buyer = await owner(app);
  await db.update(organizationVehicles).set({ lifecycleTemplate: 'showroom', status: 'reserved' }).where(eq(organizationVehicles.vehicleId, vehicleId));
  await db.insert(serviceRecords).values({ id: uuid(), vehicleId, servicedOn: '2026-09-01', odometer: '11000', totalCost: '50', notes: 'Seller record', createdBy: userId });
  const sold = await app.inject({ method: 'POST', url: `/v1/organizations/${orgId}/vehicles/${vehicleId}/transfer`, headers, payload: { buyer_email: buyer.email, sale_date: '2026-10-01', current_mileage_km: 12000 } });
  expect(sold.statusCode, sold.body).toBe(201);
  await db.insert(serviceRecords).values({ id: uuid(), vehicleId, servicedOn: '2026-10-20', odometer: '13000', totalCost: '90', notes: 'Buyer private record', createdBy: buyer.user.id });
  const history = await app.inject({ method: 'GET', url: `/v1/organizations/${orgId}/transferred/${vehicleId}/history`, headers });
  expect(history.statusCode).toBe(200);
  expect(history.json().service_records).toHaveLength(1);
  expect(history.body).toContain('Seller record');
  expect(history.body).not.toContain('Buyer private record');
  // Old transfers never fall back to querying current records.
  await db.update(transferredVehicles).set({ serviceSnapshot: [] }).where(eq(transferredVehicles.vehicleId, vehicleId));
  const legacy = await app.inject({ method: 'GET', url: `/v1/organizations/${orgId}/transferred/${vehicleId}/history`, headers });
  expect(legacy.json().service_records).toEqual([]);
});
it('throttles share-code guessing independently of the public endpoint limiter', async () => {
  const { app } = await createTestApp(); cleanup.push(() => app.close());
  const a = await owner(app);
  for (let i = 0; i < 30; i++) {
    const response = await app.inject({ method: 'GET', url: '/v1/vehicles/shares/ABCDEFGH', headers: auth(a.access_token) });
    expect(response.statusCode).not.toBe(429);
  }
  const limited = await app.inject({ method: 'GET', url: '/v1/vehicles/shares/ABCDEFGH', headers: auth(a.access_token) });
  expect(limited.statusCode).toBe(429);
  expect(limited.headers['retry-after']).toBeTruthy();
});
