import { readFileSync } from "node:fs";
import { storeWithQuota } from "../src/lib/storage.js";
import { buildApp } from "../src/app.js";
import { createMailer } from "../src/lib/mail.js";
import { describe, expect, it } from "vitest";
import { createTestApp, testEnv, uuid } from "./helpers.js";
import { signAccess } from "../src/lib/crypto.js";
import { expiryStatus } from "../src/lib/driver-credentials.js";

async function signup(app: { inject: Function }, label: string) {
  const email = `${label}-${uuid()}@test.local`;
  const response = await app.inject({
    method: "POST",
    url: "/v1/auth/signup",
    payload: { email, password: "password1", display_name: label },
  }) as { statusCode: number; json: () => { access_token: string; user: { id: string } } };
  expect(response.statusCode).toBe(201);
  return { email, id: response.json().user.id, token: response.json().access_token };
}

async function adminToken(app: { inject: Function }) {
  const response = await app.inject({
    method: "POST",
    url: "/v1/auth/login",
    payload: { email: testEnv.BOOTSTRAP_ADMIN_EMAIL, password: testEnv.BOOTSTRAP_ADMIN_PASSWORD },
  }) as { statusCode: number; json: () => { access_token: string } };
  expect(response.statusCode).toBe(200);
  return response.json().access_token;
}

const auth = (token: string) => ({ authorization: `Bearer ${token}` });

async function createVehicle(app: { inject: Function }, token: string, label: string) {
  const vehicleId = uuid();
  const vehicle = await app.inject({
    method: "POST",
    url: "/v1/vehicles",
    headers: auth(token),
    payload: {
      id: vehicleId, name: `${label} Car`, make: "Toyota", model: "Corolla", year: 2021,
      license_plate: `${label.slice(0, 3).toUpperCase()}${vehicleId.slice(0, 4)}`,
      vin: vehicleId.replaceAll("-", "").slice(0, 17),
      fuel_type: "petrol", mileage: 5000,
    },
  });
  expect(vehicle.statusCode).toBe(201);
  return vehicleId;
}

