import { readFileSync } from "node:fs";
import { PGlite } from "@electric-sql/pglite";
import { expect, it } from "vitest";
import { applyInitSql } from "../src/db/migrate.js";

const resetSql = readFileSync(new URL("../drizzle/0036_names_only_maintenance_catalog.sql", import.meta.url), "utf8");
const names = [
  "Air Conditioning", "Air Filter", "Battery", "Belts", "Brake Fluid", "Brake Pads",
  "Car Wash", "Fuel Filter", "Lights", "Mileage Update", "New Tires", "Oil Change",
  "Oil Filter", "Schedule Maintenance", "Suspension/Shock Absorbers",
  "Tires - Alignment/Balancing", "Tires - Pressure", "Tire - Rotation",
];

it("resets only maintenance data once and never restores legacy seeds on startup", async () => {
  const client = new PGlite();
  try {
    await applyInitSql(async (sql) => {
      if (sql !== resetSql) await client.exec(sql);
    });
    await client.exec(`
      INSERT INTO users(id,email,password_hash,username) VALUES ('10000000-0000-0000-0000-000000000001','reset@test.local','test','reset_test');
      INSERT INTO vehicles(id,user_id,name,make,model,year,license_plate,fuel_type,mileage)
        VALUES ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Daily','Honda','Fit',2020,'RESET','petrol',10000);
      INSERT INTO plan_items(id,vehicle_id,name,interval_days) VALUES ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Old oil',365);
      INSERT INTO plan_schedule_baselines(plan_item_id,next_due_mileage) VALUES ('30000000-0000-0000-0000-000000000001',15000);
      INSERT INTO service_records(id,vehicle_id,serviced_on,odometer,total_cost) VALUES ('40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','2026-01-01',10000,100);
      INSERT INTO service_record_items(id,service_record_id,plan_item_id,name) VALUES ('50000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Old oil');
      INSERT INTO parts(id,vehicle_id,name) VALUES ('60000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Filter');
      INSERT INTO service_record_parts(id,service_record_id,part_id,name) VALUES ('70000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','Filter');
      INSERT INTO expenses(id,vehicle_id,category,amount,incurred_on,source_kind,source_id) VALUES
        ('80000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','maintenance',100,'2026-01-01','service_record','40000000-0000-0000-0000-000000000001'),
        ('80000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','other',50,'2026-01-01',NULL,NULL);
      INSERT INTO documents(id,vehicle_id,name,category) VALUES ('90000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Invoice','invoice');
      INSERT INTO document_links(id,document_id,service_record_id) VALUES ('91000000-0000-0000-0000-000000000001','90000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001');
      INSERT INTO notification_feed(id,user_id,plan_item_id,title,body) VALUES ('92000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Due','Old');
      INSERT INTO change_log(user_id,entity_type,entity_id,op,payload) VALUES ('10000000-0000-0000-0000-000000000001','plan_item','30000000-0000-0000-0000-000000000001','upsert','{"name":"Old oil"}');
    `);
    await client.exec(resetSql);
    const catalog = await client.query<{ name: string; interval_days: number | null; interval_distance: string | null }>(
      "SELECT name, interval_days, interval_distance FROM maintenance_catalog ORDER BY sort_order",
    );
    expect(catalog.rows.map((row) => row.name)).toEqual(names);
    expect(catalog.rows.every((row) => row.interval_days === null && row.interval_distance === null)).toBe(true);
    for (const table of ["plan_items", "service_records", "service_record_items", "service_record_parts", "plan_schedule_baselines", "notification_feed", "document_links"]) {
      expect((await client.query(`SELECT * FROM ${table}`)).rows).toHaveLength(0);
    }
    for (const table of ["users", "vehicles", "parts", "documents", "expenses"]) {
      expect((await client.query(`SELECT * FROM ${table}`)).rows).toHaveLength(1);
    }
    expect((await client.query("SELECT op,payload FROM change_log WHERE entity_type='plan_item'")).rows)
      .toEqual([{ op: "delete", payload: { id: "30000000-0000-0000-0000-000000000001" } }]);
    await client.exec(`
      INSERT INTO plan_items(id,vehicle_id,name,next_due_mileage) VALUES ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','New reminder',15000);
      UPDATE maintenance_catalog SET name='Custom oil label' WHERE catalog_key='oil_change';
      DELETE FROM maintenance_catalog WHERE catalog_key='battery';
    `);
    await applyInitSql(async (sql) => { await client.exec(sql); });
    expect((await client.query("SELECT * FROM plan_items")).rows).toHaveLength(1);
    expect((await client.query("SELECT * FROM maintenance_catalog")).rows).toHaveLength(17);
    expect((await client.query("SELECT name FROM maintenance_catalog WHERE catalog_key='oil_change'")).rows)
      .toEqual([{ name: "Custom oil label" }]);
  } finally {
    await client.close();
  }
});
