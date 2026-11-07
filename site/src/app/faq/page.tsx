import type { Metadata } from "next";
import { getSiteCopy } from "@/i18n/dictionary";
import { pillTone } from "@/lib/tone";
import { FaqCategorySection } from "@/components/faq/faq-category";
import { AuroraBackdrop } from "@/components/marketing/aurora-backdrop";
import { SectionHeading } from "@/components/marketing/section-heading";
import { CtaBanner } from "@/components/marketing/cta-banner";

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

  return (
    <>
      <section className="relative isolate overflow-hidden border-b border-line">
        <AuroraBackdrop dots />
        <div className="mx-auto max-w-4xl px-4 pb-14 pt-24 sm:px-6 sm:pb-16 sm:pt-28">
          <SectionHeading
            eyebrow={faq.hero.eyebrow}
            title={faq.hero.title}
            intro={faq.hero.intro}
          />
          <nav aria-label={faq.categoriesAria} className="mt-8 flex flex-wrap justify-center gap-2">
            {faq.categories.map((category, index) => (
              <a
                key={category.id}
                href={`#${category.id}`}
                className={`pill ${pillTone(index)} px-4 py-1.5 text-sm transition-[filter,transform] duration-200 ease-out-soft hover:-translate-y-0.5 hover:brightness-110 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus`}
              >
                {category.label}
              </a>
            ))}
          </nav>
        </div>
      </section>

      <section className="mx-auto flex max-w-4xl flex-col gap-12 px-4 py-12 sm:px-6 sm:py-16">
        {faq.categories.map((category) => (
          <FaqCategorySection key={category.id} category={category} />
        ))}
      </section>

      <CtaBanner
        title={faq.cta.title}
        subtitle={faq.cta.subtitle}
        primary={{ href: "/pricing", label: faq.cta.primary }}
        secondary={{ href: "/#download", label: faq.cta.secondary }}
        badgeLabels={d.storeBadges}
      />
    </>
  );
}
