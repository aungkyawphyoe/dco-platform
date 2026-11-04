import { getAccessibleVehicle } from './vehicles.js';
import { recordChange } from '../lib/dbx.js';
import { publicUser } from '../lib/serialize.js';
import { fanOutVehicleChange } from './vehicle-shares.js';
import { loadService, publicExpense, publicFuelLog } from '../lib/serialize-records.js';
import { eq, sql, and, ne, isNull } from 'drizzle-orm';
import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { users, organizations, vehicles, organizationMembers, driverAssignments, organizationVehicles, fuelLogs, serviceRecords, expenses } from '../db/schema.js';
import { AppError } from '../lib/errors.js';
import { operationalCurrency } from '../lib/operational-money.js';
import { assertPersonalGarageAllowed } from '../lib/personal-garage.js';
import { requireOwner, requireFleetClient, requireFleetPortal } from './auth.js';
import { assertPasswordChangeClear, getOrganizationAccess } from './fleet.js';

const update = z.object({ currency: operationalCurrency, expected_currency: operationalCurrency.nullable(), relabel_history: z.boolean().default(false) });
export const currencyPlugin: FastifyPluginAsync = async app => {
  async function state(kind: 'personal' | 'organization', id: string) {
    const table = kind === 'personal' ? users : organizations;
    const [row] = await app.db.select().from(table).where(eq(table.id,id));
    if (!row) throw new AppError(404,'not_found','Currency scope not found');
    return { currency: row.currency, locked: false, locked_at: null,
      review_required: false, enabled: true, default_currency: 'MMK', supported: operationalCurrency.options };
  }
  async function change(kind: 'personal' | 'organization', id: string, raw: unknown) {
    const body = update.parse(raw);
    const table = kind === 'personal' ? users : organizations;
    await app.db.transaction(async tx => {
      const [row] = await tx.select().from(table).where(eq(table.id,id)).for('update');
      if (!row) throw new AppError(404,'not_found','Currency scope not found');
      if (row.currency !== body.expected_currency) throw new AppError(409,'currency_mismatch','Currency changed; refresh before trying again');
      await tx.update(table).set({ currency: body.currency }).where(eq(table.id,id));
      if (body.relabel_history) {
        const scope = kind === 'personal'
          ? and(eq(vehicles.userId,id), isNull(organizationVehicles.orgId))
          : eq(organizationVehicles.orgId,id);
        const cars = await tx.select({ id: vehicles.id }).from(vehicles)
          .leftJoin(organizationVehicles,eq(organizationVehicles.vehicleId,vehicles.id))
          .where(scope).orderBy(vehicles.id).for('update', { of: vehicles });
        for (const car of cars) {
          const filters = (table: typeof fuelLogs | typeof serviceRecords | typeof expenses) =>
            and(eq(table.vehicleId,car.id), ne(table.currency,body.currency));
          const fuel = await tx.update(fuelLogs).set({ currency: body.currency }).where(filters(fuelLogs)).returning();
          const services = await tx.update(serviceRecords).set({ currency: body.currency }).where(filters(serviceRecords)).returning();
          const costs = await tx.update(expenses).set({ currency: body.currency }).where(filters(expenses)).returning();
          if (kind === 'personal') {
            for (const row of fuel) await fanOutVehicleChange(tx,{ vehicleId:car.id, entityType:'fuel_log',entityId:row.id,op:'upsert',payload:publicFuelLog(row) });
            for (const row of services) await fanOutVehicleChange(tx,{ vehicleId:car.id, entityType:'service_record',entityId:row.id,op:'upsert',payload:await loadService(tx,row.id) });
            for (const row of costs) await fanOutVehicleChange(tx,{ vehicleId:car.id, entityType:'expense',entityId:row.id,op:'upsert',payload:await publicExpense(tx,row.id) });
          }
        }
      }
      if (kind === 'personal') {
        const [user] = await tx.select().from(users).where(eq(users.id,id));
        await recordChange(tx,{userId:id,entityType:'user',entityId:id,op:'upsert',payload:publicUser(user)});
      }
    });
    return state(kind,id);
  }
  app.get('/vehicles/:vehicleId/currency',async request => {
    requireOwner(request);
    await assertPersonalGarageAllowed(app.db,request.authUser!.sub);
    const id=z.string().uuid().parse((request.params as {vehicleId:string}).vehicleId);
    const vehicle=await getAccessibleVehicle(app.db,request.authUser!.sub,id,'drive_only',true);
    const account = await state('personal',vehicle.allowMemberCurrency ? request.authUser!.sub : vehicle.userId);
    return {...account, currency: vehicle.allowMemberCurrency ? account.currency : vehicle.baseCurrency ?? account.currency,
      base_currency: vehicle.baseCurrency, allow_member_currency: vehicle.allowMemberCurrency, can_manage: vehicle.userId === request.authUser!.sub};
  });
  const policy = z.object({base_currency: operationalCurrency.nullable(), allow_member_currency: z.boolean()});
  app.put('/vehicles/:vehicleId/currency', async request => {
    requireOwner(request);
    const uid = request.authUser!.sub;
    await assertPersonalGarageAllowed(app.db,uid);
    const id = z.string().uuid().parse((request.params as {vehicleId:string}).vehicleId);
    const body = policy.parse(request.body);
    await app.db.transaction(async tx => {
      await tx.select().from(vehicles).where(eq(vehicles.id,id)).for('update');
      const vehicle = await getAccessibleVehicle(tx,uid,id,'drive_only',true);
      if (vehicle.userId !== uid) throw new AppError(403,'forbidden','Only the vehicle owner can set currency policy');
      await tx.update(vehicles).set({baseCurrency:body.base_currency,allowMemberCurrency:body.allow_member_currency}).where(eq(vehicles.id,id));
    });
    return body;
  });
  const fleetPath = '/organizations/:id/vehicles/:vehicleId/currency';
  async function fleetVehicle(request: import('fastify').FastifyRequest) {
    requireFleetClient(request);
    const {id,vehicleId} = z.object({id:z.string().uuid(),vehicleId:z.string().uuid()}).parse(request.params);
    const uid=request.authUser!.sub;
    await assertPasswordChangeClear(app.db,uid);
    const {membership}=await getOrganizationAccess(app.db,uid,id);
    const [vehicle]=await app.db.select({base:vehicles.baseCurrency,overrides:vehicles.allowMemberCurrency})
      .from(vehicles).innerJoin(organizationVehicles,eq(organizationVehicles.vehicleId,vehicles.id))
      .where(and(eq(vehicles.id,vehicleId),eq(organizationVehicles.orgId,id)));
    if (!vehicle) throw new AppError(404,'not_found','Fleet vehicle not found');
    if (membership.role === 'org_driver') {
      const [assignment]=await app.db.select({id:driverAssignments.id}).from(driverAssignments)
        .where(and(eq(driverAssignments.orgId,id),eq(driverAssignments.vehicleId,vehicleId),eq(driverAssignments.driverId,uid),eq(driverAssignments.status,'active')));
      if (!assignment) throw new AppError(403,'forbidden','Vehicle is not assigned to this driver');
    }
    return {id,vehicleId,vehicle,membership};
  }
  app.get(fleetPath,async request => {
    const {id,vehicle,membership}=await fleetVehicle(request);
    const fleet=await state('organization',id);
    return {...fleet, organization_id:id,base_currency:vehicle.base, allow_member_currency:vehicle.overrides,
      currency:(vehicle.overrides ? membership.displayCurrency : null) ?? vehicle.base ?? fleet.currency};
  });
  app.put(fleetPath,async request => {
    requireFleetPortal(request);
    const {id,vehicleId,membership}=await fleetVehicle(request);
    if (membership.role !== 'org_admin') throw new AppError(403,'forbidden','Fleet administrator required');
    const body=policy.parse(request.body);
    const changed=await app.db.update(vehicles).set({baseCurrency:body.base_currency,allowMemberCurrency:body.allow_member_currency})
      .where(and(eq(vehicles.id,vehicleId),sql`EXISTS (SELECT 1 FROM organization_vehicles WHERE vehicle_id=${vehicleId} AND org_id=${id})`)).returning({id:vehicles.id});
    if (!changed.length) throw new AppError(409,'vehicle_no_longer_in_org','Vehicle no longer belongs to the fleet');
    return body;
  });
  app.put(fleetPath+'/member',async request => {
    const {vehicle,membership}=await fleetVehicle(request);
    if (!vehicle.overrides) throw new AppError(403,'forbidden','Member currency is disabled on this vehicle');
    const {currency}=z.object({currency:operationalCurrency}).parse(request.body);
    await app.db.update(organizationMembers).set({displayCurrency:currency}).where(eq(organizationMembers.id,membership.id));
    return {currency};
  });
  app.get('/me/currency',async request => {
    requireOwner(request);
    await assertPersonalGarageAllowed(app.db,request.authUser!.sub);
    return state('personal',request.authUser!.sub);
  });
  app.put('/me/currency',async request => {
    requireOwner(request);
    await assertPersonalGarageAllowed(app.db,request.authUser!.sub);
    return change('personal',request.authUser!.sub,request.body);
  });
  app.get('/organizations/:id/currency',async request => {
    requireFleetClient(request);
    const id=z.string().uuid().parse((request.params as {id:string}).id);
    await assertPasswordChangeClear(app.db,request.authUser!.sub);
    await getOrganizationAccess(app.db,request.authUser!.sub,id,['org_admin','org_manager','org_mechanic','org_driver']);
    return state('organization',id);
  });
  app.put('/organizations/:id/currency',async request => {
    requireFleetPortal(request);
    const id=z.string().uuid().parse((request.params as {id:string}).id);
    await assertPasswordChangeClear(app.db,request.authUser!.sub);
    await getOrganizationAccess(app.db,request.authUser!.sub,id,['org_admin']);
    return change('organization',id,request.body);
  });
};
