import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import type { Env } from "../config/env.js";
import { users } from "../db/schema.js";
import { hashPassword, newId } from "../lib/crypto.js";

export async function bootstrapAdmin(db: Db, env: Env): Promise<void> {
  if (!env.BOOTSTRAP_ADMIN_EMAIL || !env.BOOTSTRAP_ADMIN_PASSWORD) return;
  const email = env.BOOTSTRAP_ADMIN_EMAIL.toLowerCase();
  const [existing] = await db.select().from(users).where(eq(users.email, email)).limit(1);
  if (existing) return;
  await db.insert(users).values({
    id: newId(),
    email,
    passwordHash: await hashPassword(env.BOOTSTRAP_ADMIN_PASSWORD),
    displayName: "Bootstrap admin",
    role: "admin",
    plan: "premium",
    emailVerified: true,
  });
  console.log(`[bootstrap] admin ${email} created — rotate BOOTSTRAP_ADMIN_PASSWORD`);
}
