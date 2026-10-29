import { describe, expect, it } from 'vitest';
import { currencyTotal, defaultCurrency, fuelCost, moneyAmount, operationalCurrency } from '../src/lib/operational-money.js';

describe('operational money', () => {
  it('defaults to MMK and accepts only the four operational currencies', () => {
    expect(defaultCurrency).toBe('MMK');
    for (const currency of ['MMK', 'USD', 'THB', 'CNY']) expect(operationalCurrency.parse(currency)).toBe(currency);
    expect(operationalCurrency.safeParse('EUR').success).toBe(false);
  });
  it('validates final costs without floating point rounding or silent truncation', () => {
    expect(moneyAmount('50000.00', 'MMK')).toBe('50000');
    expect(moneyAmount('0.10', 'THB')).toBe('0.10');
    expect(moneyAmount(0, 'CNY')).toBe('0.00');
    expect(() => moneyAmount('50000.01', 'MMK')).toThrow('decimal places');
    expect(() => moneyAmount('0.001', 'USD')).toThrow('decimal places');
    for (const value of ['-1', 'NaN', 'Infinity', '1e10', '10000000000', '', ' 1']) {
      expect(() => moneyAmount(value, 'USD')).toThrow();
    }
  });
  it('retains unit-price precision and rounds half up only at the final amount', () => {
    expect(fuelCost('3', '0.335', 'USD')).toBe('1.01');
    expect(fuelCost('1.125', '2.666666', 'CNY')).toBe('3.00');
    expect(fuelCost('2.5', '2000.2', 'MMK')).toBe('5001');
    expect(() => fuelCost('0', '1', 'USD')).toThrow('positive');
    expect(() => fuelCost('1.0001', '1', 'USD')).toThrow('decimal places');
    expect(() => fuelCost('1', '1.0000001', 'USD')).toThrow('decimal places');
  });
  it('excludes foreign history, reports exclusions, and preserves legacy MMK fractions', () => {
    const records = [{ amount: '0.10', currency: 'THB' }, { amount: '0.20', currency: 'THB' },
      { amount: '50000.25', currency: 'MMK' }, { amount: '10', currency: 'USD' }];
    expect(currencyTotal(records, 'THB')).toEqual({ amount: '0.30', currency: 'THB', excluded: [
      { currency: 'MMK', count: 1 }, { currency: 'USD', count: 1 },
    ] });
    expect(currencyTotal(records, 'MMK').amount).toBe('50000.25');
  });
});
