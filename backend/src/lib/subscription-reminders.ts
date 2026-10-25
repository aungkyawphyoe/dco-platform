import { and, eq, isNull } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { organizations, subscriptionNotices, subscriptionTerms, users } from '../db/schema.js';
import { accessEnd, DAY, subscriberTerms, termStatus } from './subscriptions.js';
import type { Mailer } from './mail.js';
/** Run hourly. Lock subscriber before evaluating terms to serialize renewals/corrections. */
export async function sendSubscriptionReminders(db: Db, mailer: Mailer, now = new Date()) {
    if (!mailer.sendSubscriptionReminder)
        throw new Error('Subscription reminder mailer unavailable');
    const rows = await db.select().from(subscriptionTerms).where(and(eq(subscriptionTerms.source, 'direct'), isNull(subscriptionTerms.revokedAt)));
    let sent = 0, failures = 0;
    for (const candidate of rows) {
        try {
            await db.transaction(async (tx) => {
                let recipient: string | null = null;
                if (candidate.userId) {
                    const [u] = await tx.select().from(users).where(eq(users.id, candidate.userId)).for('update');
                    recipient = u?.email ?? null;
                }
                else {
                    const [o] = await tx.select().from(organizations).where(eq(organizations.id, candidate.organizationId!)).for('update');
                    if (!o?.billingMigrated)
                        return;
                    const [u] = await tx.select().from(users).where(eq(users.id, o.adminUserId));
                    recipient = u?.email ?? null;
                }
                if (!recipient)
                    return;
                const terms = await subscriberTerms(tx as unknown as Db, candidate.userId ? 'user' : 'organization', (candidate.userId ?? candidate.organizationId)!);
                const term = terms.find(t => t.id === candidate.id);
                if (!term || term.revokedAt || term.startsAt > now)
                    return;
                // A renewal or complimentary extension suppresses notices for the old term.
                if (terms.some(t => t.id !== term.id && !t.revokedAt && t.startsAt <= accessEnd(term) && t.endsAt > term.endsAt))
                    return;
                const status = termStatus(term, now);
                const milestone = status === 'expired' ? 'restricted' : status === 'grace' ? 'grace' : term.endsAt.getTime() - now.getTime() <= 7 * DAY ? 'upcoming' : null;
                if (!milestone)
                    return;
                const key = `${term.id}:${term.version}:${milestone}`;
                const [notice] = await tx.select().from(subscriptionNotices).where(eq(subscriptionNotices.id, key));
                if (notice?.sentAt)
                    return;
                await tx.insert(subscriptionNotices).values({ id: key, termId: term.id, milestone }).onConflictDoNothing();
                const restriction = term.organizationId ? 'Your organization becomes read-only; existing records remain available.' : 'Your account returns to Free; choose one editable vehicle. Existing records remain available.';
                await mailer.sendSubscriptionReminder!(recipient, `${term.plan} subscription: ${milestone}. Paid expiry: ${term.endsAt.toISOString()}. Grace ends: ${accessEnd(term).toISOString()}. ${restriction} Contact your AutoX administrator to renew. View Plans & subscriptions or your Fleet Portal subscription notice for current status.`);
                await tx.update(subscriptionNotices).set({ sentAt: now }).where(eq(subscriptionNotices.id, key));
                sent++;
            });
        }
        catch {
            failures++;
        }
    }
    return { sent, failures };
}
