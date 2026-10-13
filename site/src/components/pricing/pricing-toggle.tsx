"use client";

import type { BillingPeriod } from "@/lib/pricing";

type PricingToggleProps = {
  value: BillingPeriod;
  onChange: (period: BillingPeriod) => void;
};

export function PricingToggle({ value, onChange }: PricingToggleProps) {
  return (
    <div
      role="group"
      aria-label="Billing period"
      className="glass inline-flex items-center gap-1 rounded-full p-1"
    >
      {(["monthly", "annual"] as const).map((period) => {
        const active = value === period;
        return (
          <button
            key={period}
            type="button"
            aria-pressed={active}
            onClick={() => onChange(period)}
            className={`relative rounded-full px-5 py-2 text-sm font-medium transition-[color,background-color,box-shadow] duration-200 ease-out-soft focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus ${
              active ? "btn-gloss" : "text-ink-muted hover:text-ink"
            }`}
          >
            {period === "monthly" ? "Monthly" : "Annual"}
            {period === "annual" && (
              <span
                className={`ml-2 rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                  active ? "bg-on-gold/15 text-on-gold" : "bg-success-dim text-success"
                }`}
              >
                2 months free
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}
