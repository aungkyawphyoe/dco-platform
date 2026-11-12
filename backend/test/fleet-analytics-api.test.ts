import { expect, it } from 'vitest';
import { eq } from 'drizzle-orm';
import { analyticsFixture } from './analytics-fixture.js';
import { organizationMembers, organizationVehicles, expenses } from '../src/db/schema.js';
import { applyInitSql } from '../src/db/migrate.js';
it('scopes reports and exports, locks currency, freezes transferred history, and survives migration replay', async () => {
  const {app,db,client,headers,orgId,vehicleId,userId}=await analyticsFixture();
  try {
    const base=`/v1/organizations/${orgId}/analytics`, query='from=2026-01-01&to=2026-09-30';
    expect((await app.inject({url:`${base}/report?${query}`,headers})).statusCode).toBe(200);
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

it('reports service types from service-record line items captured in the snapshot', async () => {
  const {app,client,headers,orgId,vehicleId}=await analyticsFixture();
  try {
    const serviceId=crypto.randomUUID();
    const created=await app.inject({method:'POST',url:`/v1/organizations/${orgId}/records/vehicles/${vehicleId}/service-records`,headers,payload:{
      id:serviceId,serviced_on:'2026-09-26',odometer:9800,total_cost:100000,
      items:[{name:'Oil change',line_cost:40000},{name:'Brake pads',line_cost:25000}],
    }});
    expect(created.statusCode,created.body).toBe(201);
    const snapshot=await client.query<{payload:{items:{name:string;line_cost:string|null}[]}}>(
      'SELECT payload FROM analytics_records WHERE org_id=$1 AND kind=$2 AND id=$3',[orgId,'service_record',serviceId]);
    expect(snapshot.rows[0]?.payload.items.map(item=>item.name).sort()).toEqual(['Brake pads','Oil change']);
    const report=await app.inject({url:`/v1/organizations/${orgId}/analytics/report?from=2026-09-26&to=2026-09-26`,headers});
    expect(report.statusCode,report.body).toBe(200);
    expect(report.json().total_cost).toBe(100000);
    expect(report.json().service_types).toEqual({'Oil change':40000,'Brake pads':25000,Unallocated:35000});
    const scoped=await app.inject({url:`/v1/organizations/${orgId}/analytics/records?from=2026-09-26&to=2026-09-26&categories=parking,parts`,headers});
    expect(scoped.json().total).toBe(0);
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
    const corrected=await app.inject({method:'PATCH',url:`/v1/organizations/${orgId}/records/fuel-logs/${id}`,
      headers:{...headers,'if-match':String(response.json().revision)},payload:{cost:12.75,currency:'EUR'}});
    expect(corrected.statusCode,corrected.body).toBe(200);
    expect(corrected.json()).toMatchObject({currency:'EUR',cost:12.75});
    const mirror=await client.query('SELECT currency,amount::text FROM expenses WHERE source_id=$1',[id]);
    expect(mirror.rows).toEqual([{currency:'EUR',amount:'12.75'}]);
  } finally {await app.close();await client.close();}
},30000);


it('displays totals in fleet currency and preserves original tags in records and exports', async () => {
  const {app,client,headers,orgId,vehicleId}=await analyticsFixture();
  try {
    const base=`/v1/organizations/${orgId}/analytics`, query='from=2026-01-01&to=2026-09-30';
    // A retained historical snapshot can differ from the current fleet currency.
    const foreignId=crypto.randomUUID();
    await client.query(`INSERT INTO analytics_records(org_id,vehicle_id,kind,id,payload) VALUES($1,$2,'expense',$3,$4::jsonb)`,
      [orgId,vehicleId,foreignId,JSON.stringify({amount:12.25,currency:'USD',incurred_on:'2026-09-25',category:'parking'})]);
    const report=await app.inject({url:`${base}/report?${query}`,headers});
    expect(report.json().currency).toBe('MMK');
    expect(report.json().total_cost).toBe(1962012.25);
    const records=await app.inject({url:`${base}/records?${query}`,headers});
    expect(records.json().items.find((r:{id:string})=>r.id===foreignId)).toMatchObject({amount:12.25,currency:'USD',included_in_total:true});
    const csv=await app.inject({url:`${base}/export?${query}&kind=expenses`,headers});
    expect(csv.body.split('\n').find(line=>line.includes(foreignId))).toContain('USD');
    const save=await app.inject({method:'PUT',url:`${base}/settings`,headers,payload:{timezone:'Asia/Bangkok'}});
    expect(save.statusCode,save.body).toBe(200);
    expect(save.json()).toEqual({currency:'MMK',timezone:'Asia/Bangkok'});
    expect((await app.inject({url:`${base}/settings`,headers})).json()).toEqual(save.json());
  } finally {await app.close();await client.close();}
},30000);
