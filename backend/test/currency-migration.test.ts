import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { describe, expect, it } from 'vitest';
import { applyInitSql } from '../src/db/migrate.js';

const migration = readFileSync(new URL('../drizzle/0031_operational_currency.sql', import.meta.url), 'utf8');
const ids = Array.from({ length: 10 }, () => crypto.randomUUID());
const [owner, buyer, vehicle, org, service, link, transfer, nextOrg, expense] = ids;

async function legacyFixture() {
  const db = new PGlite();
  await applyInitSql(async sql => { if (sql !== migration) await db.exec(sql); });
  await db.exec(`
    INSERT INTO users(id,username,email) VALUES ('${owner}','owner','owner@example.test'), ('${buyer}','buyer','buyer@example.test');
    INSERT INTO vehicles(id,user_id,name,make,model,year,license_plate,fuel_type,mileage,purchase_price)
      VALUES ('${vehicle}','${owner}','Car','Toyota','Vios',2020,'ABC','petrol',0,123456.75);
    INSERT INTO organizations(id,name,type,admin_user_id,created_by)
      VALUES ('${org}','Fleet','taxi_fleet','${owner}','${owner}');
    INSERT INTO organization_vehicles(id,org_id,vehicle_id,lifecycle_template,status,added_by)
      VALUES ('${link}','${org}','${vehicle}','commercial','active','${owner}');
    INSERT INTO service_records(id,vehicle_id,serviced_on,odometer,total_cost,created_by)
      VALUES ('${service}','${vehicle}','2026-10-01',100,50000.25,'${owner}');
    INSERT INTO transferred_vehicles(id,vehicle_id,org_id,buyer_user_id,transferred_by,service_snapshot,vehicle_snapshot)
      VALUES ('${transfer}','${vehicle}','${org}','${buyer}','${owner}',
      '[{"id":"${service}","total_cost":50000.25}]','{"purchase_price":123456.75}');
  `);
  return db;
}

describe('operational currency migration', () => {
  it('backfills live amounts and retained snapshots as MMK without numerical changes', async () => {
    const db = await legacyFixture();
    try {
      await db.exec(migration);
      expect((await db.query('SELECT currency,total_cost::text FROM service_records')).rows).toEqual([{ currency: 'MMK', total_cost: '50000.25' }]);
      expect((await db.query('SELECT currency,amount::text FROM expenses')).rows).toEqual([{ currency: 'MMK', amount: '50000.25' }]);
      expect((await db.query('SELECT purchase_currency,purchase_price::text FROM vehicles')).rows).toEqual([{ purchase_currency: 'MMK', purchase_price: '123456.75' }]);
      const snapshots = await db.query<{ service_snapshot: { currency: string; total_cost: number }[]; vehicle_snapshot: { purchase_currency: string } }>('SELECT service_snapshot,vehicle_snapshot FROM transferred_vehicles');
      expect(snapshots.rows[0].service_snapshot[0]).toMatchObject({ currency: 'MMK', total_cost: 50000.25 });
      expect(snapshots.rows[0].vehicle_snapshot.purchase_currency).toBe('MMK');
      expect((await db.query("SELECT DISTINCT payload->>'currency' AS currency FROM analytics_records")).rows).toEqual([{ currency: 'MMK' }]);
      expect((await db.query('SELECT currency FROM organizations')).rows).toEqual([{ currency: 'MMK' }]);
    } finally { await db.close(); }
  });

  it('does not reset choices or select currency for a newly provisioned fleet on reboot', async () => {
    const db = await legacyFixture();
    try {
      await db.exec(migration);
      await db.exec(`UPDATE organizations SET currency='THB' WHERE id='${org}';
        UPDATE users SET currency='CNY' WHERE id='${owner}';
        INSERT INTO organizations(id,name,type,admin_user_id,created_by)
        VALUES ('${nextOrg}','New Fleet','taxi_fleet','${buyer}','${owner}');`);
      await applyInitSql(async sql => { await db.exec(sql); });
      expect((await db.query(`SELECT currency FROM organizations WHERE id='${org}'`)).rows).toEqual([{ currency: 'THB' }]);
      expect((await db.query(`SELECT currency FROM organizations WHERE id='${nextOrg}'`)).rows).toEqual([{ currency: null }]);
      expect((await db.query(`SELECT currency FROM users WHERE id='${owner}'`)).rows).toEqual([{ currency: 'CNY' }]);
      await expect(db.exec(`UPDATE expenses SET currency='EUR'`)).rejects.toThrow();
    } finally { await db.close(); }
  });

  it('derived accounting inherits source currency through create and historical corrections', async () => {
    const db = await legacyFixture();
    try {
      await db.exec(migration);
      await db.exec(`INSERT INTO service_records(id,vehicle_id,serviced_on,odometer,total_cost,created_by,currency)
        VALUES ('${expense}','${vehicle}','2026-10-02',100,12.50,'${owner}','USD');`);
      expect((await db.query(`SELECT currency,amount::text FROM expenses WHERE source_id='${expense}'`)).rows).toEqual([{ currency: 'USD', amount: '12.50' }]);
      await expect(db.exec(`UPDATE expenses SET source_id='${expense}' WHERE id='${service}'`)).rejects.toThrow('currency_immutable');
      await expect(db.exec(`UPDATE service_records SET currency='CNY' WHERE id='${expense}'`)).rejects.toThrow('currency_immutable');
      await db.exec(`UPDATE organizations SET currency='THB' WHERE id='${org}';
        UPDATE service_records SET total_cost=11.25 WHERE id='${expense}';`);
      expect((await db.query(`SELECT currency,amount::text FROM expenses WHERE source_id='${expense}'`)).rows).toEqual([{ currency: 'USD', amount: '11.25' }]);
      await applyInitSql(async sql => { await db.exec(sql); });
      await db.exec(`UPDATE service_records SET total_cost=10.25 WHERE id='${expense}';`);
      expect((await db.query(`SELECT currency,amount::text FROM expenses WHERE source_id='${expense}'`)).rows).toEqual([{ currency: 'USD', amount: '10.25' }]);
    } finally { await db.close(); }
  });
});
