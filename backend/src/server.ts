process.stderr.write("[BOOT] imports starting\n");
import { existsSync, readFileSync } from "node:fs";
import { loadEnv } from "./config/env.js";
import { createPgDb } from "./db/client.js";
import { bootstrapAdmin } from "./lib/bootstrap.js";
import { createMailer } from "./lib/mail.js";
import { createMediaStore } from "./lib/media.js";
import { buildApp } from "./app.js";
process.stderr.write("[BOOT] imports done\n");

loadLocalEnv();

async function main() {
  console.error("[STARTUP] Loading env...");
  const env = loadEnv();
  console.error("[STARTUP] Connecting to DB...");
  const { db, pool } = await createPgDb(env.DATABASE_URL);
  console.error("[STARTUP] Bootstrapping admin...");
  await bootstrapAdmin(db, env);
  console.error("[STARTUP] Building app...");
  const app = await buildApp({
    env,
    db,
    mailer: createMailer(env),
    media: createMediaStore(env),
  });
  console.error("[STARTUP] Listening on port " + env.PORT);
  await app.listen({ port: env.PORT, host: "0.0.0.0" });
  const shutdown = async () => {
    await app.close();
    await pool.end();
    process.exit(0);
  };
  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);
}

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

process.on("uncaughtException", (err) => {
  console.error("UNCAUGHT:", err);
  process.exit(1);
});
process.on("unhandledRejection", (err) => {
  console.error("UNHANDLED:", err);
  process.exit(1);
});

main().catch((err) => {
  console.error("MAIN ERROR:", err);
  process.exit(1);
});
