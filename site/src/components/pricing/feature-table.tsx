import { Fragment } from "react";
import type { PricingFeatureGroup, PricingPlan } from "@/lib/pricing";

type FeatureTableProps = {
  plans: PricingPlan[];
  matrix: PricingFeatureGroup[];
};

function renderValue(value: boolean | string): React.ReactNode {
  if (typeof value === "string") return <span className="text-ink-muted">{value}</span>;
  if (value) {
    return (
      <svg
        aria-label="Included"
        role="img"
        viewBox="0 0 20 20"
        fill="currentColor"
        className="mx-auto h-4 w-4 text-gold"
      >
        <path
          fillRule="evenodd"
          d="M16.7 5.3a1 1 0 0 1 0 1.4l-7.5 7.5a1 1 0 0 1-1.4 0l-3.5-3.5a1 1 0 1 1 1.4-1.4l2.8 2.8 6.8-6.8a1 1 0 0 1 1.4 0Z"
          clipRule="evenodd"
        />
      </svg>
    );
  }
  return (
    <span aria-label="Not included" role="img" className="text-ink-faint">
      —
    </span>
  );
}

export function FeatureTable({ plans, matrix }: FeatureTableProps) {
  return (
    <div className="surface overflow-x-auto rounded-xl">
      <table className="w-full min-w-[640px] border-collapse text-sm">
        <thead>
          <tr className="border-b border-line">
            <th scope="col" className="px-5 py-4 text-left font-display text-base font-semibold">
              Features
            </th>
            {plans.map((plan) => (
              <th key={plan.id} scope="col" className="px-4 py-4 text-center font-display text-base font-semibold">
                {plan.name}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {matrix.map((group) => (
            <Fragment key={group.category}>
              <tr className="bg-panel">
                <th
                  scope="colgroup"
                  colSpan={plans.length + 1}
                  className="px-5 py-2.5 text-left text-xs font-medium uppercase tracking-wide text-ink-faint"
                >
                  {group.category}
                </th>
              </tr>
              {group.rows.map((row) => (
                <tr
                  key={`${group.category}-${row.label}`}
                  className="border-b border-line-subtle transition-colors duration-200 ease-out-soft last:border-0 hover:bg-gold/[0.04]"
                >
                  <th scope="row" className="px-5 py-3 text-left font-normal text-ink">
                    {row.label}
                  </th>
                  {plans.map((plan) => (
                    <td key={plan.id} className="px-4 py-3 text-center">
                      {renderValue(row.values[plan.id])}
                    </td>
                  ))}
                </tr>
              ))}
            </Fragment>
          ))}
        </tbody>
      </table>
    </div>
  );
}
