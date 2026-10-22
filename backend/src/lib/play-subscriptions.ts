import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { playSubscriptions, users } from "../db/schema.js";
import { AppError } from "./errors.js";
import { playAccountId, verifiedPlayLine, type PlayGateway } from "./google-play.js";

/** Serialize per account BEFORE querying Google, so late RTDN cannot write old state. */
export async function syncPlayPurchase(db: Db, gateway: PlayGateway, userId: string, token: string) {
  const result = await db.transaction(async tx => {
    const [user] = await tx.select().from(users).where(eq(users.id, userId)).for("update");
    if (!user) throw new AppError(404, "not_found", "Account not found");
    const [existing] = await tx.select().from(playSubscriptions).where(eq(playSubscriptions.purchaseToken, token));
    if (existing && existing.userId !== userId) throw new AppError(409, "purchase_account_mismatch", "Purchase belongs to another account");
    const purchase = await gateway.get(token);
    const { line, plan, expiresAt, entitled } = verifiedPlayLine(purchase, playAccountId(userId));
    const acknowledged = purchase.acknowledgementState === "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED";
    const values = { userId, productId: line.productId, basePlanId: line.offerDetails!.basePlanId, plan,
      state: purchase.subscriptionState, expiresAt, autoRenewing: line.autoRenewingPlan?.autoRenewEnabled ?? false,
      acknowledged, updatedAt: new Date() };
    await tx.insert(playSubscriptions).values({ purchaseToken: token, ...values })
      .onConflictDoUpdate({ target: playSubscriptions.purchaseToken, set: values });
    if (purchase.linkedPurchaseToken) {
      const [linked] = await tx.select().from(playSubscriptions).where(eq(playSubscriptions.purchaseToken, purchase.linkedPurchaseToken));
      if (linked && linked.userId !== userId) throw new AppError(409, "purchase_account_mismatch", "Linked purchase belongs to another account");
      if (linked) await tx.update(playSubscriptions).set({ state: "REPLACED", expiresAt: new Date(), autoRenewing: false })
        .where(eq(playSubscriptions.purchaseToken, purchase.linkedPurchaseToken));
    }
    return { entitled, acknowledged, productId: line.productId };
  });
  // Durable entitlement first; acknowledgement can safely retry after a crash.
  if (result.entitled && !result.acknowledged) {
    await gateway.acknowledge(result.productId, token);
    await db.update(playSubscriptions).set({ acknowledged: true }).where(eq(playSubscriptions.purchaseToken, token));
  }
  return { verified: true, entitled: result.entitled, acknowledged: result.entitled || result.acknowledged };
}

export function publicPlaySubscription(row: typeof playSubscriptions.$inferSelect) {
  return { product_id: row.productId, base_plan_id: row.basePlanId, plan: row.plan,
    state: row.state, expires_at: row.expiresAt.toISOString(), auto_renewing: row.autoRenewing };
}
