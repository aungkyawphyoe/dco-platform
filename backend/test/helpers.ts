import { PGlite } from "@electric-sql/pglite";
import { drizzle } from "drizzle-orm/pglite";
import { loadEnv } from "../src/config/env.js";
import { buildApp } from "../src/app.js";
import type { Db } from "../src/db/client.js";
import { applyInitSql } from "../src/db/migrate.js";
import * as schema from "../src/db/schema.js";
import { bootstrapAdmin } from "../src/lib/bootstrap.js";
import { createMailer } from "../src/lib/mail.js";
import { createMediaStore } from "../src/lib/media.js";

export const testEnv = loadEnv({
  APP_ENV: "local",
  PORT: "8080",
  DATABASE_URL: "postgres://ignored",
  JWT_ACCESS_SECRET: "test-access-secret-32-chars-min",
  JWT_REFRESH_SECRET: "test-refresh-secret-32-chars-min",
  JWT_ACCESS_TTL: "15m",
  JWT_REFRESH_TTL: "720h",
  JWT_OWNER_AUD: "dco-owner",
  JWT_ADMIN_AUD: "dco-admin",
  BOOTSTRAP_ADMIN_EMAIL: "admin@test.local",
  BOOTSTRAP_ADMIN_PASSWORD: "AdminPass123!",
  MAIL_PROVIDER: "stdout",
  MAIL_FROM: "noreply@test.local",
  MEDIA_DRIVER: "local",
  MEDIA_LOCAL_DIR: "var/media-test",
  MEDIA_SIGNING_KEY: "test-media-signing-key",
  CORS_ORIGINS: "http://localhost:5173",
  PUBLIC_API_URL: "http://localhost:8080/v1",
  LICENSE_KID: "lic-test-2026-10",
  // Deterministic Ed25519 test key (minted via `npm run license:key`); test-only.
  LICENSE_ED25519_KEY: "MC4CAQAwBQYDK2VwBCIEIG9YssLh8bg7iAcnYU-5xCpVFnDS5OCL5joOZ72HwPas",
  LICENSE_TTL_DAYS: "30",
} as NodeJS.ProcessEnv);

export async function createTestApp() {
  const client = new PGlite();
  await applyInitSql(async (sql) => {
    await client.exec(sql);
  });
  const db = drizzle(client, { schema }) as unknown as Db;
  await bootstrapAdmin(db, testEnv);
  const app = await buildApp({
    env: testEnv,
    db,
    mailer: createMailer(testEnv),
    media: createMediaStore(testEnv),
  });
  await app.ready();
  return { app, db, client };
}

export function uuid(): string {
  return crypto.randomUUID();
}

/** Fleet workflow fixtures require an explicit term under subscription enforcement. */
export async function grantTestFleet(app: Awaited<ReturnType<typeof createTestApp>>['app'], token: string, id: string) {
  const result = await app.inject({ method: 'POST', url: '/v1/admin/subscriptions', headers: { authorization: `Bearer ${token}` }, payload: {
    kind:'organization', id, request_id:uuid(), plan:'fleet', source:'complimentary', reason:'Fleet workflow test fixture',
    starts_at:new Date(Date.now()-60000).toISOString(), unit:'years', count:1,
  }});
  if(result.statusCode !== 200) throw new Error(result.body);
}
