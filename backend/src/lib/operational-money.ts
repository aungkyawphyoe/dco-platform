import { z } from 'zod';
import { AppError } from './errors.js';

/** Operational vehicle costs only; subscription/payment currencies are separate. */
export const operationalCurrency = z.enum(['MMK', 'USD', 'THB', 'CNY']);
export type OperationalCurrency = z.infer<typeof operationalCurrency>;
export const defaultCurrency: OperationalCurrency = 'MMK';
export const currencyScale = (currency: OperationalCurrency) => currency === 'MMK' ? 0 : 2;

function decimal(value: string | number): { coefficient: bigint; scale: number } {
  const text = String(value);
  if (text.length > 40 || !/^\d+(?:\.\d+)?$/.test(text)) {
    throw new AppError(422, 'invalid_amount', 'Enter a nonnegative decimal amount');
  }
  const [whole, fraction = ''] = text.split('.');
  return { coefficient: BigInt(whole + fraction), scale: fraction.length };
}

function atScale(value: { coefficient: bigint; scale: number }, scale: number, round: boolean): bigint {
  if (value.scale <= scale) return value.coefficient * 10n ** BigInt(scale - value.scale);
  const divisor = 10n ** BigInt(value.scale - scale);
  const remainder = value.coefficient % divisor;
  if (!round && remainder !== 0n) {
    throw new AppError(422, 'invalid_money_precision', `Use at most ${scale} decimal places`);
  }
  return value.coefficient / divisor + (round && remainder * 2n >= divisor ? 1n : 0n);
}

function formatted(units: bigint, scale: number): string {
  if (!scale) return String(units);
  const digits = String(units).padStart(scale + 1, '0');
  return `${digits.slice(0, -scale)}.${digits.slice(-scale)}`;
}

/** Exact final-cost validation. Trailing zeroes do not change precision. */
export function moneyAmount(value: string | number, currency: OperationalCurrency): string {
  const units = atScale(decimal(value), currencyScale(currency), false);
  const result = formatted(units, currencyScale(currency));
  // The existing operational amount columns are numeric(12,2).
  if (units > 9999999999n * 10n ** BigInt(currencyScale(currency)) + (currency === 'MMK' ? 0n : 99n)) {
    throw new AppError(422, 'amount_too_large', 'Amount exceeds the supported limit');
  }
  return result;
}

/** Quantity remains at three decimals, unit price may use six; round only once. */
export function fuelCost(quantity: string | number, unitPrice: string | number, currency: OperationalCurrency): string {
  const quantityUnits = atScale(decimal(quantity), 3, false);
  if (quantityUnits === 0n) throw new AppError(422, 'invalid_quantity', 'Quantity must be positive');
  const priceUnits = atScale(decimal(unitPrice), 6, false);
  const units = atScale({ coefficient: quantityUnits * priceUnits, scale: 9 }, currencyScale(currency), true);
  return moneyAmount(formatted(units, currencyScale(currency)), currency);
}

/** Return included totals without ever adding foreign-currency amounts. */
export function currencyTotal(records: ReadonlyArray<{ amount: string; currency: string }>, currency: OperationalCurrency) {
  const excluded = new Map<string, number>();
  // Preserve legacy fractional MMK amounts in storage/aggregation.
  let cents = 0n;
  for (const record of records) {
    if (record.currency !== currency) {
      excluded.set(record.currency, (excluded.get(record.currency) ?? 0) + 1);
    } else {
      cents += atScale(decimal(record.amount), 2, false);
    }
  }
  return {
    amount: formatted(cents, 2), currency,
    excluded: [...excluded].sort(([a], [b]) => a.localeCompare(b)).map(([code, count]) => ({ currency: code, count })),
  };
}
