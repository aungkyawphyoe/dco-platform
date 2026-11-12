import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { applyInitSql } from '../src/db/migrate.js';

const migration = readFileSync(new URL('../drizzle/0040_vehicle_ownership_periods.sql', import.meta.url), 'utf8');
const owner = '00000000-0000-4000-8000-000000000001';
const buyer = '00000000-0000-4000-8000-000000000002';
const vehicle = '00000000-0000-4000-8000-000000000003';
const org = '00000000-0000-4000-8000-000000000004';
const service = '00000000-0000-4000-8000-000000000005';
async function fixture(legacy = false) {
  const db = new PGlite();
  await applyInitSql(async sql => { if (!legacy || !sql.includes('reconcile_vehicle_ownership')) await db.exec(sql); });
  await db.exec(`INSERT INTO users(id,username,email) VALUES
    ('${owner}','period-owner','period-owner@test.local'),('${buyer}','period-buyer','period-buyer@test.local');
    INSERT INTO vehicles(id,user_id,name,make,model,year,license_plate,vin,fuel_type,mileage)
    VALUES('${vehicle}','${owner}','Period car','Honda','Civic',2023,'PERIOD-1','PERIOD00000000001','petrol',43000);
    INSERT INTO organizations(id,name,type,admin_user_id,created_by) VALUES('${org}','Period showroom','showroom','${owner}','${owner}');
    INSERT INTO organization_vehicles(id,org_id,vehicle_id,lifecycle_template,status,added_by)
    VALUES(gen_random_uuid(),'${org}','${vehicle}','showroom','reserved','${owner}');`);
  return db;
}
async function addService(db: PGlite) {
  await db.exec(`INSERT INTO service_records(id,vehicle_id,serviced_on,odometer,total_cost)
    VALUES('${service}','${vehicle}','2020-01-01',40000,100);`);
}

describe('ownership attribution foundation', () => {
  it('retains showroom attribution across handover and attributes new backdated records to the buyer', async () => {
    const db = await fixture();
    try {
      await addService(db);
      const before = await db.query<{ownership_period_id:string}>(`SELECT ownership_period_id FROM service_records WHERE id='${service}'`);
      const period = before.rows[0].ownership_period_id;
      expect(period).toBeTruthy();
      expect((await db.query(`SELECT org_id FROM vehicle_ownership_periods WHERE id='${period}'`)).rows).toEqual([{org_id:org}]);
      await db.exec(`BEGIN; UPDATE vehicles SET user_id='${buyer}' WHERE id='${vehicle}'; DELETE FROM organization_vehicles WHERE vehicle_id='${vehicle}'; ROLLBACK;`);
      expect((await db.query(`SELECT id FROM vehicle_ownership_periods WHERE vehicle_id='${vehicle}' AND ended_at IS NULL`)).rows).toEqual([{id:period}]);
      await db.exec(`BEGIN; UPDATE vehicles SET user_id='${buyer}' WHERE id='${vehicle}'; DELETE FROM organization_vehicles WHERE vehicle_id='${vehicle}'; COMMIT;`);
      expect((await db.query(`SELECT user_id FROM vehicle_ownership_periods WHERE vehicle_id='${vehicle}' AND ended_at IS NULL`)).rows).toEqual([{user_id:buyer}]);
      expect((await db.query(`SELECT ended_at IS NOT NULL AS closed FROM vehicle_ownership_periods WHERE id='${period}'`)).rows).toEqual([{closed:true}]);
      await db.exec(`UPDATE service_records SET total_cost=120 WHERE id='${service}';
        INSERT INTO expenses(id,vehicle_id,category,amount,incurred_on) VALUES(gen_random_uuid(),'${vehicle}','other',10,'2019-01-01');`);
      expect((await db.query(`SELECT ownership_period_id FROM service_records WHERE id='${service}'`)).rows).toEqual([{ownership_period_id:period}]);
      expect((await db.query(`SELECT ownership_period_id FROM expenses WHERE source_id='${service}'`)).rows).toEqual([{ownership_period_id:period}]);
      expect((await db.query(`SELECT p.user_id FROM expenses e JOIN vehicle_ownership_periods p ON p.id=e.ownership_period_id WHERE e.source_id IS NULL`)).rows).toEqual([{user_id:buyer}]);
      await expect(db.exec(`UPDATE service_records SET ownership_period_id=(SELECT id FROM vehicle_ownership_periods WHERE vehicle_id='${vehicle}' AND ended_at IS NULL) WHERE id='${service}'`)).rejects.toThrow('ownership_attribution_immutable');
      await expect(db.exec(`INSERT INTO parts(id,vehicle_id,name,ownership_period_id) VALUES(gen_random_uuid(),'${vehicle}','Spoofed','${period}')`)).rejects.toThrow('ownership_period_mismatch');
      const periods = (await db.query('SELECT id FROM vehicle_ownership_periods')).rows;
      await db.exec(migration);
      expect((await db.query('SELECT id FROM vehicle_ownership_periods')).rows).toEqual(periods);
    } finally { await db.close(); }
  });

  it('flags legacy history without inventing ownership, and preserves it on reapplication', async () => {
    const db = await fixture(true);
    try {
      await addService(db);
      await db.exec(migration);
      expect((await db.query('SELECT ownership_period_id FROM service_records')).rows).toEqual([{ownership_period_id:null}]);
      expect((await db.query(`SELECT entity_id FROM ownership_migration_reviews WHERE entity_type='service_records'`)).rows).toEqual([{entity_id:service}]);
      await db.exec(migration);
      expect((await db.query(`SELECT entity_id FROM ownership_migration_reviews WHERE entity_type='service_records'`)).rows).toHaveLength(1);
      expect((await db.query('SELECT total_cost::text FROM service_records')).rows).toEqual([{total_cost:'100.00'}]);
      await expect(db.exec(`INSERT INTO vehicle_ownership_periods(vehicle_id,user_id,org_id,origin) VALUES('${vehicle}','${buyer}','${org}','observed')`)).rejects.toThrow();
      await expect(db.exec(`INSERT INTO vehicle_ownership_periods(vehicle_id,user_id,origin) VALUES('${vehicle}','${buyer}','observed')`)).rejects.toThrow();
    } finally { await db.close(); }
  });
});
