import { describe, expect, it } from 'vitest';
import { createTestApp, grantTestFleet, testEnv, uuid } from './helpers.js';
import { countActiveVehicles, assertVehicleLimit } from '../src/lib/limits.js';
import { scanReminderEmails } from '../src/lib/reminder-email.js';
import type { Mailer } from '../src/lib/mail.js';

const auth = (token: string) => ({ authorization: `Bearer ${token}` });
describe('ownership-period access', () => {
  it('hides showroom history, media and stale sync payloads from the buyer while retaining the showroom audit', async () => {
    const { app, client } = await createTestApp();
    const blobKey = `ownership-test/${uuid()}`;
    try {
      const accounts = [];
      for (const name of ['showroom','buyer']) {
        const email = `${name}-${uuid()}@test.local`;
        const res = await app.inject({method:'POST',url:'/v1/auth/signup',payload:{email,password:'password1'}});
        accounts.push({email,id:res.json().user.id,token:res.json().access_token});
      }
      const [seller,buyer] = accounts;
      const platform = await app.inject({method:'POST',url:'/v1/auth/login',payload:{email:testEnv.BOOTSTRAP_ADMIN_EMAIL,password:testEnv.BOOTSTRAP_ADMIN_PASSWORD}});
      const created = await app.inject({method:'POST',url:'/v1/admin/organizations',headers:auth(platform.json().access_token),payload:{name:'Privacy showroom',type:'showroom',admin_email:seller.email}});
      const org = created.json().id;
      await grantTestFleet(app,platform.json().access_token,org);
      await app.inject({method:'PATCH',url:`/v1/admin/organizations/${org}/status`,headers:auth(platform.json().access_token),payload:{status:'active'}});
      const login = await app.inject({method:'POST',url:'/v1/auth/login',payload:{email:seller.email,password:'password1',surface:'fleet'}});
      const fleet = auth(login.json().access_token);
      const vehicle = uuid(), service = uuid(), plan = uuid(), part = uuid(), doc = uuid(), media = uuid();
      const added = await app.inject({method:'POST',url:`/v1/organizations/${org}/vehicles`,headers:fleet,payload:{id:vehicle,name:'Private history car',make:'Honda',model:'Civic',year:2023,license_plate:uuid().slice(0,8),vin:uuid().replaceAll('-','').slice(0,17),fuel_type:'petrol',mileage:43000,lifecycle_template:'showroom'}});
      expect(added.statusCode).toBe(201);
      await app.media.put(blobKey,Buffer.from('%PDF-private'), 'application/pdf');
      await client.exec(`INSERT INTO plan_items(id,vehicle_id,name,next_due_mileage,baseline_due_mileage) VALUES('${plan}','${vehicle}','Oil',45000,45000);
        INSERT INTO service_records(id,vehicle_id,serviced_on,total_cost,notes) VALUES('${service}','${vehicle}','2026-01-01',100,'SHOWROOM PRIVATE');
        INSERT INTO parts(id,vehicle_id,name) VALUES('${part}','${vehicle}','Private part');
        INSERT INTO media_objects(id,user_id,owner_org_id,vehicle_id,purpose,blob_key,content_type,byte_size) VALUES('${media}','${seller.id}','${org}','${vehicle}','document','${blobKey}','application/pdf',12);
        INSERT INTO documents(id,vehicle_id,name,category,media_id) VALUES('${doc}','${vehicle}','Private invoice','invoice','${media}');`);
      for (const status of ['listed','reserved']) expect((await app.inject({method:'PATCH',url:`/v1/organizations/${org}/vehicles/${vehicle}`,headers:fleet,payload:{status}})).statusCode).toBe(200);
      const transferred = await app.inject({method:'POST',url:`/v1/organizations/${org}/vehicles/${vehicle}/transfer`,headers:fleet,payload:{buyer_email:buyer.email,sale_date:'2026-01-01',current_mileage_km:43000}});
      expect(transferred.statusCode).toBe(201);
      expect(await countActiveVehicles(app.db, buyer.id)).toBe(0);
      await expect(assertVehicleLimit(app.db, buyer.id, 'free')).resolves.toBeUndefined();
      const personalCar = uuid();
      await client.exec(`INSERT INTO vehicles(id,user_id,name,make,model,year,license_plate,fuel_type,mileage) VALUES('${personalCar}','${buyer.id}','Personal','Honda','Civic',2023,'${personalCar.slice(0,8)}','petrol',0)`);
      expect(await countActiveVehicles(app.db, buyer.id)).toBe(1);
      await expect(assertVehicleLimit(app.db, buyer.id, 'free')).rejects.toMatchObject({code:'LIMIT_EXCEEDED'});
      await client.exec(`UPDATE users SET email_verified=true, email_reminders_enabled=true WHERE id='${buyer.id}';
        UPDATE plan_items SET next_due_on='2026-01-01' WHERE id='${plan}';`);
      const recipients: string[] = [];
      const reminders = await scanReminderEmails({ db: app.db, now: new Date('2026-11-11'),
        mailer: { sendMaintenanceReminder: async (to: string) => { recipients.push(to); } } as unknown as Mailer });
      expect(reminders.sent).toBe(0);
      expect(recipients).toEqual([]);
      for (const resource of ['plan-items','service-records','expenses','parts','documents','fuel-logs']) {
        const response = await app.inject({method:'GET',url:`/v1/vehicles/${vehicle}/${resource}`,headers:auth(buyer.token)});
        expect(response.statusCode,resource).toBe(200);
        expect(response.json().items,resource).toEqual([]);
      }
      const oldExpense = (await client.query<{id:string}>(`SELECT id FROM expenses WHERE source_id='${service}'`)).rows[0].id;
      for (const [resource,id] of [['service-records',service],['expenses',oldExpense],['documents',doc],['parts',part],['plan-items',plan],['media',media]]) {
        const response = await app.inject({method:'GET',url:`/v1/${resource}/${id}`,headers:auth(buyer.token)});
        expect(response.statusCode,resource).toBe(404);
      }
      const signed = app.media.signDownload(media).token;
      expect((await app.inject({method:'GET',url:`/v1/media/${media}/content?token=${encodeURIComponent(signed)}`})).statusCode).toBe(404);
      const edit = await app.inject({method:'PATCH',url:`/v1/service-records/${service}`,headers:auth(buyer.token),payload:{notes:'Buyer overwrite'}});
      expect(edit.statusCode).toBe(404);
      const dashboard = await app.inject({method:'GET',url:`/v1/vehicles/${vehicle}/dashboard`,headers:auth(buyer.token)});
      expect(dashboard.json().ownership).toMatchObject({total_spent:0,services_count:0,documents_count:0});
      const audit = await app.inject({method:'GET',url:`/v1/organizations/${org}/transferred/${vehicle}/history`,headers:fleet});
      expect(audit.statusCode).toBe(200);
      expect(audit.json().service_records[0].notes).toBe('SHOWROOM PRIVATE');
      await client.exec(`INSERT INTO change_log(user_id,entity_type,entity_id,op,payload) VALUES('${buyer.id}','service_record','${service}','upsert','{"vehicle_id":"${vehicle}","notes":"SHOWROOM PRIVATE"}');
        INSERT INTO change_log(user_id,entity_type,entity_id,op,payload) VALUES('${buyer.id}','vehicle','${personalCar}','upsert','{"id":"${personalCar}"}');`);
      const sync = await app.inject({method:'GET',url:'/v1/sync/changes?cursor=',headers:auth(buyer.token)});
      expect(sync.statusCode).toBe(200);
      expect(sync.json().changes.find((row: {entity_type:string;entity_id:string}) => row.entity_type === 'vehicle' && row.entity_id === vehicle)?.payload.transfer_limit_exempt).toBe(true);
      expect(sync.json().changes.find((row: {entity_type:string;entity_id:string}) => row.entity_type === 'vehicle' && row.entity_id === personalCar)?.payload.transfer_limit_exempt).toBe(false);
      expect(sync.body).not.toContain('SHOWROOM PRIVATE');
      expect(sync.json().changes.find((row: {entity_id:string})=>row.entity_id===service)).toMatchObject({op:'delete'});
      const newService = await app.inject({method:'POST',url:`/v1/vehicles/${vehicle}/service-records`,headers:auth(buyer.token),payload:{id:uuid(),serviced_on:'2026-01-02',odometer:43000,total_cost:20,currency:'MMK',title:'Buyer service',items:[{name:'Oil',line_cost:20}]}});
      expect(newService.statusCode,newService.body).toBe(201);
      const after = await app.inject({method:'GET',url:`/v1/vehicles/${vehicle}/service-records`,headers:auth(buyer.token)});
      expect(after.json().items).toHaveLength(1);
      const historical = await app.inject({method:'GET',url:`/v1/organizations/${org}/transferred/${vehicle}/records`,headers:fleet});
      expect(historical.statusCode).toBe(200);
      expect(historical.json().service_records).toHaveLength(1);
      expect(historical.json().documents[0].id).toBe(doc);
      expect(historical.json().service_records[0].id).toBe(service);
      const receipt = await app.inject({method:'GET',url:`/v1/organizations/${org}/media/${media}/content`,headers:fleet});
      expect(receipt.statusCode).toBe(200);
      expect(receipt.body).toBe('%PDF-private');
      const forbiddenLink = await app.inject({method:'POST',url:`/v1/vehicles/${vehicle}/documents`,headers:auth(buyer.token),payload:{id:uuid(),name:'Copied invoice',category:'invoice',media_id:media}});
      expect(forbiddenLink.statusCode).toBe(422);
      expect((await client.query(`SELECT notes FROM service_records WHERE id='${service}'`)).rows).toEqual([{notes:'SHOWROOM PRIVATE'}]);
    } finally { await app.media.delete(blobKey); await app.close(); await client.close(); }
  });
});
