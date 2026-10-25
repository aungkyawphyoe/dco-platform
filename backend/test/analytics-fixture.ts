import { createTestApp, testEnv, uuid } from './helpers.js';
import { signAccess } from '../src/lib/crypto.js';
import { users, organizations, organizationMembers, vehicles, organizationVehicles, expenses, fuelTypes, fuelLogs } from '../src/db/schema.js';
export async function analyticsFixture() {
  const state = await createTestApp(), { db } = state;
  const userId = uuid(), orgId = uuid(), vehicleId = uuid(), typeId = uuid();
  await db.insert(users).values({ id: userId, email: 'analytics-preview@test.local', username: 'analytics_preview', displayName: 'Fleet manager', passwordHash: null, role: 'owner', plan: 'fleet' });
  await db.insert(organizations).values({ id: orgId, billingMigrated: false, name: 'Northside Fleet', type: 'commercial', status: 'active', adminUserId: userId, createdBy: userId });
  await db.insert(organizationMembers).values({id:uuid(),orgId,userId,role:'org_admin'});
  await db.insert(vehicles).values({id:vehicleId,userId,name:'Toyota Probox',make:'Toyota',model:'Probox',year:2022,licensePlate:'YGN 6S-2841',fuelType:'petrol',mileage:'12000',mileageUnit:'km'});
  await db.insert(organizationVehicles).values({id:uuid(),orgId,vehicleId,lifecycleTemplate:'commercial',status:'available',addedBy:userId,addedAt:new Date('2025-01-01')});
  await db.insert(fuelTypes).values({id:typeId,userId,name:'Diesel',kind:'liquid',unit:'L'});
  for (let month=1;month<=9;month++) {
    const m=String(month).padStart(2,'0');
    await db.insert(fuelLogs).values({id:uuid(),userId,vehicleId,kind:'refuel',fuelTypeId:typeId,fuelTypeName:'Diesel',unit:'L',fillStatus:'full',loggedOn:`2026-${m}-01`,amount:'35',cost:String(80000+month*1000),odometer:String(month*1000)});
    await db.insert(fuelLogs).values({id:uuid(),userId,vehicleId,kind:'refuel',fuelTypeId:typeId,fuelTypeName:'Diesel',unit:'L',fillStatus:'full',loggedOn:`2026-${m}-20`,amount:'30',cost:String(70000+month*1000),odometer:String(month*1000+500)});
    await db.insert(expenses).values({id:uuid(),vehicleId,category:month%3===0?'maintenance':'parking',amount:String(month%3===0?150000:12000),incurredOn:`2026-${m}-15`,createdBy:userId,notes:month%3===0?'Scheduled service':'City parking'});
  }
  const { token } = await signAccess(testEnv,{sub:userId,role:'owner',plan:'fleet',aud:testEnv.JWT_FLEET_AUD});
  return { ...state,userId,orgId,vehicleId,typeId,headers:{authorization:`Bearer ${token}`} };
}
