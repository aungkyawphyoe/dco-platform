import { sql, and, eq } from 'drizzle-orm';
import { users, organizations, vehicles, organizationVehicles } from '../db/schema.js';
import type { Db } from '../db/client.js';
import { AppError } from './errors.js';
import { moneyAmount, operationalCurrency, type OperationalCurrency } from './operational-money.js';

export async function currencyEnabled(db: Db): Promise<boolean> {
  const result = await db.execute(sql`SELECT enabled FROM operational_currency_control WHERE singleton`);
  return result.rows[0]?.enabled === true;
}

/** Validate raw amounts before PostgreSQL numeric(12,2) can round them. */
export async function incomingCurrency(db: Db, body: unknown, amounts: unknown[], existing?: { currency: string; amounts?: unknown[] }): Promise<OperationalCurrency> {
  const raw = body as Record<string, unknown> | undefined;
  const supplied = raw?.currency ?? raw?.purchase_currency;
  const active = await currencyEnabled(db);
  if (supplied === undefined && active) throw new AppError(428, 'currency_required', 'Send the intended currency with this monetary entry');
  const currency = operationalCurrency.parse(supplied ?? existing?.currency ?? 'MMK');
  if (existing && currency !== existing.currency) throw new AppError(409, 'currency_immutable', 'Historical record currency cannot change');
  if (!active && currency !== 'MMK') throw new AppError(409, 'currency_not_enabled', 'Currency selection is not available yet');
  if (active) amounts.forEach((amount, index) => {
    if (amount == null) return;
    // Preserve exact legacy values when an edit sends the unchanged amount.
    if (existing?.amounts?.[index] != null && String(amount).replace(/\.0+$|(?<=\.[0-9]*[1-9])0+$/g, '') === String(existing.amounts[index]).replace(/\.0+$|(?<=\.[0-9]*[1-9])0+$/g, '')) return;
    moneyAmount(amount as string | number, currency);
  });
  return currency;
}

export function currencyDatabaseError(error: unknown): AppError | null {
  let cause: unknown = error;
  const codes: Record<string, number> = { currency_locked: 409, currency_immutable: 409,
    currency_mismatch: 409, currency_required: 409, invalid_money_precision: 422,
    currency_migration_review_required: 409, currency_activation_locked: 409 };
  for (let depth=0; cause && depth<5; depth++) {
    const value = cause as { code?: string; message?: string; detail?: string; cause?: unknown };
    // Only recognize our explicit PostgreSQL RAISE errors, not SQL text embedded
    // in a query wrapper or arbitrary user-provided strings.
    if (value.code === 'P0001' && typeof value.message === 'string') {
      const code = value.message.split(':',1)[0];
      if (codes[code]) {
        let details: Record<string,unknown> = {};
        if (code === 'currency_mismatch' && value.detail) {
          try { const parsed = JSON.parse(value.detail); if (operationalCurrency.safeParse(parsed.current_currency).success) details = {current_currency:parsed.current_currency}; } catch { /* PostgreSQL detail is optional. */ }
        }
        return new AppError(codes[code], code, value.message.slice(code.length+1).trim(), details);
      }
    }
    cause = value.cause;
  }
  return null;
}

export async function signupCurrency(db: Db, body: unknown) {
  return incomingCurrency(db,{currency:(body as {currency?:unknown})?.currency ?? 'MMK'},[]);
}

export async function incomingServiceCurrency(db: Db, body: unknown) {
  const value = body as {total_cost?:number;completion_cost?:number;items?:{line_cost?:number}[]};
  return incomingCurrency(db,body,[value.total_cost ?? value.completion_cost,...(value.items ?? []).map(item=>item.line_cost)]);
}


/** Serialize fleet cost creation with ownership transfer before validating scope. */
export async function lockCurrencyVehicle(db: Db, vehicleId: string, organizationId: string) {
  await db.select({id:vehicles.id}).from(vehicles).where(eq(vehicles.id,vehicleId)).for('update');
  const [link]=await db.select({id:organizationVehicles.id}).from(organizationVehicles).where(and(eq(organizationVehicles.vehicleId,vehicleId),eq(organizationVehicles.orgId,organizationId)));
  if (!link) throw new AppError(409,'vehicle_no_longer_in_org','Vehicle no longer belongs to this organization');
}


export async function effectiveVehicleCurrency(db: Db, vehicleId: string): Promise<string | null> {
  const [row] = await db.select({ownerCurrency:users.currency, orgId:organizationVehicles.orgId, orgCurrency:organizations.currency})
    .from(vehicles).innerJoin(users,eq(users.id,vehicles.userId))
    .leftJoin(organizationVehicles,eq(organizationVehicles.vehicleId,vehicles.id))
    .leftJoin(organizations,eq(organizations.id,organizationVehicles.orgId))
    .where(eq(vehicles.id,vehicleId));
  if (!row) throw new AppError(404,'not_found','Vehicle not found');
  return row.orgId ? row.orgCurrency : row.ownerCurrency;
}
