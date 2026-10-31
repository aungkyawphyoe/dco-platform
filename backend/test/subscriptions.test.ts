import { beforeAll, afterAll, describe, expect, it } from 'vitest';
import { eq } from 'drizzle-orm';
import { decodeJwt } from 'jose';
import { createTestApp, testEnv, uuid } from './helpers.js';
import { users, subscriptionTerms, organizations, organizationMembers, plans, vehicles, playSubscriptions } from '../src/db/schema.js';
import { signAccess } from '../src/lib/crypto.js';
import { effectiveSubscription } from '../src/lib/gifts.js';
import { sendSubscriptionReminders } from '../src/lib/subscription-reminders.js';
import { applyInitSql } from '../src/db/migrate.js';
import { DAY, termEnd, termStatus, organizationBilling } from '../src/lib/subscriptions.js';
describe('admin billing', () => {
    let ctx: Awaited<ReturnType<typeof createTestApp>>, admin: {
        authorization: string;
    };
    beforeAll(async () => { ctx = await createTestApp(); const [a] = await ctx.db.select().from(users).where(eq(users.role, 'admin')); admin = { authorization: `Bearer ${(await signAccess(testEnv, { sub: a.id, role: 'admin', plan: 'free', aud: testEnv.JWT_ADMIN_AUD })).token}` }; });
    afterAll(async () => { await ctx.app.close(); await ctx.client.close(); });
    async function owner() { const id = uuid(); await ctx.db.insert(users).values({ id, email: `${id}@test.local`, username: id, role: 'owner', emailVerified: true }); return { id, headers: { authorization: `Bearer ${(await signAccess(testEnv, { sub: id, role: 'owner', plan: 'free' })).token}` } }; }
    function payload(id: string) { return { kind: 'user', id, request_id: uuid(), plan: 'lite', source: 'direct', starts_at: new Date().toISOString(), unit: 'years', count: 1, price_version: 1, payment: { amount: 30000, currency: 'MMK', paid_at: new Date().toISOString(), method: 'cash' } }; }
    it('clamps calendar months and applies exact grace boundaries', () => { expect(termEnd(new Date('2028-02-29T12:00:00Z'), 'years', 1).toISOString()).toBe('2029-02-28T12:00:00.000Z'); const t = { startsAt: new Date('2026-01-01Z'), endsAt: new Date('2026-02-01Z'), source: 'direct', revokedAt: null }; expect(termStatus(t, new Date('2026-02-01Z'))).toBe('grace'); expect(termStatus(t, new Date('2026-02-08Z'))).toBe('expired'); expect(termStatus({ ...t, source: 'complimentary' }, t.endsAt)).toBe('expired'); });
    it('records payment once, resolves access, signs bounded licenses and rejects overlapping terms', async () => { const o = await owner(), b = payload(o.id); const create = () => ctx.app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: admin, payload: b }); const r = await create(); expect(r.statusCode, r.body).toBe(200); expect((await create()).json().id).toBe(r.json().id); expect((await effectiveSubscription(ctx.db, o.id)).plan).toBe('lite'); const license = await ctx.app.inject({ method: 'GET', url: '/v1/me/license', headers: o.headers }); expect(decodeJwt(license.json().license).exp! * 1000).toBeLessThanOrEqual(Date.now() + DAY); const overlap = await ctx.app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: admin, payload: { ...b, request_id: uuid() } }); expect(overlap.statusCode).toBe(409); const renew = await ctx.app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: admin, payload: { ...b, request_id: uuid(), renew: true } }); expect(renew.statusCode, renew.body).toBe(200); expect(renew.json().startsAt).toBe(r.json().endsAt); });
    it('preserves term history on correction, upgrades with unchanged expiry and revokes without grace', async () => { const o = await owner(); const r = await ctx.app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: admin, payload: payload(o.id) }); const t = r.json(); const upgrade = await ctx.app.inject({ method: 'PATCH', url: `/v1/admin/subscriptions/${t.id}`, headers: admin, payload: { version: 1, action: 'upgrade', reason: 'Complimentary upgrade' } }); expect(upgrade.statusCode, upgrade.body).toBe(200); expect(upgrade.json().endsAt).toBe(t.endsAt); expect((await effectiveSubscription(ctx.db, o.id)).plan).toBe('standard'); const revoke = await ctx.app.inject({ method: 'PATCH', url: `/v1/admin/subscriptions/${t.id}`, headers: admin, payload: { version: 2, action: 'revoke', reason: 'Correction' } }); expect(revoke.statusCode).toBe(200); expect((await effectiveSubscription(ctx.db, o.id)).plan).toBe('free'); expect(revoke.json().payment.amount).toBe(30000); });
    it('publishes prices with optimistic locking and keeps Free zero', async () => { const body = { version: 1, monthly_mmk: 4000, annual_mmk: 40000, monthly_usd: 1.5, annual_usd: 15 }; const r = await ctx.app.inject({ method: 'PATCH', url: '/v1/admin/prices/lite', headers: admin, payload: body }); expect(r.statusCode, r.body).toBe(200); const p = (await ctx.app.inject({ method: 'GET', url: '/v1/pricing' })).json().plans.find((p: {
        id: string;
    }) => p.id === 'lite'); expect(p.prices.monthly).toEqual({ mmk: 4000, usd: 1.5 }); expect((await ctx.app.inject({ method: 'PATCH', url: '/v1/admin/prices/lite', headers: admin, payload: body })).statusCode).toBe(409); expect((await ctx.app.inject({ method: 'PATCH', url: '/v1/admin/prices/free', headers: admin, payload: body })).statusCode).toBe(422); await ctx.db.update(plans).set({ priceMonthlyMmk: 3000, priceAnnualMmk: 30000, priceMonthlyUsd: '1', priceAnnualUsd: '10', priceVersion: 1 }).where(eq(plans.id, 'lite')); });
    it('rejects non-admin mutations', async () => { const o = await owner(); expect((await ctx.app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: o.headers, payload: payload(o.id) })).statusCode).toBe(403); });
    it('retains Fleet reads while enforcing expired operational writes', async () => { const o = await owner(), org = uuid(); await ctx.db.insert(organizations).values({ id: org, name: 'Fleet', type: 'commercial', adminUserId: o.id, createdBy: o.id, status: 'active' }); await ctx.db.insert(organizationMembers).values({ id: uuid(), orgId: org, userId: o.id, role: 'org_admin' }); const token = (await signAccess(testEnv, { sub: o.id, role: 'owner', plan: 'free', aud: testEnv.JWT_FLEET_AUD })).token; const headers = { authorization: `Bearer ${token}` }; const r = await ctx.app.inject({ method: 'GET', url: `/v1/organizations/${org}/subscription`, headers }); expect(r.statusCode, r.body).toBe(200); expect(r.json().writable).toBe(false); const denied = await ctx.app.inject({ method: 'POST', url: `/v1/organizations/${org}/vehicles`, headers, payload: {} }); expect(denied.statusCode).toBeGreaterThanOrEqual(400); const grant = await ctx.app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: admin, payload: { kind: 'organization', id: org, request_id: uuid(), plan: 'fleet', source: 'complimentary', reason: 'Trial contract', starts_at: new Date().toISOString(), unit: 'days', count: 30 } }); expect(grant.statusCode, grant.body).toBe(200); expect((await ctx.app.inject({ method: 'GET', url: `/v1/organizations/${org}/subscription`, headers })).json().writable).toBe(true); });
    it('retains excess vehicles and locks the Free editable selection after expiry', async () => {
        const o = await owner();
        const r = await ctx.app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: admin, payload: payload(o.id) });
        const ids = [uuid(), uuid()];
        for (const id of ids)
            await ctx.db.insert(vehicles).values({ id, userId: o.id, name: 'Car', make: 'Toyota', model: 'Corolla', year: 2020, licensePlate: id.slice(0, 8), fuelType: 'petrol', mileage: '100' });
        await ctx.db.update(subscriptionTerms).set({ startsAt: new Date(Date.now() - 20 * DAY), endsAt: new Date(Date.now() - 8 * DAY) }).where(eq(subscriptionTerms.id, r.json().id));
        const write = () => ctx.app.inject({ method: 'PATCH', url: `/v1/vehicles/${ids[0]}`, headers: o.headers, payload: { name: 'Updated' } });
        expect((await write()).json().error.code).toBe('vehicle_read_only');
        expect((await ctx.app.inject({ method: 'GET', url: `/v1/vehicles/${ids[0]}`, headers: o.headers })).statusCode).toBe(200);
        expect((await ctx.app.inject({ method: 'POST', url: '/v1/me/free-vehicle', headers: o.headers, payload: { vehicle_id: ids[0] } })).statusCode).toBe(200);
        expect((await write()).statusCode).toBe(200);
        expect((await ctx.app.inject({ method: 'POST', url: '/v1/me/free-vehicle', headers: o.headers, payload: { vehicle_id: ids[1] } })).statusCode).toBe(409);
        expect(await ctx.db.select().from(vehicles).where(eq(vehicles.userId, o.id))).toHaveLength(2);
    });
    it('blocks store conflicts and rejects reused request IDs with different payloads', async () => {
        const o = await owner();
        await ctx.db.insert(playSubscriptions).values({ purchaseToken: uuid(), userId: o.id, productId: 'lite', basePlanId: 'monthly', plan: 'lite', state: 'SUBSCRIPTION_STATE_CANCELED', expiresAt: new Date(Date.now() + DAY), autoRenewing: false, acknowledged: true });
        expect((await ctx.app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: admin, payload: payload(o.id) })).statusCode).toBe(409);
        const another = await owner(), b = payload(another.id);
        expect((await ctx.app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: admin, payload: b })).statusCode).toBe(200);
        expect((await ctx.app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: admin, payload: { ...b, count: 2 } })).statusCode).toBe(409);
    });
    it('deduplicates renewal reminders and preserves migrated flags and prices on restart', async () => {
        const o = await owner();
        const r = await ctx.app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: admin, payload: payload(o.id) });
        await ctx.db.update(subscriptionTerms).set({ endsAt: new Date(Date.now() + 2 * DAY) }).where(eq(subscriptionTerms.id, r.json().id));
        const sent: string[] = [];
        const mailer = { sendSubscriptionReminder: async (to: string) => { sent.push(to); } } as unknown as import('../src/lib/mail.js').Mailer;
        await sendSubscriptionReminders(ctx.db, mailer);
        await sendSubscriptionReminders(ctx.db, mailer);
        expect(sent.filter(x => x === `${o.id}@test.local`)).toHaveLength(1);
        const org = uuid();
        await ctx.db.insert(organizations).values({ id: org, name: 'Legacy', type: 'commercial', adminUserId: o.id, createdBy: o.id, billingMigrated: false });
        await ctx.db.update(plans).set({ priceMonthlyMmk: 4321 }).where(eq(plans.id, 'lite'));
        await applyInitSql(sql => ctx.client.exec(sql));
        expect((await ctx.db.select().from(organizations).where(eq(organizations.id, org)))[0].billingMigrated).toBe(false);
        expect((await ctx.db.select().from(plans).where(eq(plans.id, 'lite')))[0].priceMonthlyMmk).toBe(4321);
    });

    it('lists source-aware subscriptions and provides authoritative renewal previews', async () => {
        const o=await owner(), b=payload(o.id);
        const r=await ctx.app.inject({method:'POST',url:'/v1/admin/subscriptions',headers:admin,payload:{...b,price_version:1,payment:{...b.payment,override_reason:'Test negotiated contract'}}});
        expect(r.statusCode,r.body).toBe(200);
        const list=await ctx.app.inject({method:'GET',url:`/v1/admin/subscriptions?kind=user&id=${o.id}&status=active&plan=lite`,headers:admin});
        expect(list.statusCode,list.body).toBe(200);expect(list.json().items).toHaveLength(1);
        const preview=await ctx.app.inject({method:'POST',url:'/v1/admin/subscriptions/preview',headers:admin,payload:{kind:'user',id:o.id,starts_at:b.starts_at,unit:'years',count:1,renew:true,source:'direct'}});
        expect(preview.statusCode,preview.body).toBe(200);expect(preview.json().starts_at).toBe(r.json().endsAt);
    });

    it('automatically enforces Fleet terms even with a stale migration flag',async()=>{
        const o=await owner(),id=uuid();
        await ctx.db.insert(organizations).values({id,name:'Review fleet',type:'commercial',adminUserId:o.id,createdBy:o.id,billingMigrated:false,status:'active'});
        expect((await organizationBilling(ctx.db,id)).writable).toBe(true);
        const migrate=()=>ctx.app.inject({method:'POST',url:`/v1/admin/organizations/${id}/migrate-billing`,headers:admin});
        expect((await migrate()).statusCode).toBe(422);
        const grant=await ctx.app.inject({method:'POST',url:'/v1/admin/subscriptions',headers:admin,payload:{kind:'organization',id,request_id:uuid(),plan:'fleet',source:'complimentary',reason:'Contract review',starts_at:new Date().toISOString(),unit:'years',count:1}});
        expect(grant.statusCode,grant.body).toBe(200);
        expect((await ctx.db.select().from(organizations).where(eq(organizations.id,id)))[0].billingMigrated).toBe(true);
        expect(await organizationBilling(ctx.db,id)).toMatchObject({migrated:true,writable:true,status:'active'});
        // Reproduce records from older deployments that failed to set the flag.
        await ctx.db.update(organizations).set({billingMigrated:false}).where(eq(organizations.id,id));
        expect(await organizationBilling(ctx.db,id)).toMatchObject({migrated:true,writable:true,status:'active'});
        await ctx.db.update(subscriptionTerms).set({startsAt:new Date(Date.now()-2*DAY),endsAt:new Date(Date.now()-DAY)}).where(eq(subscriptionTerms.id,grant.json().id));
        expect(await organizationBilling(ctx.db,id)).toMatchObject({migrated:true,writable:false,status:'read_only'});
        await ctx.db.update(subscriptionTerms).set({startsAt:new Date(grant.json().startsAt),endsAt:new Date(grant.json().endsAt)}).where(eq(subscriptionTerms.id,grant.json().id));
        expect((await ctx.app.inject({method:'PATCH',url:`/v1/admin/subscriptions/${grant.json().id}`,headers:admin,payload:{version:1,action:'revoke',reason:'Review correction'}})).statusCode).toBe(200);
        expect(await organizationBilling(ctx.db,id)).toMatchObject({migrated:true,writable:false,status:'read_only'});
    });
    it('cleans pre-launch accounts once while preserving real access and stored records', async () => {
        const legacy = await owner(), paid = await owner(), store = await owner();
        await ctx.db.update(users).set({ plan: 'standard' }).where(eq(users.id, legacy.id));
        const org = uuid(), activeOrg = uuid();
        for (const id of [org, activeOrg]) await ctx.db.insert(organizations).values({ id, name: 'Test fleet', type: 'commercial', adminUserId: id === org ? legacy.id : paid.id, createdBy: legacy.id, billingMigrated: false, status: 'active' });
        const vehicleId = uuid();
        await ctx.db.insert(vehicles).values({ id: vehicleId, userId: legacy.id, name: 'Keep me', make: 'Toyota', model: 'Corolla', year: 2020, licensePlate: vehicleId.slice(0, 8), fuelType: 'petrol', mileage: '100' });
        for (const [kind, id, plan] of [['user', paid.id, 'lite'], ['organization', activeOrg, 'fleet']]) {
            const result = await ctx.app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: admin, payload: { kind, id, plan, request_id: uuid(), source: 'complimentary', reason: 'Existing test access', starts_at: new Date().toISOString(), unit: 'years', count: 1 } });
            expect(result.statusCode, result.body).toBe(200);
        }
        await ctx.db.insert(playSubscriptions).values({ purchaseToken: uuid(), userId: store.id, productId: 'standard', basePlanId: 'monthly', plan: 'standard', state: 'SUBSCRIPTION_STATE_ACTIVE', expiresAt: new Date(Date.now() + DAY), autoRenewing: true, acknowledged: true });
        const termsBefore = await ctx.db.select().from(subscriptionTerms);
        const storeBefore = await ctx.db.select().from(playSubscriptions);
        // Simulate an existing deployment immediately before this migration.
        await ctx.client.exec("DELETE FROM billing_migrations WHERE name = 'prelaunch_test_accounts'");
        await applyInitSql(sql => ctx.client.exec(sql));
        expect(await effectiveSubscription(ctx.db, legacy.id)).toMatchObject({ plan: 'free', user: { billingManaged: true } });
        expect((await effectiveSubscription(ctx.db, paid.id)).plan).toBe('lite');
        expect((await effectiveSubscription(ctx.db, store.id)).plan).toBe('standard');
        expect(await organizationBilling(ctx.db, org)).toMatchObject({ migrated: true, writable: false, status: 'read_only' });
        expect(await organizationBilling(ctx.db, activeOrg)).toMatchObject({ migrated: true, writable: true, status: 'active' });
        expect(await ctx.db.select().from(subscriptionTerms)).toEqual(termsBefore);
        expect(await ctx.db.select().from(playSubscriptions)).toEqual(storeBefore);
        expect(await ctx.db.select().from(vehicles).where(eq(vehicles.id, vehicleId))).toHaveLength(1);
        const list = await ctx.app.inject({ method: 'GET', url: '/v1/admin/subscriptions', headers: admin });
        expect(list.json().legacy).toEqual([]);
        expect(list.json().awaiting_review).toEqual([]);
        // A restart must not repeat the one-time cleanup on later test fixtures.
        const later = await owner();
        await ctx.db.update(users).set({ plan: 'lite' }).where(eq(users.id, later.id));
        await applyInitSql(sql => ctx.client.exec(sql));
        expect((await effectiveSubscription(ctx.db, later.id)).plan).toBe('lite');
    });

});
