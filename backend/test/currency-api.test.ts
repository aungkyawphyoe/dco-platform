import { describe, expect, it } from 'vitest';
import { eq, sql } from 'drizzle-orm';
import { createTestApp, uuid, testEnv } from './helpers.js';
import { users, vehicles, vehicleShares, organizations, organizationMembers, organizationVehicles, expenses, driverAssignments, workOrders } from '../src/db/schema.js';
import { signAccess } from '../src/lib/crypto.js';

type State = Awaited<ReturnType<typeof createTestApp>>;
async function activate(state: State) { await state.db.execute(sql`UPDATE operational_currency_control SET enabled=true`); }
async function account(state: State, currency='MMK') {
  const result=await state.app.inject({method:'POST',url:'/v1/auth/signup',payload:{email:`${uuid()}@test.local`,password:'password1',currency}});
  expect(result.statusCode,result.body).toBe(201);
  return { id:result.json().user.id as string, headers:{authorization:`Bearer ${result.json().access_token}`} };
}
async function car(state:State, owner:Awaited<ReturnType<typeof account>>) {
  const id=uuid(); const response=await state.app.inject({method:'POST',url:'/v1/vehicles',headers:owner.headers,payload:{id,name:'Car',make:'Toyota',model:'Vios',year:2020,license_plate:id.slice(0,8),fuel_type:'petrol',mileage:0}});
  expect(response.statusCode,response.body).toBe(201);return id;
}
const expense=(currency?:string,amount=10)=>({id:uuid(),category:'parking',amount,incurred_on:'2026-10-29',...(currency?{currency}:{})});

