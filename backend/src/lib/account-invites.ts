import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { emailTokens, users } from "../db/schema.js";
import { hashPassword, newId, randomToken, sha256 } from "./crypto.js";
import type { Mailer } from "./mail.js";

export async function createInvitedOwnerAccount(db: Db, mailer: Mailer, rawEmail: string) {
  const email = rawEmail.toLowerCase();
  const [existing] = await db.select().from(users).where(eq(users.email, email)).limit(1);
  if (existing) return { user: existing, created: false };

  const userId = newId();
  const [user] = await db.insert(users).values({
    id: userId,
    email,
    passwordHash: await hashPassword(randomToken()),
    role: "owner",
    plan: "free",
    status: "active",
    emailVerified: false,
  }).returning();

  const token = randomToken();
  await db.insert(emailTokens).values({
    id: newId(),
    userId,
    purpose: "reset",
    tokenHash: sha256(token),
    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
  });
  await mailer.sendPasswordReset(email, token);
  return { user, created: true };
}
