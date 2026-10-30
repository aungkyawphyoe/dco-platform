import { getAccessibleVehicle } from './vehicles.js';
import { recordChange } from '../lib/dbx.js';
import { publicUser } from '../lib/serialize.js';
import { eq, sql } from 'drizzle-orm';
import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { users, organizations } from '../db/schema.js';
import { AppError } from '../lib/errors.js';
import { currencyEnabled } from '../lib/operational-currency.js';
import { operationalCurrency } from '../lib/operational-money.js';
import { assertPersonalGarageAllowed } from '../lib/personal-garage.js';
import { requireOwner, requireFleetClient, requireFleetPortal } from './auth.js';
import { assertPasswordChangeClear, getOrganizationAccess } from './fleet.js';

const update = z.object({ currency: operationalCurrency, expected_currency: operationalCurrency.nullable() });
export const currencyPlugin: FastifyPluginAsync = async app => {
  async function state(kind: 'personal' | 'organization', id: string) {
    const table = kind === 'personal' ? users : organizations;
    const [row] = await app.db.select().from(table).where(eq(table.id,id));
    if (!row) throw new AppError(404,'not_found','Currency scope not found');
    const review = await app.db.execute(sql`SELECT 1 FROM currency_migration_reviews WHERE scope_type=${kind} AND scope_id=${id} AND resolved_at IS NULL`);
    return { currency: row.currency, locked: row.currencyLockedAt !== null, locked_at: row.currencyLockedAt?.toISOString() ?? null,
      review_required: review.rows.length > 0, enabled: await currencyEnabled(app.db), default_currency: 'MMK', supported: operationalCurrency.options };
  }
  async function change(kind: 'personal' | 'organization', id: string, raw: unknown) {
    const body = update.parse(raw);
    if (!await currencyEnabled(app.db)) throw new AppError(409,'currency_not_enabled','Currency selection is not available yet');
    const table = kind === 'personal' ? users : organizations;
    await app.db.transaction(async tx => {
      const [row] = await tx.select().from(table).where(eq(table.id,id)).for('update');
      if (!row) throw new AppError(404,'not_found','Currency scope not found');
      if (row.currency !== body.expected_currency) throw new AppError(409,'currency_mismatch','Currency changed; refresh before trying again');
      if (row.currencyLockedAt && row.currency !== body.currency) throw new AppError(409,'currency_locked','Currency is locked by monetary history');
      const review = await tx.execute(sql`SELECT 1 FROM currency_migration_reviews WHERE scope_type=${kind} AND scope_id=${id} AND resolved_at IS NULL`);
      if (review.rows.length) throw new AppError(409,'currency_migration_review_required','Legacy history requires review');
      await tx.update(table).set({ currency: body.currency }).where(eq(table.id,id));
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
    return state('personal',vehicle.userId);
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
