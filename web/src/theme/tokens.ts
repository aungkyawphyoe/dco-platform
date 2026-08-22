import theme from "./garage-minimal-dark.json";

export const tokens = theme;

export type Tokens = typeof tokens;

/** Expense category → chart hue, per design-system "chart" block. */
export const categoryColor: Record<string, string> = {
  fuel: tokens.chart.fuel,
  maintenance: tokens.chart.maintenance,
  insurance: tokens.chart.insurance,
  parking: tokens.chart.parking,
  tolls: tokens.chart.tolls,
  parts: tokens.chart.parts,
  other: tokens.chart.other,
};
