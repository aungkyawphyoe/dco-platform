import { PGlite } from "@electric-sql/pglite";
import { drizzle } from "drizzle-orm/pglite";
import { describe, expect, test } from "vitest";
import {
  applyInitSql,
  auditTrailSql,
  documentCreatedBySql,
  documentExpiresOnSql,
  familyVehicleGrantsSql,
  fleetFoundationSql,
  fuelLogOdometerSql,
  initSql,
  maintenanceCatalogKmSql,
  maintenanceCatalogSql,
  planTiersSql,
  usersUsernameSql,
  vehicleSharingSql,
} from "../src/db/migrate.js";
import type { Db } from "../src/db/client.js";
import * as schema from "../src/db/schema.js";
import { plans } from "../src/db/schema.js";
import { PLANS, PLAN_IDS, type Plan } from "../src/lib/plans.js";

async function legacyDb(): Promise<PGlite> {
  const client = new PGlite();
  const beforeTiers = [
    initSql(),
    maintenanceCatalogSql(),
    maintenanceCatalogKmSql(),
    fleetFoundationSql(),
    fuelLogOdometerSql(),
    documentExpiresOnSql(),
    familyVehicleGrantsSql(),
    usersUsernameSql(),
    vehicleSharingSql(),
    auditTrailSql(),
    documentCreatedBySql(),
  ];
  for (const sql of beforeTiers) await client.exec(sql);
  return client;
}

describe("plan tiers", () => {
  test("plans table seed matches the src/lib/plans.ts registry", async () => {
    const client = new PGlite();
    await applyInitSql(async (sql) => {
      await client.exec(sql);
    });
    const db = drizzle(client, { schema }) as unknown as Db;

    const rows = await db.select().from(plans);
    expect(rows.map((r) => r.id).sort()).toEqual([...PLAN_IDS].sort());
    for (const row of rows) {
      const def = PLANS[row.id as Plan];
      expect(def, `unknown plan id ${row.id}`).toBeDefined();
      expect(row.name).toBe(def.name);
      expect(row.vehicleLimit).toBe(def.vehicleLimit);
      expect(row.sharingLimit).toBe(def.sharingLimit);
      expect(row.storageBytes).toBe(def.storageBytes);
      expect(row.aiTier).toBe(def.aiTier);
      expect(row.priceMonthlyMmk).toBe(def.priceMonthlyMmk);
      expect(row.priceAnnualMmk).toBe(def.priceAnnualMmk);
    }

    await client.close();
  });

  test("0011 maps legacy premium users to standard and retires the premium enum value", async () => {
    const client = await legacyDb();
    await client.query(
      `INSERT INTO users (id, email, username, password_hash, role, plan)
       VALUES ('11111111-1111-1111-1111-111111111111', 'legacy@test.local', 'legacy', 'x', 'owner', 'premium')`,
    );

    await client.exec(planTiersSql());

    const mapped = await client.query<{ plan: string }>(
      `SELECT plan FROM users WHERE email = 'legacy@test.local'`,
    );
    expect(mapped.rows[0].plan).toBe("standard");

    const labels = await client.query<{ enumlabel: string }>(
      `SELECT e.enumlabel FROM pg_enum e
       JOIN pg_type t ON t.oid = e.enumtypid
       WHERE t.typname = 'user_plan' ORDER BY e.enumsortorder`,
    );
    expect(labels.rows.map((r) => r.enumlabel)).toEqual(["free", "lite", "standard", "fleet"]);

    // The retired value must be rejected after migration.
    await expect(
      client.query(
        `INSERT INTO users (id, email, username, password_hash, role, plan)
         VALUES ('22222222-2222-2222-2222-222222222222', 'old@test.local', 'old', 'x', 'owner', 'premium')`,
      ),
    ).rejects.toThrow();

    await client.close();
  });
});
