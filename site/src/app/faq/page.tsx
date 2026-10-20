import type { Metadata } from "next";
import { FAQ_CATEGORIES } from "@/content/faq";
import { pillTone } from "@/lib/tone";
import { FaqCategorySection } from "@/components/faq/faq-category";
import { AuroraBackdrop } from "@/components/marketing/aurora-backdrop";
import { SectionHeading } from "@/components/marketing/section-heading";
import { CtaBanner } from "@/components/marketing/cta-banner";

export const metadata: Metadata = {
  title: "FAQ",
  description:
    "Answers to common questions about AutoX — platforms, accounts, personal use, fleet management, maintenance, fuel and plans.",
};

export default function FaqPage() {
  return (
    <>
      <section className="relative isolate overflow-hidden border-b border-line">
        <AuroraBackdrop dots />
        <div className="mx-auto max-w-4xl px-4 pb-14 pt-24 sm:px-6 sm:pb-16 sm:pt-28">
          <SectionHeading
            eyebrow="Help center"
            title="Frequently asked questions"
            intro="Find answers to the most common questions about AutoX."
          />
          <nav aria-label="FAQ categories" className="mt-8 flex flex-wrap justify-center gap-2">
            {FAQ_CATEGORIES.map((category, index) => (
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
        {FAQ_CATEGORIES.map((category) => (
          <FaqCategorySection key={category.id} category={category} />
        ))}
      </section>

      <CtaBanner
        title="Still have questions?"
        subtitle="Start with the free plan and try AutoX with zero commitment."
        primary={{ href: "/pricing", label: "See pricing" }}
        secondary={{ href: "/#download", label: "Download the app" }}
      />
    </>
  );
}