describe("driving licenses (standalone module)", () => {
  it("creates, reads, and updates the caller's license", async () => {
    const { app, db } = await createTestApp();
    const owner = await signup(app, "lic-owner");

    const missing = await app.inject({ method: "GET", url: "/v1/users/me/license", headers: auth(owner.token) });
    expect(missing.statusCode).toBe(404);

    expect((await app.inject({method:'POST',url:'/v1/users/me/license/media',headers:auth(owner.token)})).statusCode).toBe(404);
    const created = await app.inject({
      method: "PUT",
      url: "/v1/users/me/license",
      headers: auth(owner.token),
      payload: {
        license_number: "AB123456",
        license_expiry_date: "2030-05-20",
      },
    });
    expect(created.statusCode).toBe(200);
    const licenseId = created.json().id as string;

    const read = await app.inject({ method: "GET", url: "/v1/users/me/license", headers: auth(owner.token) });
    expect(read.statusCode).toBe(200);
    expect(read.json().license_number).toBe("AB123456");
    expect(read.json().license_expiry_date).toBe("2030-05-20");

    const updated = await app.inject({
      method: "PUT",
      url: "/v1/users/me/license",
      headers: auth(owner.token),
      payload: { license_number: "XY987654", license_expiry_date: "2031-01-01" },
    });
    expect(updated.statusCode).toBe(200);
    expect(updated.json().id).toBe(licenseId);
    expect(updated.json().license_number).toBe("XY987654");

    const noExpiry = await app.inject({ method: "PUT", url: "/v1/users/me/license", headers: auth(owner.token), payload: { license_expiry_date: null } });
    expect(noExpiry.statusCode).toBe(200);
    expect(noExpiry.json().license_expiry_date).toBeNull();
    const impossibleDate = await app.inject({ method: "PUT", url: "/v1/users/me/license", headers: auth(owner.token), payload: { license_expiry_date: "2030-02-30" } });
    expect(impossibleDate.statusCode).toBe(422);

    const expired = await app.inject({
      method: "PUT",
      url: "/v1/users/me/license",
      headers: auth(owner.token),
      payload: { license_expiry_date: "2020-01-01" },
    });
    expect(expired.statusCode).toBe(200);
    expect(expiryStatus(expired.json().license_expiry_date)).toBe('expired');
    const invalid=await app.inject({method:'PUT',url:'/v1/users/me/license',headers:auth(owner.token),payload:{license_number:'bad-number'}});
    expect(invalid.statusCode).toBe(422);
    expect((await app.inject({method:'PATCH',url:'/v1/users/me/profile',headers:auth(owner.token),payload:{license_number:'XY123',license_expiry_date:'2030-01-02'}})).statusCode).toBe(200);
    expect((await app.inject({method:'GET',url:'/v1/users/me/license',headers:auth(owner.token)})).json()).toMatchObject({license_number:'XY123',license_expiry_date:'2030-01-02'});
    expect((await app.inject({ method: "DELETE", url: "/v1/users/me/license", headers: auth(owner.token) })).statusCode).toBe(204);
    expect((await app.inject({ method: "GET", url: "/v1/users/me/license", headers: auth(owner.token) })).statusCode).toBe(404);
  });

  it("retires both linked and orphaned photos while retaining credentials and unrelated media", async()=>{
    const {app,db,client}=await createTestApp();
    const owner=await signup(app,"legacy-driver");
    const store=app.media;
    await client.exec("ALTER TABLE media_objects DROP CONSTRAINT no_license_image_uploads");
    const add=(purpose:string)=>storeWithQuota(db,store,{id:uuid(),owner:{userId:owner.id},purpose,bytes:Buffer.from([1]),contentType:"image/jpeg"});
    const linked=await add("license_front"), orphan=await add("driving_license"), avatar=await add("profile_photo");
    await client.exec("ALTER TABLE driving_licenses RENAME COLUMN license_expiry_date TO expiry_date; ALTER TABLE driving_licenses ADD COLUMN front_media_id uuid, ADD COLUMN back_media_id uuid, ADD COLUMN issuing_country text, ADD COLUMN categories text;");
    await client.query("INSERT INTO driving_licenses(id,user_id,license_number,expiry_date,front_media_id) VALUES($1,$2,'AB123','2030-01-02',$3)",[uuid(),owner.id,linked.id]);
    const migration=readFileSync(new URL("../drizzle/0035_retire_license_images.sql",import.meta.url),"utf8");
    await client.exec(migration);await client.exec(migration);
    expect((await client.query("SELECT license_number,license_expiry_date::text FROM driving_licenses")).rows).toEqual([{license_number:"AB123",license_expiry_date:"2030-01-02"}]);
    const token=store.signDownload(linked.id).token;
    expect((await app.inject({url:`/v1/media/${linked.id}/content?token=${token}`})).statusCode).toBe(404);
    await app.close();
    const restarted=await buildApp({env:testEnv,db,media:store,mailer:createMailer(testEnv)});
    try {
      await restarted.ready();
      for(const photo of [linked,orphan]) await expect(store.get(photo.blobKey)).rejects.toThrow();
      expect(await store.get(avatar.blobKey)).toEqual(Buffer.from([1]));
      expect((await client.query("SELECT media_id FROM media_cleanup")).rows).toEqual([]);
    } finally {await restarted.close();await client.close();}
  });
  it("requires both credentials for fleet drivers and marks the 30-day boundary", async()=>{
    const {app,client}=await createTestApp();
    try {
      const driver=await signup(app,"fleet-driver");
      const org=uuid();
      await client.query("INSERT INTO organizations(id,name,type,admin_user_id,created_by) VALUES($1,'Fleet','commercial',$2,$2)",[org,driver.id]);
      await client.query("INSERT INTO organization_members(id,org_id,user_id,role) VALUES($1,$2,$3,'org_driver')",[uuid(),org,driver.id]);
      const put=(payload:object)=>app.inject({method:"PUT",url:"/v1/users/me/license",headers:auth(driver.token),payload});
      expect((await put({license_number:"ABC123"})).statusCode).toBe(422);
      expect((await put({license_number:"ABC123",license_expiry_date:"2030-01-01"})).statusCode).toBe(200);
      expect((await put({license_expiry_date:null})).statusCode).toBe(422);
      expect((await app.inject({method:"DELETE",url:"/v1/users/me/license",headers:auth(driver.token)})).statusCode).toBe(422);
      const manager=await signup(app,"fleet-manager");
      await client.query("INSERT INTO organization_members(id,org_id,user_id,role) VALUES($1,$2,$3,'org_manager')",[uuid(),org,manager.id]);
      await client.query("UPDATE organizations SET billing_migrated=false,status='active' WHERE id=$1",[org]);
      const fleetToken=await signAccess(testEnv,{sub:manager.id,role:'owner',plan:'free',aud:testEnv.JWT_FLEET_AUD});
      const managerHeaders=auth(fleetToken.token);
      const path=`/v1/organizations/${org}/members/${driver.id}/license`;
      const saved=await app.inject({method:'PUT',url:path,headers:managerHeaders,payload:{license_expiry_date:'2020-01-01'}});
      expect(saved.statusCode,saved.body).toBe(200);
      expect(saved.json()).toEqual({license_expiry_date:'2020-01-01',license_status:'expired'});
      const members=await app.inject({url:`/v1/organizations/${org}/members`,headers:managerHeaders});
      expect(members.json().items.find((m:{user_id:string})=>m.user_id===driver.id)).toMatchObject({license_expiry_date:'2020-01-01',license_status:'expired'});
      expect(members.body).not.toContain('ABC123');
      expect((await app.inject({method:'PUT',url:path,headers:auth(driver.token),payload:{license_expiry_date:'2030-01-01'}})).statusCode).toBe(403);
      for(const [days,status] of [[-1,"expired"],[0,"expiring_soon"],[30,"expiring_soon"],[31,"valid"]] as const){
        expect(expiryStatus(new Date(Date.now()+days*86400000).toISOString().slice(0,10))).toBe(status);
      }
    } finally {await app.close();await client.close();}
  });

  it("keeps licenses private even with an active vehicle share", async () => {
    const { app, db } = await createTestApp();
    const admin = await adminToken(app);
    const owner = await signup(app, "lic-share-owner");
    const member = await signup(app, "lic-share-member");
    const stranger = await signup(app, "lic-share-stranger");

    await app.inject({
      method: "PATCH",
      url: `/v1/admin/users/${owner.id}`,
      headers: auth(admin),
      payload: { plan: "standard" },
    });

    const vehicleId = await createVehicle(app, owner.token, "LIC");

    await app.inject({
      method: "PUT",
      url: "/v1/users/me/license",
      headers: auth(owner.token),
      payload: { license_number: "SH123456", license_expiry_date: "2032-09-09" },
    });

    const strangerRead = await app.inject({
      method: "GET",
      url: `/v1/users/${owner.id}/license`,
      headers: auth(stranger.token),
    });
    expect(strangerRead.statusCode).toBe(403);

    const share = await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/shares`,
      headers: auth(owner.token),
      payload: { method: "email", email: member.email, access_level: "view" },
    });
    expect(share.statusCode).toBe(201);
    const inviteToken = share.json().invite_token as string;

    const accept = await app.inject({
      method: "POST",
      url: "/v1/vehicles/shares/accept",
      headers: auth(member.token),
      payload: { token: inviteToken },
    });
    expect(accept.statusCode).toBe(200);

    const memberRead = await app.inject({
      method: "GET",
      url: `/v1/users/${owner.id}/license`,
      headers: auth(member.token),
    });
    expect(memberRead.statusCode).toBe(403);
    expect(memberRead.json().error.code).toBe("private_document");
    const detail = await app.inject({ method: "GET", url: `/v1/users/${owner.id}/detail`, headers: auth(member.token) });
    expect(detail.statusCode).toBe(200);
    expect(detail.json().driving_license).toBeNull();

    const selfRead = await app.inject({
      method: "GET",
      url: `/v1/users/${owner.id}/license`,
      headers: auth(owner.token),
    });
    expect(selfRead.statusCode).toBe(200);
  });
});
