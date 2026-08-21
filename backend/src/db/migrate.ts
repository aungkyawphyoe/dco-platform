import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

export function initSql(): string {
  return readFileSync(join(here, "../../drizzle/0000_init.sql"), "utf8");
}

export async function applyInitSql(exec: (sql: string) => Promise<unknown>): Promise<void> {
  await exec(initSql());
}
