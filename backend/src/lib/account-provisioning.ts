import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { users } from "../db/schema.js";
import { hashPassword, newId, randomToken } from "./crypto.js";
import { generateUniqueUsername } from "./username.js";

/**
 * Provision an owner account for an admin-driven flow (org creation, member
 * invite, workshop link) without any email dependency: the account is created
 * active, email-verified, and must change its password on first sign-in. When
 * no password is supplied a strong one is generated and returned so the admin
 * can hand it over — no credential email is ever sent.
 */
export async function provisionOwnerAccount(db: Db, rawEmail: string, password?: string) {
  const email = rawEmail.toLowerCase();
  const [existing] = await db.select().from(users).where(eq(users.email, email)).limit(1);
  if (existing) return { user: existing, created: false, temporaryPassword: null as string | null };

  const temporaryPassword = password ?? randomToken();
  const userId = newId();
  const [user] = await db.insert(users).values({
    id: userId,
    email,
    username: await generateUniqueUsername(db, email),
    passwordHash: await hashPassword(temporaryPassword),
    role: "owner",
    plan: "free",
    status: "active",
    emailVerified: true,
    mustChangePassword: true,
  }).returning();
  return { user, created: true, temporaryPassword };
}
