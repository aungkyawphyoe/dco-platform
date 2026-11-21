import type { Metadata } from "next";
import { getSiteCopy } from "@/i18n/dictionary";
import { FaqCategorySection } from "@/components/faq/faq-category";
import { CtaBanner } from "@/components/marketing/cta-banner";
import { GarageArt } from "@/components/marketing/garage-art";

export async function generateMetadata(): Promise<Metadata> {
  const { d } = await getSiteCopy();
  return {
    title: d.meta.pages.faq.title,
    description: d.meta.pages.faq.description,
  };
}

export default async function FaqPage() {
  const { d } = await getSiteCopy();
  const faq = d.faq;
  return <>
    <section className="frame-section paired route-hero"><div><h1><span className="section-label">{faq.hero.eyebrow}</span>{faq.hero.title}</h1><p className="intro">{faq.hero.intro}</p></div>
      <GarageArt kind="help" /></section>
    <div className="frame-section faq-layout">
      <nav aria-label={faq.categoriesAria}>{faq.categories.map(c => <a key={c.id} href={`#${c.id}`}>{c.label}</a>)}</nav>
      <div className="grid gap-12">{faq.categories.map(c => <FaqCategorySection key={c.id} category={c} />)}</div>
    </div>
    <CtaBanner label={d.sectionLabels.nextSteps} title={faq.cta.title} subtitle={faq.cta.subtitle}
      primary={{href:"/pricing",label:faq.cta.primary}} secondary={{href:"/#download",label:faq.cta.secondary}}
      badgeLabels={d.storeBadges} showBadges={false} />
  </>;
}
