"use client";

import { useState } from "react";
import type { BillingPeriod, PricingResponse } from "@/lib/pricing";
import { Reveal } from "@/components/marketing/reveal";
import { FeatureTable } from "./feature-table";
import { PricingCard } from "./pricing-card";
import { PricingToggle } from "./pricing-toggle";

type PricingSectionProps = {
  data: PricingResponse;
  live: boolean;
};

export function PricingSection({ data, live }: PricingSectionProps) {
  const [period, setPeriod] = useState<BillingPeriod>("monthly");

  return (
    <div className="flex flex-col gap-12">
      <div className="flex flex-col items-center gap-5">
        <PricingToggle value={period} onChange={setPeriod} />
        <p className="text-xs text-ink-caption">
          {live
            ? "Prices served live from the API · shown in MMK, with USD equivalents"
            : "Showing saved pricing — live API unavailable"}
          {!live && <span className="ml-1 text-warning">(offline snapshot)</span>}
        </p>
      </div>

      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        {data.plans.map((plan, index) => (
          <Reveal key={plan.id} delay={index * 80} className="h-full">
            <PricingCard plan={plan} period={period} />
          </Reveal>
        ))}
      </div>

      <section aria-labelledby="compare-heading" className="flex flex-col gap-6">
        <Reveal className="flex flex-col gap-2">
          <h2 id="compare-heading" className="font-display text-2xl font-semibold tracking-tight">
            Compare every plan
          </h2>
          <p className="text-sm text-ink-muted">
            Limits and features per tier. Fleet operations are included with Fleet/Pro.
          </p>
        </Reveal>
        <FeatureTable plans={data.plans} matrix={data.feature_matrix} />
      </section>

      <Reveal className="surface grid gap-4 rounded-xl p-6 sm:grid-cols-3">
        <div>
          <h3 className="font-display text-base font-semibold">30-day money-back</h3>
          <p className="mt-1 text-sm text-ink-muted">Paid plans include a no-questions-asked refund window.</p>
        </div>
        <div>
          <h3 className="font-display text-base font-semibold">Pay in MMK</h3>
          <p className="mt-1 text-sm text-ink-muted">Local payment methods for Myanmar, USD by card internationally.</p>
        </div>
        <div>
          <h3 className="font-display text-base font-semibold">Annual = 2 months free</h3>
          <p className="mt-1 text-sm text-ink-muted">Billed yearly at ten times the monthly price.</p>
        </div>
      </Reveal>
    </div>
  );
}
