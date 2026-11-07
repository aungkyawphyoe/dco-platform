import type { Metadata } from "next";
import { getSiteCopy } from "@/i18n/dictionary";
import { getPricing, localizePricing } from "@/lib/pricing";
import { PricingSection } from "@/components/pricing/pricing-section";
import { AuroraBackdrop } from "@/components/marketing/aurora-backdrop";
import { SectionHeading } from "@/components/marketing/section-heading";

export async function generateMetadata(): Promise<Metadata> {
  const { d } = await getSiteCopy();
  return {
    title: d.meta.pages.pricing.title,
    description: d.meta.pages.pricing.description,
  };
}

export default async function PricingPage() {
  const { d } = await getSiteCopy();
  const { data, live } = await getPricing();
  const localized = localizePricing(data, d.pricing.catalog);

  return (
    <>
      <section className="relative isolate overflow-hidden border-b border-line">
        <AuroraBackdrop dots />
        <div className="mx-auto max-w-6xl px-4 pb-14 pt-24 sm:px-6 sm:pb-16 sm:pt-28">
          <SectionHeading
            eyebrow={d.pricing.hero.eyebrow}
            title={d.pricing.hero.title}
            intro={d.pricing.hero.intro}
          />
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-4 py-12 sm:px-6 sm:py-16">
        <PricingSection data={localized} live={live} copy={d.pricing} />
      </section>
    </>
  );
}
