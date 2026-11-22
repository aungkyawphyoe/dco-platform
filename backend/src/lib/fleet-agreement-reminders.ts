import { and, desc, eq, isNull } from "drizzle-orm";
import { z } from "zod";
import type { Db } from "../db/client.js";
import { fleetAgreementNotices, fleetAgreements, fleetAgreementTerms, organizationMembers, organizations, users } from "../db/schema.js";
import { days, reportingToday } from "./fleet-analytics.js";
import type { Mailer } from "./mail.js";

const settings = z.object({ analytics: z.object({ timezone: z.string().optional() }).optional() });

export async function sendFleetAgreementReminders(db: Db, mailer: Mailer, now = new Date()) {
  const send = mailer.sendFleetAgreementReminder?.bind(mailer);
  if (!send) throw new Error("Fleet agreement reminder mailer unavailable");

  const candidates = await db.select({ id: fleetAgreements.id }).from(fleetAgreements)
    .where(isNull(fleetAgreements.archivedAt));
  let sent = 0;
  let failures = 0;
  for (const candidate of candidates) {
    try {
      const outcome = await db.transaction(async tx => {
        const [agreement] = await tx.select().from(fleetAgreements)
          .where(eq(fleetAgreements.id, candidate.id)).for("update");
        if (!agreement || agreement.archivedAt || !agreement.responsibleMemberId) return;
        const [organization] = await tx.select().from(organizations)
          .where(and(eq(organizations.id, agreement.orgId), eq(organizations.status, "active"),
            eq(organizations.plan, "enterprise"))).for("share");
        if (!organization) return;
        const parsed = settings.safeParse(organization.settings);
        const today = reportingToday(parsed.success ? parsed.data.analytics?.timezone ?? "UTC" : "UTC", now);
        const [term] = await tx.select().from(fleetAgreementTerms)
          .where(eq(fleetAgreementTerms.agreementId, agreement.id))
          .orderBy(desc(fleetAgreementTerms.termNumber)).limit(1);
        if (!term || today < term.startsOn || today > term.endsOn ||
          days(today, term.endsOn) - 1 > term.reminderLeadDays) return;

        const key = { termId: term.id, endsOn: term.endsOn };
        const [notice] = await tx.select().from(fleetAgreementNotices)
          .where(and(eq(fleetAgreementNotices.termId, key.termId), eq(fleetAgreementNotices.endsOn, key.endsOn)));
        if (notice?.sentAt) return;
        const [recipient] = await tx.select({ email: users.email }).from(organizationMembers)
          .innerJoin(users, eq(users.id, organizationMembers.userId))
          .where(and(eq(organizationMembers.id, agreement.responsibleMemberId),
            eq(organizationMembers.orgId, agreement.orgId), eq(organizationMembers.status, "active"),
            eq(users.status, "active"))).for("share");
        if (!recipient?.email) return;

        let sentAt: Date | null = null;
        try {
          await send(recipient.email, `Your fleet agreement expires on ${term.endsOn}. Open the Fleet Portal to review the agreement and record its renewal.`);
          sentAt = now;
        } catch {
          // Persist the failed attempt so operators can see it and the next run can retry.
        }
        await tx.insert(fleetAgreementNotices).values({ ...key, attemptedAt: now, sentAt })
          .onConflictDoUpdate({
            target: [fleetAgreementNotices.termId, fleetAgreementNotices.endsOn],
            set: { attemptedAt: now, sentAt },
          });
        return sentAt ? "sent" : "failed";
      });
      if (outcome === "sent") sent++;
      if (outcome === "failed") failures++;
    } catch {
      failures++;
    }
  }
  return { sent, failures };
}
