import { and, desc, eq, gt, inArray, sql } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { giftGrants, users, playSubscriptions } from "../db/schema.js";
import { AppError } from "./errors.js";

export async function effectiveSubscription(db: Db, userId: string, now = new Date()) {
  const [user] = await db.select().from(users).where(eq(users.id, userId));
  if (!user) throw new AppError(404, "not_found", "Account not found");
  const [gift] = await db.select().from(giftGrants).where(and(
    eq(giftGrants.userId, userId), gt(giftGrants.endsAt, now),
  )).orderBy(desc(giftGrants.endsAt)).limit(1);
  const [play] = await db.select().from(playSubscriptions).where(and(
    eq(playSubscriptions.userId, userId), gt(playSubscriptions.expiresAt, now),
    inArray(playSubscriptions.state, ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "SUBSCRIPTION_STATE_CANCELED"]),
  )).orderBy(sql`CASE ${playSubscriptions.plan} WHEN 'standard' THEN 2 WHEN 'lite' THEN 1 ELSE 0 END DESC`, desc(playSubscriptions.expiresAt)).limit(1);
  const rank = { free: 0, lite: 1, standard: 2, fleet: 3 };
  let plan = user.plan;
  let giftEnd: Date | null = null;
  let paidEnd: Date | null = null;
  if (gift && user.plan === "free") { plan = gift.plan; giftEnd = gift.endsAt; }
  if (play && rank[play.plan] >= rank[plan] && rank[play.plan] > rank[user.plan]) {
    plan = play.plan; giftEnd = null; paidEnd = play.expiresAt;
  }
  return { user, plan, gift: giftEnd ? gift : null, play: play ?? null, paidEnd };

}

export function publicGift(gift: typeof giftGrants.$inferSelect) {
  return { id: gift.id, promotion_id: gift.promotionId, plan: gift.plan,
    starts_at: gift.startsAt.toISOString(), ends_at: gift.endsAt.toISOString() };
}
