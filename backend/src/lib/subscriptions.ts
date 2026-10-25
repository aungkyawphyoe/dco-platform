import { desc, eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { organizations, subscriptionTerms } from "../db/schema.js";
import { AppError } from "./errors.js";
export const DAY = 86400000;
export type Term = typeof subscriptionTerms.$inferSelect;
export function accessEnd(term: Pick<Term, 'source' | 'endsAt'>) {
    return new Date(term.endsAt.getTime() + (term.source === 'direct' ? 7 * DAY : 0));
}
export function termStatus(term: Pick<Term, 'startsAt' | 'endsAt' | 'source' | 'revokedAt'>, now = new Date()) {
    if (term.revokedAt)
        return 'revoked';
    if (now < term.startsAt)
        return 'scheduled';
    if (now < term.endsAt)
        return 'active';
    return now < accessEnd(term) ? 'grace' : 'expired';
}
/** Calendar arithmetic in UTC with month-end clamping; days are exact 24h. */
export function termEnd(start: Date, unit: 'months' | 'years' | 'days', count: number) {
    if (unit === 'days')
        return new Date(start.getTime() + count * DAY);
    const end = new Date(start);
    const day = end.getUTCDate();
    end.setUTCDate(1);
    end.setUTCMonth(end.getUTCMonth() + count * (unit === 'years' ? 12 : 1));
    const last = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth() + 1, 0)).getUTCDate();
    end.setUTCDate(Math.min(day, last));
    return end;
}
export async function subscriberTerms(db: Db, kind: 'user' | 'organization', id: string) {
    return db.select().from(subscriptionTerms).where(eq(kind === 'user' ? subscriptionTerms.userId : subscriptionTerms.organizationId, id)).orderBy(desc(subscriptionTerms.endsAt));
}
export async function activeAdminTerm(db: Db, kind: 'user' | 'organization', id: string, now = new Date()) {
    const rows = await subscriberTerms(db, kind, id);
    return rows.filter(t => ['active', 'grace'].includes(termStatus(t, now)))
        .sort((a, b) => (b.plan === 'standard' ? 2 : 1) - (a.plan === 'standard' ? 2 : 1) || accessEnd(b).getTime() - accessEnd(a).getTime())[0] ?? null;
}
export async function organizationBilling(db: Db, id: string) {
    const [org] = await db.select().from(organizations).where(eq(organizations.id, id));
    if (!org)
        throw new AppError(404, 'organization_not_found', 'Organization not found');
    const term = await activeAdminTerm(db, 'organization', id);
    return { migrated: org.billingMigrated, writable: org.status === "active" && (!org.billingMigrated || !!term),
        status: !org.billingMigrated ? 'awaiting_review' : term ? termStatus(term) : 'read_only', term };
}
export async function assertOrganizationWritable(db: Db, id: string) {
    if (!(await organizationBilling(db, id)).writable)
        throw new AppError(403, 'subscription_read_only', 'Organization subscription is inactive. Existing records remain readable.');
}
export function publicTerm(term: Term) {
    return { ...term, status: termStatus(term), accessEndsAt: accessEnd(term) };
}
