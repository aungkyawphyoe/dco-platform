import type { Metadata } from "next";
import { FAQ_CATEGORIES } from "@/content/faq";
import { FaqCategorySection } from "@/components/faq/faq-category";
import { SectionHeading } from "@/components/marketing/section-heading";
import { CtaBanner } from "@/components/marketing/cta-banner";

export const metadata: Metadata = {
  title: "FAQ",
  description:
    "Answers to common questions about DCO — platforms, accounts, personal use, fleet management, maintenance, fuel and plans.",
};

export default function FaqPage() {
  return (
    <>
      <section className="border-b border-line">
        <div className="mx-auto max-w-4xl px-4 py-14 sm:px-6 sm:py-16">
          <SectionHeading
            eyebrow="Help center"
            title="Frequently asked questions"
            intro="Find answers to the most common questions about DCO."
          />
          <nav aria-label="FAQ categories" className="mt-8 flex flex-wrap justify-center gap-2">
            {FAQ_CATEGORIES.map((category) => (
              <a
                key={category.id}
                href={`#${category.id}`}
                className="rounded-full border border-line-subtle bg-card px-4 py-1.5 text-sm text-ink-muted transition-colors duration-150 hover:border-gold hover:text-gold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
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
        subtitle="Start with the free plan and try DCO with zero commitment."
        primary={{ href: "/pricing", label: "See pricing" }}
        secondary={{ href: "/#download", label: "Download the app" }}
      />
    </>
  );
}
