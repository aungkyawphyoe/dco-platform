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

/** Drive the reviewed showroom handover flow used by fleet integration fixtures. */
export async function completeHandover(
  app: Awaited<ReturnType<typeof createTestApp>>['app'],
  options: {
    orgId: string;
    token: string;
    vehicleId: string;
    buyerEmail: string;
    saleDate?: string;
    currentMileageKm?: number;
    warrantyTemplateId?: string | null;
    plan?: Array<Record<string, unknown>>;
  },
) {
  const headers = { authorization: `Bearer ${options.token}` };
  const lookup = await app.inject({
    method: 'GET',
    url: `/v1/organizations/${options.orgId}/handover-buyers?email=${encodeURIComponent(options.buyerEmail)}`,
    headers,
  });
  if (lookup.statusCode !== 200) return lookup;
  const created = await app.inject({
    method: 'POST', url: `/v1/organizations/${options.orgId}/handovers`, headers,
    payload: {
      vehicle_id: options.vehicleId,
      buyer_user_id: lookup.json().user_id,
      sale_date: options.saleDate ?? new Date().toISOString().slice(0, 10),
      ...(options.currentMileageKm !== undefined ? { current_mileage_km: options.currentMileageKm } : {}),
      plan: options.plan ?? [{ name: 'Initial service', initial_service_required: true }],
      warranty_choice: options.warrantyTemplateId ? 'template' : 'none',
      ...(options.warrantyTemplateId ? { warranty_template_id: options.warrantyTemplateId } : {}),
    },
  });
  if (created.statusCode !== 201) return created;
  const reviewed = await app.inject({
    method: 'POST', url: `/v1/organizations/${options.orgId}/handovers/${created.json().id}/review`, headers,
    payload: { revision: created.json().revision },
  });
  if (reviewed.statusCode !== 200) return reviewed;
  return app.inject({
    method: 'POST', url: `/v1/organizations/${options.orgId}/handovers/${created.json().id}/complete`, headers,
    payload: { reviewed_revision: reviewed.json().revision, acknowledged: true },
  });
}
