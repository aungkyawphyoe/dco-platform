import { drizzle, type NodePgDatabase } from "drizzle-orm/node-postgres";
import pg from "pg";
import * as schema from "./schema.js";
import { applyInitSql } from "./migrate.js";

export type Db = NodePgDatabase<typeof schema> & { $client?: pg.Pool };

export async function createPgDb(databaseUrl: string): Promise<{ db: Db; pool: pg.Pool }> {
  const pool = new pg.Pool({ connectionString: databaseUrl });
  await applyInitSql((sql) => pool.query(sql));
  const db = drizzle(pool, { schema }) as Db;
  return { db, pool };
}
