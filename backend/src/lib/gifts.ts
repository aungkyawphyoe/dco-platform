import { and, desc, eq, gt } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { giftGrants, users } from "../db/schema.js";
import { AppError } from "./errors.js";

export async function effectiveSubscription(db: Db, userId: string, now = new Date()) {
  const [user] = await db.select().from(users).where(eq(users.id, userId));
  if (!user) throw new AppError(404, "not_found", "Account not found");
  const [gift] = await db.select().from(giftGrants).where(and(
    eq(giftGrants.userId, userId), gt(giftGrants.endsAt, now),
  )).orderBy(desc(giftGrants.endsAt)).limit(1);
  // An independent admin assignment takes precedence and is never cleared by expiry.
  return { user, plan: user.plan === "free" && gift ? gift.plan : user.plan,
    gift: user.plan === "free" ? gift ?? null : null };
}

export function publicGift(gift: typeof giftGrants.$inferSelect) {
  return { id: gift.id, promotion_id: gift.promotionId, plan: gift.plan,
    starts_at: gift.startsAt.toISOString(), ends_at: gift.endsAt.toISOString() };
}
