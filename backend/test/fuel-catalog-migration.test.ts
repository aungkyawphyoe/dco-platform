import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { expect, it } from 'vitest';
import { applyInitSql } from '../src/db/migrate.js';

it('renames legacy fuel history and change-log snapshots once, preserving IDs and costs', async () => {
  const db = new PGlite();
  const migration = readFileSync(new URL('../drizzle/0044_fuel_catalog_battery.sql', import.meta.url), 'utf8');
  try {
    await applyInitSql(async statement => { if (statement !== migration) await db.exec(statement); });
    await db.exec(`
      INSERT INTO users(id,email,username) VALUES ('10000000-0000-0000-0000-000000000001','fuel@test.local','fuel');
      INSERT INTO vehicles(id,user_id,name,make,model,year,license_plate,fuel_type,mileage)
      VALUES ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','EV','Tesla','3',2024,'FUEL','electric',100);
      INSERT INTO fuel_types(id,user_id,name,kind,unit) VALUES
      ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Electricity','electric','kWh');
      INSERT INTO fuel_logs(id,user_id,vehicle_id,kind,fuel_type_id,fuel_type_name,unit,logged_on,amount,cost)
      VALUES ('40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','charge','30000000-0000-0000-0000-000000000001','Electricity','kWh','2026-01-01',10,7500);
      INSERT INTO change_log(user_id,entity_type,entity_id,op,payload) VALUES
      ('10000000-0000-0000-0000-000000000001','fuel_log','40000000-0000-0000-0000-000000000001','upsert','{"fuel_type_name":"Electricity","cost":7500}');
    `);
    await db.exec(migration);
    const logs = await db.query<{fuel_type_id:string;fuel_type_name:string;cost:string;battery_level:number|null}>('SELECT fuel_type_id,fuel_type_name,cost,battery_level FROM fuel_logs');
    expect(logs.rows[0]).toMatchObject({fuel_type_id:'30000000-0000-0000-0000-000000000001',fuel_type_name:'Electric (Fast)',battery_level:null});
    expect(Number(logs.rows[0].cost)).toBe(7500);
    expect((await db.query<{payload:unknown}>("SELECT payload FROM change_log WHERE entity_type='fuel_log'")).rows[0].payload)
      .toEqual({fuel_type_name:'Electric (Fast)',cost:7500});
    await db.exec(migration);
    expect((await db.query('SELECT * FROM fuel_logs')).rows).toHaveLength(1);
  } finally { await db.close(); }
});
