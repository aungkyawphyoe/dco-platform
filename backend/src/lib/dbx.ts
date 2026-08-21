import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { changeLog, users } from "../db/schema.js";

export type ChangeOp = "upsert" | "archive" | "delete";

export async function recordChange(
  db: Db,
  input: {
    userId: string;
    entityType: string;
    entityId: string;
    op: ChangeOp;
    payload: unknown;
  },
): Promise<void> {
  await db.insert(changeLog).values({
    userId: input.userId,
    entityType: input.entityType,
    entityId: input.entityId,
    op: input.op,
    payload: input.payload as object,
  });
}

export async function getUser(db: Db, userId: string) {
  const rows = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  return rows[0] ?? null;
}

export function num(v: string | number | null | undefined): number | null {
  if (v === null || v === undefined) return null;
  return Number(v);
}

export function reqNum(v: string | number | null | undefined): number {
  return Number(v ?? 0);
}

export function iso(d: Date | string | null | undefined): string | null {
  if (!d) return null;
  if (d instanceof Date) return d.toISOString();
  return d;
}

export function dateOnly(d: Date | string | null | undefined): string | null {
  if (!d) return null;
  if (typeof d === "string") return d.slice(0, 10);
  return d.toISOString().slice(0, 10);
}
