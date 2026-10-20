import type { Metadata } from "next";
import { getPricing } from "@/lib/pricing";
import { PricingSection } from "@/components/pricing/pricing-section";
import { AuroraBackdrop } from "@/components/marketing/aurora-backdrop";
import { SectionHeading } from "@/components/marketing/section-heading";

export const metadata: Metadata = {
  title: "Pricing",
  description:
    "Simple, transparent pricing — free for one vehicle, flexible plans for more vehicles and fleets. Prices in MMK and USD.",
};

export default async function PricingPage() {
  const { data, live } = await getPricing();

  return (
    <>
      <section className="relative isolate overflow-hidden border-b border-line">
        <AuroraBackdrop dots />
        <div className="mx-auto max-w-6xl px-4 pb-14 pt-24 sm:px-6 sm:pb-16 sm:pt-28">
          <SectionHeading
            eyebrow="Pricing"
            title="Simple, transparent pricing"
            intro="Free for your first vehicle. Upgrade for more vehicles, sharing and storage — or move to Fleet/Pro for your operation."
          />
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-4 py-12 sm:px-6 sm:py-16">
        <PricingSection data={data} live={live} />
      </section>
    </>
  );
}
