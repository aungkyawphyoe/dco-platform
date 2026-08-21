import { existsSync, readFileSync } from "node:fs";
import { loadEnv } from "../config/env.js";
import { createPgDb } from "./client.js";

function loadLocalEnv() {
  if (!existsSync(".env")) return;
  for (const line of readFileSync(".env", "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const idx = trimmed.indexOf("=");
    if (idx < 0) continue;
    const key = trimmed.slice(0, idx);
    const value = trimmed.slice(idx + 1);
    if (process.env[key] === undefined) process.env[key] = value;
  }
}

loadLocalEnv();
const env = loadEnv();
const { pool } = await createPgDb(env.DATABASE_URL);
await pool.end();
console.log("migrations applied");
