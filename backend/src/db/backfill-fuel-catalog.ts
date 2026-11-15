import { eq, sql } from "drizzle-orm";
import { DEFAULT_FUEL_TYPES, defaultFuelTypeId } from "../lib/catalog.js";
import { recordChange } from "../lib/dbx.js";
import type { Db } from "./client.js";
import { fuelTypes, users } from "./schema.js";

/** Add missing defaults without replacing legacy IDs or custom catalog rows. */
export async function backfillFuelCatalog(db: Db): Promise<void> {
  await db.transaction(async (tx) => {
    const marker = await tx.execute(sql`
      INSERT INTO fuel_catalog_migrations (name) VALUES ('default_types_v3')
      ON CONFLICT DO NOTHING RETURNING name
    `);
    if (marker.rows.length === 0) return;

    const accounts = await tx.select({ id: users.id }).from(users)
      .where(eq(users.role, "owner"));
    for (const { id: userId } of accounts) {
      const inserted = await tx.insert(fuelTypes).values(
        DEFAULT_FUEL_TYPES.map(type => ({
          ...type,
          id: defaultFuelTypeId(userId, type.name),
          userId,
        })),
      ).onConflictDoNothing().returning();

      for (const type of inserted) {
        await recordChange(tx as Db, {
          userId,
          entityType: "fuel_type",
          entityId: type.id,
          op: "upsert",
          payload: {
            id: type.id,
            user_id: userId,
            name: type.name,
            kind: type.kind,
            unit: type.unit,
          },
        });
      }
    }
  });
}
