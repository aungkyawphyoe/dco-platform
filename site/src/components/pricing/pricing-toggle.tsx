"use client";

import type { BillingPeriod } from "@/lib/pricing";
import type { Dictionary } from "@/i18n/types";

type PricingToggleProps = {
  value: BillingPeriod;
  onChange: (period: BillingPeriod) => void;
  copy: Dictionary["pricing"]["toggle"];
};

export function PricingToggle({ value, onChange, copy }: PricingToggleProps) {
  return (
    <div
      role="group"
      aria-label={copy.aria}
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
            {period === "monthly" ? copy.monthly : copy.annual}
            {period === "annual" && (
              <span className={`pill pill-sm ml-2 ${active ? "pill-on-gold" : "pill-mint"}`}>
                {copy.twoMonthsFree}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}
