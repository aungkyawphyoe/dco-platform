import { gte } from "drizzle-orm";
import { loadEnv } from "../config/env.js";
import { createPgDb } from "../db/client.js";
import { playSubscriptions } from "../db/schema.js";
import { GooglePlayGateway, playConfigured } from "../lib/google-play.js";
import { syncPlayPurchase } from "../lib/play-subscriptions.js";

// Schedule hourly as a backstop for delayed/missed Pub/Sub delivery.
const env = loadEnv();
if (!playConfigured(env)) throw new Error("Play billing must be configured");
const { db, pool } = await createPgDb(env.DATABASE_URL);
let failures = 0;
try {
  const gateway = new GooglePlayGateway(env);
  const rows = await db.select().from(playSubscriptions)
    .where(gte(playSubscriptions.expiresAt, new Date(Date.now() - 60 * 86400000)));
  for (const row of rows) {
    try { await syncPlayPurchase(db, gateway, row.userId, row.purchaseToken); }
    catch { failures++; } // Tokens/credentials must never reach logs.
  }
  console.log(JSON.stringify({ checked: rows.length, failures }));
} finally { await pool.end(); }
if (failures) process.exitCode = 1;
