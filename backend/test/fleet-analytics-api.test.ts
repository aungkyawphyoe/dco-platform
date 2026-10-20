import { expect, it } from 'vitest';
import { eq } from 'drizzle-orm';
import { analyticsFixture } from './analytics-fixture.js';
import { organizationMembers, organizationVehicles, expenses } from '../src/db/schema.js';
import { applyInitSql } from '../src/db/migrate.js';
it('scopes reports and exports, locks currency, freezes transferred history, and survives migration replay', async () => {
  const {app,db,client,headers,orgId,vehicleId,userId}=await analyticsFixture();
  try {
    const base=`/v1/organizations/${orgId}/analytics`, query='from=2026-01-01&to=2026-09-30';
    expect((await app.inject({url:`${base}/report?${query}`,headers})).statusCode).toBe(409);
    const save=await app.inject({method:'PUT',url:`${base}/settings`,headers,payload:{currency:'MMK',timezone:'Asia/Yangon',confirm_existing_amounts:true}});
    expect(save.statusCode,save.body).toBe(200);
    expect((await app.inject({method:'PUT',url:`${base}/settings`,headers,payload:{currency:'USD',timezone:'UTC',confirm_existing_amounts:true}})).statusCode).toBe(409);
    const report=await app.inject({url:`${base}/report?${query}`,headers});
    expect(report.statusCode,report.body).toBe(200);
    const total=report.json().total_cost;
    expect(total).toBe(1962000);
    const records=await app.inject({url:`${base}/records?${query}`,headers});
    expect(records.json().total).toBe(27); expect(records.json().items[0].entered_by).toBe('Fleet manager');
    const csv=await app.inject({url:`${base}/export?${query}&kind=expenses`,headers});
    expect(csv.statusCode).toBe(200); expect(csv.body).toContain('MMK');
    expect((await app.inject({url:`${base}/report?${query}&vehicles=${crypto.randomUUID()}`,headers})).statusCode).toBe(404);
    expect((await app.inject({url:`${base}/report?from=2026-02-30&to=2026-03-01`,headers})).statusCode).toBe(422);
    await db.update(organizationMembers).set({role:'org_mechanic'}).where(eq(organizationMembers.userId,userId));
    expect((await app.inject({url:`${base}/export?${query}`,headers})).statusCode).toBe(403);
    await db.update(organizationMembers).set({role:'org_admin'}).where(eq(organizationMembers.userId,userId));
    await db.delete(organizationVehicles).where(eq(organizationVehicles.vehicleId,vehicleId));
    await db.update(expenses).set({amount:'999999'}).where(eq(expenses.vehicleId,vehicleId));
    await db.insert(expenses).values({id:crypto.randomUUID(),vehicleId,category:'parking',amount:'888888',incurredOn:'2026-05-01'});
    await applyInitSql(s=>client.exec(s));
    const frozen=await app.inject({url:`${base}/report?${query}`,headers});
    expect(frozen.statusCode,frozen.body).toBe(200); expect(frozen.json().total_cost).toBe(total); expect(frozen.json().vehicles[0].status).toBe('transferred');
    expect((await app.inject({url:`${base}/report?${query}&active=true`,headers})).json().total_cost).toBe(0);
  } finally {await app.close();await client.close();}
},30000);

it('persists full/partial tank status through shared organization record writes', async () => {
  const {app,client,headers,orgId,vehicleId,typeId}=await analyticsFixture();
  try {
    const id=crypto.randomUUID();
    const response=await app.inject({method:'POST',url:`/v1/organizations/${orgId}/records/vehicles/${vehicleId}/fuel-logs`,headers,payload:{id,fuel_type_id:typeId,logged_on:'2026-09-25',amount:12,cost:30000,odometer:9600,fill_status:'partial'}});
    expect(response.statusCode,response.body).toBe(201);
    expect(response.json().fill_status).toBe('partial');
    const snapshot=await client.query<{payload:{fill_status:string}}>('SELECT payload FROM analytics_records WHERE org_id=$1 AND kind=$2 AND id=$3',[orgId,'fuel_log',id]);
    expect(snapshot.rows[0].payload.fill_status).toBe('partial');
  } finally {await app.close();await client.close();}
},30000);