describe('operational currency API',()=>{
  it('offers currency selection by default and defaults signup to MMK',async()=>{
    const state=await createTestApp();try {
      const user=await account(state);
      const read=await state.app.inject({url:'/v1/me/currency',headers:user.headers});
      expect(read.json()).toMatchObject({currency:'MMK',locked:false,enabled:true,default_currency:'MMK'});
      const result=await state.app.inject({method:'PUT',url:'/v1/me/currency',headers:user.headers,payload:{currency:'THB',expected_currency:'MMK'}});
      expect(result.json()).toMatchObject({currency:'THB',locked:false});
    } finally {await state.app.close();await state.client.close();}
  });
  it('validates intended currency and permits changes after recording costs',async()=>{
    const state=await createTestApp();try {
      await activate(state);const user=await account(state);const id=await car(state,user);
      const change=await state.app.inject({method:'PUT',url:'/v1/me/currency',headers:user.headers,payload:{currency:'THB',expected_currency:'MMK'}});
      expect(change.statusCode,change.body).toBe(200);
      const send=(payload:object)=>state.app.inject({method:'POST',url:`/v1/vehicles/${id}/expenses`,headers:user.headers,payload});
      const malformed=await send([]);expect(malformed.statusCode,malformed.body).toBe(422);
      expect((await send(expense())).json().error.code).toBe('currency_required');
      expect((await send(expense('MMK'))).json().error.code).toBe('currency_mismatch');
      expect((await send(expense('THB',0.001))).json().error.code).toBe('invalid_money_precision');
      expect((await state.app.inject({url:'/v1/me/currency',headers:user.headers})).json().locked).toBe(false);
      const body=expense('THB',10);const saved=await send(body);expect(saved.statusCode,saved.body).toBe(201);expect(saved.json().currency).toBe('THB');
      expect((await send(body)).statusCode).toBe(201);
      const removed=await state.app.inject({method:'DELETE',url:`/v1/expenses/${body.id}`,headers:user.headers});expect(removed.statusCode,removed.body).toBe(204);
      const changeLocked=await state.app.inject({method:'PUT',url:'/v1/me/currency',headers:user.headers,payload:{currency:'MMK',expected_currency:'THB'}});
      expect(changeLocked.json()).toMatchObject({currency:'MMK',locked:false});

    }finally {await state.app.close();await state.client.close();}
  });
  it('preserves history after transfer and allows authorized manual corrections',async()=>{
    const state=await createTestApp();try {
      await activate(state);const owner=await account(state,'MMK');const other=await account(state,'THB');const id=await car(state,owner);
      await state.db.insert(vehicleShares).values({id:uuid(),vehicleId:id,userId:other.id,grantedBy:owner.id,accessLevel:'add_edit_own',status:'active'});
      const policyUrl=`/v1/vehicles/${id}/currency`;
      const policy={base_currency:'EUR',allow_member_currency:false};
      expect((await state.app.inject({method:'PUT',url:policyUrl,headers:other.headers,payload:policy})).statusCode).toBe(403);
      expect((await state.app.inject({method:'PUT',url:policyUrl,headers:owner.headers,payload:policy})).statusCode).toBe(200);
      expect((await state.app.inject({url:policyUrl,headers:other.headers})).json().currency).toBe('EUR');
      expect((await state.app.inject({method:'PUT',url:policyUrl,headers:owner.headers,payload:{...policy,allow_member_currency:true}})).statusCode).toBe(200);
      expect((await state.app.inject({url:policyUrl,headers:other.headers})).json().currency).toBe('THB');
      const body=expense('MMK',50000);
      const result=await state.app.inject({method:'POST',url:`/v1/vehicles/${id}/expenses`,headers:other.headers,payload:body});
      expect(result.statusCode,result.body).toBe(201);
      expect((await state.app.inject({url:'/v1/me/currency',headers:owner.headers})).json().locked).toBe(false);
      expect((await state.app.inject({url:'/v1/me/currency',headers:other.headers})).json().locked).toBe(false);
      await state.db.update(vehicles).set({userId:other.id}).where(eq(vehicles.id,id));
      const corrected=await state.app.inject({method:'PATCH',url:`/v1/expenses/${body.id}`,headers:other.headers,payload:{amount:45000,currency:'MMK'}});
      expect(corrected.statusCode,corrected.body).toBe(200);expect(corrected.json().currency).toBe('MMK');
      expect((await state.app.inject({url:'/v1/me/currency',headers:other.headers})).json().locked).toBe(false);
      const relabel=await state.app.inject({method:'PATCH',url:`/v1/expenses/${body.id}`,headers:other.headers,payload:{amount:45000,currency:'THB'}});
      expect(relabel.statusCode,relabel.body).toBe(200);
    }finally {await state.app.close();await state.client.close();}
  });
  it('preserves amounts and changes historical tags only on explicit request',async()=>{
    const state=await createTestApp();try {
      const user=await account(state,'USD'), id=await car(state,user);
      const entry=expense('USD',19.75);
      const saved=await state.app.inject({method:'POST',url:`/v1/vehicles/${id}/expenses`,headers:user.headers,payload:entry});
      expect(saved.statusCode,saved.body).toBe(201);
      const set=(currency:string, expected_currency:string,relabel_history=false)=>state.app.inject({method:'PUT',url:'/v1/me/currency',headers:user.headers,payload:{currency,expected_currency,relabel_history}});
      expect((await set('EUR','USD')).statusCode).toBe(200);
      const read=async()=> (await state.db.select().from(expenses).where(eq(expenses.id,entry.id)))[0];
      expect(await read()).toMatchObject({currency:'USD',amount:'19.75'});
      expect((await set('EUR','EUR',true)).statusCode).toBe(200);
      expect(await read()).toMatchObject({currency:'EUR',amount:'19.75'});
    }finally {await state.app.close();await state.client.close();}
  });
  it('handles stale offline writes as conflicts while applying unrelated valid operations',async()=>{
    const state=await createTestApp();try {
      await activate(state);const user=await account(state,'CNY');const id=await car(state,user);
      const bad=expense('MMK');const good=expense('CNY',12.25);
      const response=await state.app.inject({method:'POST',url:'/v1/sync/push',headers:user.headers,payload:{operations:[bad,good].map(payload=>({entity_type:'expense',entity_id:payload.id,op:'upsert',payload:{...payload,vehicle_id:id},client_ts:new Date().toISOString()}))}});
      expect(response.statusCode,response.body).toBe(200);
      expect(response.json().results.map((r:{status:string})=>r.status)).toEqual(['conflict','idempotent']);
      expect((await state.db.select().from(expenses)).map(e=>e.currency)).toEqual(['CNY']);
    }finally {await state.app.close();await state.client.close();}
  });
  it('allows changes after a free service and preserves unchanged legacy fractional MMK edits',async()=>{
    const state=await createTestApp();try {
      const legacy=await account(state);const legacyCar=await car(state,legacy);
      const body=expense('MMK',50000.25);
      const saved=await state.app.inject({method:'POST',url:`/v1/vehicles/${legacyCar}/expenses`,headers:legacy.headers,payload:body});
      expect(saved.statusCode,saved.body).toBe(201);
      await activate(state);
      const unchanged=await state.app.inject({method:'PATCH',url:`/v1/expenses/${body.id}`,headers:legacy.headers,payload:{currency:'MMK',amount:50000.25,notes:'Corrected receipt note'}});
      expect(unchanged.statusCode,unchanged.body).toBe(200);
      const fractional=await state.app.inject({method:'PATCH',url:`/v1/expenses/${body.id}`,headers:legacy.headers,payload:{currency:'MMK',amount:45000.25}});
      expect(fractional.json().error.code).toBe('invalid_money_precision');
      const user=await account(state);const id=await car(state,user);
      const malformedService=await state.app.inject({method:'POST',url:`/v1/vehicles/${id}/service-records`,headers:user.headers,payload:{id:uuid(),serviced_on:'2026-10-29',odometer:0,total_cost:0,currency:'MMK',items:[null]}});
      expect(malformedService.statusCode,malformedService.body).toBe(422);
      const free=await state.app.inject({method:'POST',url:`/v1/vehicles/${id}/service-records`,headers:user.headers,payload:{id:uuid(),serviced_on:'2026-10-29',odometer:0,total_cost:0,currency:'MMK',items:[{name:'Free inspection',line_cost:0}]}});
      expect(free.statusCode,free.body).toBe(201);
      expect((await state.app.inject({url:'/v1/me/currency',headers:user.headers})).json().locked).toBe(false);
    } finally {await state.app.close();await state.client.close();}
  });
  it('validates a vehicle purchase in its original currency',async()=>{
    const state=await createTestApp();try {
      await activate(state);const owner=await account(state,'USD');const id=await car(state,owner);
      const purchase=await state.app.inject({method:'PATCH',url:`/v1/vehicles/${id}`,headers:owner.headers,payload:{purchase_price:123.45,purchase_currency:'USD'}});
      expect(purchase.statusCode,purchase.body).toBe(200);expect(purchase.json().purchase_currency).toBe('USD');
      expect((await state.app.inject({url:'/v1/me/currency',headers:owner.headers})).json().locked).toBe(false);
      const relabel=await state.app.inject({method:'PATCH',url:`/v1/vehicles/${id}`,headers:owner.headers,payload:{purchase_price:123.45,purchase_currency:'THB'}});
      expect(relabel.statusCode,relabel.body).toBe(200);
    } finally {await state.app.close();await state.client.close();}
  });
  it('requires fleet setup and permits only the Fleet Admin to select it',async()=>{
    const state=await createTestApp();try {
      await activate(state);const admin=await account(state,'USD');const driver=await account(state);const vehicleId=await car(state,admin);const orgId=uuid();
      await state.db.insert(organizations).values({id:orgId,name:'Fleet',type:'commercial',status:'active',billingMigrated:false,adminUserId:admin.id,createdBy:admin.id});
      await state.db.insert(organizationMembers).values([{id:uuid(),orgId,userId:admin.id,role:'org_admin'},{id:uuid(),orgId,userId:driver.id,role:'org_driver'}]);
      await state.db.insert(organizationVehicles).values({id:uuid(),orgId,vehicleId,lifecycleTemplate:'commercial',status:'available',addedBy:admin.id});
      const token=await signAccess(testEnv,{sub:admin.id,role:'owner',plan:'free',aud:testEnv.JWT_FLEET_AUD});const headers={authorization:`Bearer ${token.token}`};
      const create=()=>state.app.inject({method:'POST',url:`/v1/organizations/${orgId}/records/vehicles/${vehicleId}/expenses`,headers,payload:expense('CNY')});
      const missing=await create();expect(missing.json().error.code,missing.body).toBe('currency_required');
      const denied=await state.app.inject({method:'PUT',url:`/v1/organizations/${orgId}/currency`,headers:driver.headers,payload:{currency:'CNY',expected_currency:null}});expect(denied.statusCode).toBe(403);
      const setup=await state.app.inject({method:'PUT',url:`/v1/organizations/${orgId}/currency`,headers,payload:{currency:'CNY',expected_currency:null}});expect(setup.statusCode,setup.body).toBe(200);
      const saved=await create();expect(saved.statusCode,saved.body).toBe(201);
      expect((await state.app.inject({url:`/v1/organizations/${orgId}/currency`,headers})).json()).toMatchObject({currency:'CNY',locked:false});
      expect((await state.app.inject({url:'/v1/me/currency',headers:admin.headers})).json()).toMatchObject({currency:'USD',locked:false});
      const servicePayload={serviced_on:'2026-10-29',odometer:0,total_cost:10.25,currency:'CNY',items:[{name:'Service',line_cost:10.25}]};
      const service=await state.app.inject({method:'POST',url:`/v1/organizations/${orgId}/vehicles/${vehicleId}/service-records`,headers,payload:servicePayload});
      expect(service.statusCode,service.body).toBe(201);
      const precise=await state.app.inject({method:'POST',url:`/v1/organizations/${orgId}/vehicles/${vehicleId}/service-records`,headers,payload:{...servicePayload,total_cost:10.255}});
      expect(precise.json().error.code).toBe('invalid_money_precision');
      await state.db.insert(driverAssignments).values({id:uuid(),orgId,vehicleId,driverId:driver.id,assignedBy:admin.id});
      const operations=['MMK','CNY'].map(currency=>({operation_id:uuid(),entity_id:uuid(),entity_type:'expense',vehicle_id:vehicleId,op:'upsert',expected_revision:null,payload:expense(currency),client_ts:new Date().toISOString()}));
      const sync=await state.app.inject({method:'POST',url:`/v1/organizations/${orgId}/sync/push`,headers:driver.headers,payload:{operations}});
      expect(sync.statusCode,sync.body).toBe(200);
      expect(sync.json().results[0].error.error.code).toBe('currency_mismatch');expect(sync.json().results[1].status).toBe('applied');
      const policyUrl=`/v1/organizations/${orgId}/vehicles/${vehicleId}/currency`;
      const policy={base_currency:'EUR',allow_member_currency:true};
      expect((await state.app.inject({method:'PUT',url:policyUrl,headers:driver.headers,payload:policy})).statusCode).toBe(403);
      expect((await state.app.inject({method:'PUT',url:policyUrl,headers,payload:policy})).statusCode).toBe(200);
      expect((await state.app.inject({url:policyUrl,headers:driver.headers})).json().currency).toBe('EUR');
      expect((await state.app.inject({method:'PUT',url:policyUrl+'/member',headers:driver.headers,payload:{currency:'GBP'}})).statusCode).toBe(200);
      expect((await state.app.inject({url:policyUrl,headers:driver.headers})).json().currency).toBe('GBP');
      expect((await state.app.inject({url:policyUrl,headers})).json().currency).toBe('EUR');
      const workOrderId=uuid();
      await state.db.insert(workOrders).values({id:workOrderId,orgId,vehicleId,reportedBy:driver.id,odometerKm:0,issueType:'breakdown',description:'Inspection needed',urgency:'medium',status:'in_progress'});
      const completed=await state.app.inject({method:'PATCH',url:`/v1/organizations/${orgId}/work-orders/${workOrderId}`,headers,payload:{status:'completed',completion_cost:12.50,currency:'CNY'}});
      expect(completed.statusCode,completed.body).toBe(200);expect(completed.json().currency).toBe('CNY');expect(completed.json().service_record.currency).toBe('CNY');
      expect((await state.db.select().from(expenses)).every(e=>e.currency==='CNY')).toBe(true);

    }finally {await state.app.close();await state.client.close();}
  });
});
