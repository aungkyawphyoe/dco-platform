import { and, desc, eq, sql } from 'drizzle-orm';
import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import type { Db } from '../db/client.js';
import { auditEvents, giftGrants, organizations, plans, playSubscriptions, subscriptionTerms, users, vehicles } from '../db/schema.js';
import { AppError } from '../lib/errors.js';
import { newId, sha256 } from '../lib/crypto.js';
import { effectiveSubscription } from '../lib/gifts.js';
import { assertPersonalGarageAllowed } from '../lib/personal-garage.js';
import { accessEnd, organizationBilling, publicTerm, subscriberTerms, termEnd, termStatus } from '../lib/subscriptions.js';
import { requireAdmin, requireOwner, requireFleetClient } from './auth.js';
import { getOrganizationAccess } from './fleet.js';
const identity = z.object({ kind: z.enum(['user', 'organization']), id: z.string().uuid() });
const money = z.number().finite().nonnegative().max(1000000000).refine(n => Math.abs(n * 100 - Math.round(n * 100)) < 0.00001, 'Use at most two decimal places');
const paymentSchema = z.object({ amount: money.refine(n => n > 0, "Payment must be positive"), currency: z.enum(['MMK', 'USD']), paid_at: z.string().datetime(), method: z.string().trim().min(1).max(80), reference: z.string().max(200).optional(), receipt: z.string().url().max(2000).optional(), override_reason: z.string().trim().min(1).max(1000).optional() });
const createSchema = identity.extend({ request_id: z.string().uuid(), plan: z.enum(['lite', 'standard', 'fleet']), source: z.enum(['direct', 'complimentary']), starts_at: z.string().datetime(), unit: z.enum(['months', 'years', 'days']), count: z.number().int().min(1).max(3650), renew: z.boolean().default(false), expected_start: z.string().datetime().optional(), reason: z.string().trim().min(1).max(1000).optional(), payment: paymentSchema.optional(), price_version: z.number().int().optional() }).strict();
async function lockSubscriber(db: Db, kind: 'user' | 'organization', id: string) {
    if (kind === 'user') {
        const [u] = await db.select().from(users).where(eq(users.id, id)).for('update');
        if (!u || u.role !== 'owner' || u.status !== 'active')
            throw new AppError(422, 'invalid_subscriber', 'An active personal owner is required');
        await assertPersonalGarageAllowed(db, id);
    }
    else {
        const [o] = await db.select().from(organizations).where(eq(organizations.id, id)).for('update');
        if (!o || o.status === 'archived')
            throw new AppError(422, 'invalid_subscriber', 'Organization is unavailable');
    }
}
async function assertNoStore(db: Db, id: string) {
    const rows = await db.select().from(playSubscriptions).where(eq(playSubscriptions.userId, id));
    if (rows.some(p => !['SUBSCRIPTION_STATE_EXPIRED', 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED', 'REPLACED'].includes(p.state) && (p.expiresAt > new Date() || ['SUBSCRIPTION_STATE_ON_HOLD', 'SUBSCRIPTION_STATE_PAUSED', 'SUBSCRIPTION_STATE_PENDING'].includes(p.state))))
        throw new AppError(409, 'store_subscription_exists', 'Resolve the existing store subscription and wait for access to expire');
    const gifts = await db.select().from(giftGrants).where(eq(giftGrants.userId, id));
    if (gifts.some(g => g.endsAt > new Date()))
        throw new AppError(409, 'gift_active', 'Wait for the promotional gift to expire');
}
export const subscriptionsPlugin: FastifyPluginAsync = async (app) => {
    app.get('/me/subscriptions', async (req) => {
        requireOwner(req);
        const sub = await effectiveSubscription(app.db, req.authUser!.sub);
        return { plan: sub.plan, free_vehicle_id: sub.user.freeVehicleId, managed: sub.user.billingManaged,
            terms: (await subscriberTerms(app.db, 'user', sub.user.id)).map(publicTerm), store: sub.play ? { plan: sub.play.plan, state: sub.play.state, expiresAt: sub.play.expiresAt } : null };
    });
    app.post('/me/free-vehicle', async (req) => {
        requireOwner(req);
        const { vehicle_id } = z.object({ vehicle_id: z.string().uuid() }).parse(req.body);
        return app.db.transaction(async (tx) => {
            const db = tx as unknown as Db;
            await lockSubscriber(db, 'user', req.authUser!.sub);
            const sub = await effectiveSubscription(db, req.authUser!.sub);
            if (!sub.user.billingManaged || sub.plan !== 'free')
                throw new AppError(409, 'not_free', 'Vehicle selection applies after a managed subscription downgrade');
            if (sub.user.freeVehicleId && sub.user.freeVehicleId !== vehicle_id)
                throw new AppError(409, 'selection_locked', 'Ask a system admin to correct your Free vehicle selection');
            const [v] = await tx.select().from(vehicles).where(and(eq(vehicles.id, vehicle_id), eq(vehicles.userId, sub.user.id), eq(vehicles.archived, false)));
            if (!v)
                throw new AppError(422, 'invalid_vehicle', 'Choose an active vehicle you own');
            await tx.update(users).set({ freeVehicleId: vehicle_id }).where(eq(users.id, sub.user.id));
            return { free_vehicle_id: vehicle_id };
        });
    });
    app.get('/organizations/:id/subscription', async (req) => {
        requireFleetClient(req);
        const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
        await getOrganizationAccess(app.db, req.authUser!.sub, id);
        const billing = await organizationBilling(app.db, id);
        return { status: billing.status, writable: billing.writable, term: billing.term ? { plan: billing.term.plan, startsAt: billing.term.startsAt, endsAt: billing.term.endsAt, accessEndsAt: accessEnd(billing.term), source: billing.term.source } : null };
    });
    await app.register(async (admin) => {
        admin.addHook('preHandler', async (req) => requireAdmin(req, app.env.JWT_ADMIN_AUD));
        admin.get('/admin/prices', async () => ({ items: await app.db.select().from(plans) }));
        admin.get('/admin/price-history', async () => ({ items: await app.db.select().from(auditEvents).where(eq(auditEvents.action, 'pricing.publish')).orderBy(desc(auditEvents.at)).limit(100) }));
        admin.patch('/admin/prices/:id', async (req) => {
            const { id } = z.object({ id: z.enum(['free', 'lite', 'standard', 'fleet']) }).parse(req.params);
            const b = z.object({ version: z.number().int(), monthly_mmk: money.refine(Number.isInteger, "MMK must be a whole number"), annual_mmk: money.refine(Number.isInteger, "MMK must be a whole number"), monthly_usd: money, annual_usd: money }).strict().parse(req.body);
            if (id === 'free' && [b.monthly_mmk, b.annual_mmk, b.monthly_usd, b.annual_usd].some(n => n !== 0))
                throw new AppError(422, 'free_price', 'Free must remain zero');
            return app.db.transaction(async (tx) => {
                const [before] = await tx.select().from(plans).where(eq(plans.id, id)).for('update');
                if (!before || before.priceVersion !== b.version)
                    throw new AppError(409, 'stale_price', 'Prices changed. Refresh before publishing');
                const [after] = await tx.update(plans).set({ priceMonthlyMmk: b.monthly_mmk, priceAnnualMmk: b.annual_mmk, priceMonthlyUsd: b.monthly_usd.toFixed(2), priceAnnualUsd: b.annual_usd.toFixed(2), priceVersion: b.version + 1 }).where(eq(plans.id, id)).returning();
                await tx.insert(auditEvents).values({ adminUserId: req.authUser!.sub, action: 'pricing.publish', detail: { before, after } });
                return after;
            });
        });
        admin.get('/admin/subscriptions', async (req) => {
            const q = z.object({ q: z.string().max(200).default(''), kind: z.enum(['user', 'organization']).optional(), id: z.string().uuid().optional(), source: z.enum(['','direct','complimentary','google_play','gift','legacy']).optional(), status: z.enum(['','active','scheduled','grace','expired','revoked']).optional(), plan: z.enum(['','free','lite','standard','fleet']).optional(), offset: z.coerce.number().int().min(0).default(0) }).parse(req.query);
            const now = new Date();
            const state = sql<string> `CASE WHEN ${subscriptionTerms.revokedAt} IS NOT NULL THEN 'revoked' WHEN ${subscriptionTerms.startsAt} > ${now} THEN 'scheduled' WHEN ${subscriptionTerms.endsAt} > ${now} THEN 'active' WHEN ${subscriptionTerms.source} = 'direct' AND ${subscriptionTerms.endsAt} + interval '7 days' > ${now} THEN 'grace' ELSE 'expired' END`;
            const conditions = [sql `coalesce(${users.email}, ${organizations.name}, '') ILIKE ${'%' + q.q + '%'}`];
            if (q.id)
                conditions.push(eq(q.kind === 'organization' ? subscriptionTerms.organizationId : subscriptionTerms.userId, q.id));
            if (q.kind)
                conditions.push(sql `${q.kind === 'organization' ? subscriptionTerms.organizationId : subscriptionTerms.userId} IS NOT NULL`);
            if (q.source)
                conditions.push(eq(subscriptionTerms.source, q.source));
            if (q.status)
                conditions.push(sql `${state} = ${q.status}`);
            if (q.plan)
                conditions.push(eq(subscriptionTerms.plan, q.plan as 'lite' | 'standard' | 'fleet'));
            const rows = await app.db.select({ term: subscriptionTerms, email: users.email, name: organizations.name }).from(subscriptionTerms).leftJoin(users, eq(users.id, subscriptionTerms.userId)).leftJoin(organizations, eq(organizations.id, subscriptionTerms.organizationId)).where(and(...conditions)).orderBy(desc(subscriptionTerms.createdAt), desc(subscriptionTerms.id)).limit(51).offset(q.offset);
            const filtered = rows.map(r => ({ ...publicTerm(r.term), label: r.name ?? r.email ?? r.term.userId }));
            const personalConditions = [sql `${users.email} ILIKE ${'%' + q.q + '%'}`];
            if (q.id)
                personalConditions.push(eq(users.id, q.id));
            const storeState = sql<string>`CASE WHEN ${playSubscriptions.state} = 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' AND ${playSubscriptions.expiresAt} > ${now} THEN 'grace' WHEN ${playSubscriptions.state} IN ('SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_CANCELED') AND ${playSubscriptions.expiresAt} > ${now} THEN 'active' WHEN ${playSubscriptions.state} = 'SUBSCRIPTION_STATE_PENDING' THEN 'scheduled' ELSE 'expired' END`;
            const giftState = sql<string>`CASE WHEN ${giftGrants.startsAt} > ${now} THEN 'scheduled' WHEN ${giftGrants.endsAt} > ${now} THEN 'active' ELSE 'expired' END`;
            const stores = q.kind === 'organization' || q.source && q.source !== 'google_play' ? [] : await app.db.select({ userId: playSubscriptions.userId, plan: playSubscriptions.plan, state: playSubscriptions.state, expiresAt: playSubscriptions.expiresAt, autoRenewing: playSubscriptions.autoRenewing, email: users.email }).from(playSubscriptions).innerJoin(users, eq(users.id, playSubscriptions.userId)).where(and(...personalConditions, ...(q.plan ? [eq(playSubscriptions.plan, q.plan as 'lite' | 'standard')] : []), q.status ? sql`${storeState} = ${q.status}` : undefined)).orderBy(desc(playSubscriptions.expiresAt)).limit(51).offset(q.offset);
            const gifts = q.kind === 'organization' || q.source && q.source !== 'gift' ? [] : await app.db.select({ id: giftGrants.id, userId: giftGrants.userId, email: users.email, plan: giftGrants.plan, startsAt: giftGrants.startsAt, endsAt: giftGrants.endsAt }).from(giftGrants).innerJoin(users, eq(users.id, giftGrants.userId)).where(and(...personalConditions, q.plan ? eq(giftGrants.plan, q.plan as 'lite'|'standard') : undefined, q.status ? sql`${giftState} = ${q.status}` : undefined)).orderBy(desc(giftGrants.endsAt)).limit(51).offset(q.offset);
            const legacy = q.status && q.status !== 'active' || q.kind === 'organization' || q.source && q.source !== 'legacy' ? [] : await app.db.select({ id: users.id, email: users.email, plan: users.plan }).from(users).where(and(...personalConditions, eq(users.billingManaged, false), eq(users.role, 'owner'), q.plan ? eq(users.plan, q.plan as 'free'|'lite'|'standard'|'fleet') : undefined, sql `${users.plan} <> 'free'`)).orderBy(users.id).limit(51).offset(q.offset);
            const review = q.source && q.source !== 'legacy' || q.kind === 'user' ? [] : await app.db.select({ id: organizations.id, name: organizations.name }).from(organizations).where(and(eq(organizations.billingMigrated, false), q.id ? eq(organizations.id, q.id) : undefined, sql `${organizations.name} ILIKE ${'%' + q.q + '%'}`)).orderBy(organizations.id).limit(51).offset(q.offset);
            const conflictUsers = new Set((await app.db.select({ userId: subscriptionTerms.userId }).from(subscriptionTerms).where(sql `${subscriptionTerms.userId} IS NOT NULL AND ${state} IN ('active','grace','scheduled')`)).map(t => t.userId));
            return { items: filtered.slice(0, 50), next_offset: [rows, stores, gifts, legacy, review].some(r => r.length > 50) ? q.offset + 50 : null, stores: stores.slice(0, 50).map(s => ({ ...s, conflict: conflictUsers.has(s.userId) && s.expiresAt > now && !['SUBSCRIPTION_STATE_EXPIRED','REPLACED','SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED'].includes(s.state) })), gifts: gifts.slice(0, 50), legacy: legacy.slice(0, 50), awaiting_review: review.slice(0, 50) };
        });
        admin.get('/admin/subscriptions/history', async (req) => {
            const { id } = z.object({ id: z.string().uuid() }).parse(req.query);
            return { items: await app.db.select().from(auditEvents).where(sql `${auditEvents.detail}::text LIKE ${'%' + id + '%'}`).orderBy(desc(auditEvents.at)).limit(100) };
        });
        admin.post('/admin/subscriptions/preview', async (req) => {
            const b = identity.extend({ starts_at: z.string().datetime(), unit: z.enum(['months', 'years', 'days']), count: z.number().int().min(1).max(3650), renew: z.boolean(), source: z.enum(['direct', 'complimentary']) }).parse(req.body);
            const rows = await subscriberTerms(app.db, b.kind, b.id);
            const latest = rows.find(t => !t.revokedAt && t.source === 'direct');
            const start = b.renew && latest && new Date() < accessEnd(latest) ? latest.endsAt : new Date(b.starts_at);
            const end = termEnd(start, b.unit, b.count);
            return { starts_at: start.toISOString(), ends_at: end.toISOString(), access_ends_at: accessEnd({ source: b.source, endsAt: end }).toISOString() };
        });
        admin.post('/admin/subscriptions', async (req) => {
            const b = createSchema.parse(req.body);
            if ((b.kind === 'organization') !== (b.plan === 'fleet'))
                throw new AppError(422, 'invalid_plan', 'Fleet plans belong to organizations; personal plans are Lite or Standard');
            if (b.source === 'direct' && !b.payment || b.source === 'complimentary' && (!b.reason || b.payment))
                throw new AppError(422, 'invalid_payment', 'Paid terms require payment; complimentary grants require a reason and no payment');
            return app.db.transaction(async (tx) => {
                const db = tx as unknown as Db;
                await lockSubscriber(db, b.kind, b.id);
                const [retry] = await tx.select().from(subscriptionTerms).where(eq(subscriptionTerms.requestId, b.request_id));
                if (retry) {
                    if ((retry.userId ?? retry.organizationId) !== b.id || retry.requestFingerprint !== sha256(JSON.stringify(b)))
                        throw new AppError(409, 'request_conflict', 'Request ID already used');
                    return publicTerm(retry);
                }
                if (b.kind === 'user')
                    await assertNoStore(db, b.id);
                const rows = await subscriberTerms(db, b.kind, b.id);
                let start = new Date(b.starts_at);
                const latest = rows.find(t => !t.revokedAt && t.source === 'direct');
                if (b.renew && latest && new Date() < accessEnd(latest))
                    start = latest.endsAt;
                if (b.expected_start && start.toISOString() !== b.expected_start)
                    throw new AppError(409, "stale_preview", "Renewal dates changed. Review the subscription again");
                const end = termEnd(start, b.unit, b.count);
                if (end.getUTCFullYear() > 2100)
                    throw new AppError(422, 'invalid_duration', 'Term must end before 2101');
                if (rows.some(t => !t.revokedAt && t.startsAt < end && t.endsAt > start))
                    throw new AppError(409, 'term_overlap', 'Start the new term after existing terms end');
                const [price] = await tx.select().from(plans).where(eq(plans.id, b.plan)).for('share');
                if (!price || b.source === 'direct' && b.price_version !== price.priceVersion)
                    throw new AppError(409, 'stale_price', 'Refresh catalog prices before recording payment');
                const period = b.unit === 'years' && b.count === 1 ? 'annual' : b.unit === 'months' && b.count === 1 ? 'monthly' : null;
                const catalog = period ? Number(b.payment?.currency === 'USD' ? period === 'annual' ? price.priceAnnualUsd : price.priceMonthlyUsd : period === 'annual' ? price.priceAnnualMmk : price.priceMonthlyMmk) : null;
                if (b.payment && (catalog === null || b.payment.amount !== catalog) && !b.payment.override_reason)
                    throw new AppError(422, 'override_reason_required', 'Provide a reason for a negotiated or custom-duration amount');
                const [term] = await tx.insert(subscriptionTerms).values({ id: newId(), userId: b.kind === 'user' ? b.id : null, organizationId: b.kind === 'organization' ? b.id : null, plan: b.plan, source: b.source, startsAt: start, endsAt: end, payment: b.payment ? { ...b.payment, catalog_amount: catalog, catalog_version: price.priceVersion, period } : null, reason: b.reason, createdBy: req.authUser!.sub, requestId: b.request_id, requestFingerprint: sha256(JSON.stringify(b)) }).returning();
                if (b.kind === 'user')
                    await tx.update(users).set({ billingManaged: true, plan: 'free' }).where(eq(users.id, b.id));
                await tx.insert(auditEvents).values({ adminUserId: req.authUser!.sub, action: 'subscription.create', detail: { after: term } });
                return publicTerm(term);
            });
        });
        admin.patch('/admin/subscriptions/:id', async (req) => {
            const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
            const b = z.object({ version: z.number().int(), reason: z.string().trim().min(1).max(1000), action: z.enum(['correct', 'revoke', 'upgrade']), starts_at: z.string().datetime().optional(), ends_at: z.string().datetime().optional(), payment: paymentSchema.optional() }).strict().parse(req.body);
            if (b.action !== 'upgrade' && b.payment) throw new AppError(422, 'invalid_payment', 'Only upgrades accept an additional payment');
            return app.db.transaction(async (tx) => {
                const db = tx as unknown as Db;
                const [found] = await tx.select().from(subscriptionTerms).where(eq(subscriptionTerms.id, id));
                if (!found)
                    throw new AppError(404, 'not_found', 'Term not found');
                await lockSubscriber(db, found.userId ? 'user' : 'organization', (found.userId ?? found.organizationId)!);
                const [before] = await tx.select().from(subscriptionTerms).where(eq(subscriptionTerms.id, id)).for('update');
                if (before.version !== b.version || before.revokedAt)
                    throw new AppError(409, 'stale_term', 'Refresh the subscription before changing it');
                const start = b.starts_at ? new Date(b.starts_at) : before.startsAt, end = b.ends_at ? new Date(b.ends_at) : before.endsAt;
                if (end <= start)
                    throw new AppError(422, 'invalid_dates', 'Expiry must follow start');
                if (b.action === 'upgrade' && (before.plan !== 'lite' || before.source !== 'direct' || termStatus(before) !== 'active' || b.starts_at || b.ends_at))
                    throw new AppError(422, 'invalid_upgrade', 'Only an active direct-paid Lite term can upgrade, keeping its dates');
                if (b.action !== 'revoke' && before.userId) await assertNoStore(db, before.userId);
                if (b.action === 'correct') {
                    const rows = await subscriberTerms(db, before.userId ? 'user' : 'organization', (before.userId ?? before.organizationId)!);
                    if (rows.some(t => t.id !== id && !t.revokedAt && t.startsAt < end && t.endsAt > start))
                        throw new AppError(409, 'term_overlap', 'Corrected dates overlap another term');
                }
                const [after] = await tx.update(subscriptionTerms).set({ ...(b.action === 'revoke' ? { revokedAt: new Date() } : b.action === 'upgrade' ? { plan: 'standard' as const } : { startsAt: start, endsAt: end }), version: before.version + 1 }).where(eq(subscriptionTerms.id, id)).returning();
                await tx.insert(auditEvents).values({ adminUserId: req.authUser!.sub, action: `subscription.${b.action}`, detail: { reason: b.reason, before, after, additional_payment: b.payment ?? null } });
                return publicTerm(after);
            });
        });
        admin.post('/admin/organizations/:id/migrate-billing', async (req) => {
            const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
            return app.db.transaction(async (tx) => {
                const db = tx as unknown as Db;
                await lockSubscriber(db, 'organization', id);
                if (!(await subscriberTerms(db, 'organization', id)).some(t => !t.revokedAt))
                    throw new AppError(422, 'term_required', 'Assign a paid or complimentary term before confirming migration');
                await tx.update(organizations).set({ billingMigrated: true }).where(eq(organizations.id, id));
                await tx.insert(auditEvents).values({ adminUserId: req.authUser!.sub, action: 'subscription.migrate', detail: { organizationId: id } });
                return { migrated: true };
            });
        });
        admin.post('/admin/users/:id/free-vehicle', async (req) => {
            const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
            const b = z.object({ vehicle_id: z.string().uuid(), reason: z.string().trim().min(1) }).parse(req.body);
            return app.db.transaction(async (tx) => {
                await lockSubscriber(tx as unknown as Db, 'user', id);
                const [v] = await tx.select().from(vehicles).where(and(eq(vehicles.id, b.vehicle_id), eq(vehicles.userId, id), eq(vehicles.archived, false)));
                if (!v)
                    throw new AppError(422, 'invalid_vehicle', 'Choose an active owned vehicle');
                const [before] = await tx.select().from(users).where(eq(users.id, id));
                await tx.update(users).set({ freeVehicleId: b.vehicle_id }).where(eq(users.id, id));
                await tx.insert(auditEvents).values({ adminUserId: req.authUser!.sub, action: 'subscription.free_vehicle', detail: { userId: id, before: before.freeVehicleId, after: b.vehicle_id, reason: b.reason } });
                return { free_vehicle_id: b.vehicle_id };
            });
        });
    });
};
