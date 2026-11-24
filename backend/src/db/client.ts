import { drizzle, type NodePgDatabase } from "drizzle-orm/node-postgres";
import pg from "pg";
import * as schema from "./schema.js";
import { applyInitSql } from "./migrate.js";
import { backfillFuelCatalog } from "./backfill-fuel-catalog.js";

export type Db = NodePgDatabase<typeof schema> & { $client?: pg.Pool };

export function connectPgDb(databaseUrl: string): { db: Db; pool: pg.Pool } {
  const pool = new pg.Pool({ connectionString: databaseUrl });
  return { db: drizzle(pool, { schema }), pool };
}

export async function createPgDb(databaseUrl: string): Promise<{ db: Db; pool: pg.Pool }> {
  const { db, pool } = connectPgDb(databaseUrl);
  await applyInitSql((sql) => pool.query(sql));
  await backfillFuelCatalog(db);
  return { db, pool };
}
