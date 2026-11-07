"use client";

import { useState } from "react";
import type { BillingPeriod, PricingResponse } from "@/lib/pricing";
import type { Dictionary } from "@/i18n/types";
import { Reveal } from "@/components/marketing/reveal";
import { FeatureTable } from "./feature-table";
import { PricingCard } from "./pricing-card";
import { PricingToggle } from "./pricing-toggle";

type PricingSectionProps = {
  data: PricingResponse;
  live: boolean;
  copy: Dictionary["pricing"];
};

export function PricingSection({ data, live, copy }: PricingSectionProps) {
  const [period, setPeriod] = useState<BillingPeriod>("monthly");

  return (
    <div className="flex flex-col gap-12">
      <div className="flex flex-col items-center gap-5">
        <PricingToggle value={period} onChange={setPeriod} copy={copy.toggle} />
        <p className="text-xs text-ink-caption">
          {live ? copy.liveNote : copy.offlineNote}
          {!live && <span className="ml-1 text-warning">{copy.offlineSnapshot}</span>}
        </p>
      </div>

      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        {data.plans.map((plan, index) => (
          <Reveal key={plan.id} delay={index * 80} className="h-full">
            <PricingCard plan={plan} period={period} index={index} copy={copy.card} />
          </Reveal>
        ))}
      </div>

      <section aria-labelledby="compare-heading" className="flex flex-col gap-6">
        <Reveal className="flex flex-col gap-2">
          <h2 id="compare-heading" className="font-display text-2xl font-semibold tracking-tight">
            {copy.compareHeading}
          </h2>
          <p className="text-sm text-ink-muted">{copy.compareIntro}</p>
        </Reveal>
        <FeatureTable plans={data.plans} matrix={data.feature_matrix} copy={copy.table} />
      </section>

      <Reveal className="surface surface-grad tone-info grid gap-4 rounded-xl p-6 sm:grid-cols-3">
        {copy.perks.map((perk) => (
          <div key={perk.title}>
            <h3 className="font-display text-base font-semibold">{perk.title}</h3>
            <p className="mt-1 text-sm text-ink-muted">{perk.description}</p>
          </div>
        ))}
      </Reveal>
    </div>
  );
}
