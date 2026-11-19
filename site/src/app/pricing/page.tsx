import type { Metadata } from "next";
import { getSiteCopy } from "@/i18n/dictionary";
import Link from "next/link";
import { getPricing, localizePricing } from "@/lib/pricing";
import { PricingSection } from "@/components/pricing/pricing-section";
import { GarageArt } from "@/components/marketing/garage-art";
import { FaqCategorySection } from "@/components/faq/faq-category";

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
  const plansFaq = d.faq.categories.find(category => category.id === "plans");
  return <>
    <section className="frame-section paired route-hero"><div><h1>{d.pricing.hero.title}</h1><p className="intro">{d.pricing.hero.intro}</p></div>
      <GarageArt kind="receipt" /></section>
    <section className="frame-section"><PricingSection data={localizePricing(data, d.pricing.catalog)} live={live} copy={d.pricing} /></section>
    {plansFaq && <div className="frame-section">
      <FaqCategorySection category={{ ...plansFaq, items: plansFaq.items.slice(1, 4) }} />
      <Link href="/faq#plans" className="text-link">{d.home.cta.secondary}</Link>
    </div>}
    <section className="closing"><h2>{d.home.pathsSection.title}</h2>
      <div className="actions"><Link href="/personal" className="action">{d.home.paths[0].cta}</Link>
        <Link href="/fleet" className="action secondary">{d.home.paths[1].cta}</Link></div>
    </section>
  </>;
}
