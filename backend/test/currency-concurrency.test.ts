import pg from 'pg';
import { expect, it } from 'vitest';
import { applyInitSql } from '../src/db/migrate.js';

// Opt-in only: use a disposable PostgreSQL database, never a deployed database.
const url=process.env.CURRENCY_TEST_DATABASE_URL;
it.skipIf(!url)('serializes currency changes, first costs, and ownership changes on PostgreSQL',async()=>{
  const admin=new pg.Client({connectionString:url}), first=new pg.Client({connectionString:url}), second=new pg.Client({connectionString:url});
  const schema=`currency_test_${crypto.randomUUID().replaceAll('-','')}`;
  await Promise.all([admin.connect(),first.connect(),second.connect()]);
  try {
    await admin.query(`CREATE SCHEMA ${schema}`);
    for(const client of [admin,first,second]) await client.query(`SET search_path TO ${schema}`);
    await applyInitSql(sql=>admin.query(sql));
    const owner=crypto.randomUUID(),buyer=crypto.randomUUID(),vehicle=crypto.randomUUID();
    await admin.query('INSERT INTO users(id,username,email) VALUES($1::uuid,$1::text,$1::text),($2::uuid,$2::text,$2::text)',[owner,buyer]);
    await admin.query("INSERT INTO vehicles(id,user_id,name,make,model,year,license_plate,fuel_type,mileage) VALUES($1,$2,'Car','Toyota','Vios',2020,'ABC','petrol',0)",[vehicle,owner]);
    await admin.query('UPDATE operational_currency_control SET enabled=true');
    const pid=(await second.query('SELECT pg_backend_pid() AS pid')).rows[0].pid;
    async function blocked() {
      const end=Date.now()+3000;
      while(Date.now()<end) {
        const result=await admin.query('SELECT cardinality(pg_blocking_pids($1)) AS n',[pid]);
        if(result.rows[0].n>0)return;
        await new Promise(resolve=>setTimeout(resolve,20));
      }
      throw new Error('Expected the competing write to wait for the first transaction');
    }
    const insert=(client:pg.Client,currency:string)=>client.query("INSERT INTO expenses(id,vehicle_id,category,amount,incurred_on,currency) VALUES($1,$2,'parking',100,'2026-10-29',$3)",[crypto.randomUUID(),vehicle,currency]);
    await first.query('BEGIN');await first.query("UPDATE users SET currency='THB' WHERE id=$1",[owner]);
    await second.query('BEGIN');
    const stale=insert(second,'MMK').then(()=>null,error=>error as Error);
    await blocked();await first.query('COMMIT');expect((await stale)?.message).toContain('currency_mismatch');await second.query('ROLLBACK');
    expect((await admin.query('SELECT currency_locked_at FROM users WHERE id=$1',[owner])).rows[0].currency_locked_at).toBeNull();
    await first.query('BEGIN');await insert(first,'THB');await second.query('BEGIN');
    const change=second.query("UPDATE users SET currency='USD' WHERE id=$1",[owner]).then(()=>null,error=>error as Error);
    await blocked();await first.query('COMMIT');expect((await change)?.message).toContain('currency_locked');await second.query('ROLLBACK');
    await admin.query('DELETE FROM expenses');
    expect((await admin.query('SELECT currency_locked_at FROM users WHERE id=$1',[owner])).rows[0].currency_locked_at).not.toBeNull();
    await first.query('BEGIN');await first.query('UPDATE vehicles SET user_id=$1 WHERE id=$2',[buyer,vehicle]);await second.query('BEGIN');
    const transfer=insert(second,'THB').then(()=>null,error=>error as Error);
    await blocked();await first.query('COMMIT');expect((await transfer)?.message).toContain('currency_mismatch');await second.query('ROLLBACK');
    expect((await admin.query('SELECT currency_locked_at FROM users WHERE id=$1',[buyer])).rows[0].currency_locked_at).toBeNull();
    await first.query('BEGIN');await insert(first,'MMK');await first.query('ROLLBACK');
    expect((await admin.query('SELECT currency_locked_at FROM users WHERE id=$1',[buyer])).rows[0].currency_locked_at).toBeNull();
  } finally {
    await Promise.all([first.query('ROLLBACK'),second.query('ROLLBACK')]);
    await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
    await Promise.all([admin.end(),first.end(),second.end()]);
  }
});
