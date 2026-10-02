import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { users } from "../db/schema.js";

/** Derive a valid username base from an email local part: lowercase,
 *  `[^a-z0-9._]` -> `_`, edges stripped, min 3 chars, max 30 chars. */
export function baseUsernameFromEmail(email: string): string {
  const local = email.toLowerCase().split("@")[0] ?? "";
  let base = local
    .replace(/[^a-z0-9._]/g, "_")
    .replace(/^[._]+/, "")
    .replace(/[._]+$/, "");
  if (base.length < 3) base = "user";
  return base.slice(0, 30);
}

/** First free username derived from the email: base, then base_2, base_3, …
 *  Mirrors the backfill rule in drizzle/0007_users_username.sql. */
export async function generateUniqueUsername(db: Db, email: string): Promise<string> {
  const base = baseUsernameFromEmail(email);
  let candidate = base;
  let counter = 2;
  for (;;) {
    const [taken] = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.username, candidate))
      .limit(1);
    if (!taken) return candidate;
    const suffix = `_${counter}`;
    candidate = base.slice(0, 30 - suffix.length) + suffix;
    counter += 1;
  }
}
