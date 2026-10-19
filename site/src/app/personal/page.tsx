import type { Metadata } from "next";
import {
  PERSONAL_BENEFITS,
  PERSONAL_FEATURES,
  PERSONAL_HERO,
  PERSONAL_PROBLEM,
  PERSONAL_SOLUTION,
  PERSONAL_STEPS,
} from "@/content/personal";
import { cardTone } from "@/lib/tone";
import { BenefitList } from "@/components/marketing/benefit-list";
import { AuroraBackdrop } from "@/components/marketing/aurora-backdrop";
import { CtaBanner } from "@/components/marketing/cta-banner";
import { FeatureGrid } from "@/components/marketing/feature-grid";
import { PhoneFrame } from "@/components/marketing/phone-frame";
import { Reveal } from "@/components/marketing/reveal";
import { SectionHeading } from "@/components/marketing/section-heading";
import { StepList } from "@/components/marketing/step-list";

export const metadata: Metadata = {
  title: "Personal Use",
  description:
    "Track fuel, charging, maintenance and expenses for your own vehicles. Free forever plan available — offline-first on Android and iOS.",
};

export default function PersonalPage() {
  return (
    <>
      {/* Hero */}
      <section className="relative isolate flex min-h-svh flex-col items-center justify-center overflow-hidden border-b border-line pt-20 sm:pt-24">
        <AuroraBackdrop dots orbs />
        <div className="mx-auto grid w-full max-w-6xl gap-10 px-4 py-16 sm:px-6 sm:py-20 lg:grid-cols-[1.15fr_1fr] lg:items-center">
          <div className="flex flex-col items-start gap-6">
            <Reveal delay={0} className="flex flex-wrap items-center gap-3">
              <span className="pill pill-gold">{PERSONAL_HERO.eyebrow}</span>
              <span className="pill pill-success">Free forever</span>
            </Reveal>
            <Reveal delay={80}>
              <h1 className="font-display text-4xl font-semibold leading-[1.1] tracking-tight sm:text-5xl">
                {PERSONAL_HERO.title}
              </h1>
            </Reveal>
            <Reveal delay={160}>
              <p className="max-w-xl text-base leading-7 text-ink-muted sm:text-lg">{PERSONAL_HERO.subtitle}</p>
            </Reveal>
            <Reveal delay={240}>
              <ul className="grid gap-2.5 sm:grid-cols-2">
              {PERSONAL_HERO.bullets.map((bullet) => (
                <li key={bullet} className="flex items-start gap-2 text-sm text-ink-muted">
                  <svg
                    aria-hidden="true"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    className="mt-0.5 h-4 w-4 shrink-0 text-gold"
                  >
                    <path
                      fillRule="evenodd"
                      d="M16.7 5.3a1 1 0 0 1 0 1.4l-7.5 7.5a1 1 0 0 1-1.4 0l-3.5-3.5a1 1 0 1 1 1.4-1.4l2.8 2.8 6.8-6.8a1 1 0 0 1 1.4 0Z"
                      clipRule="evenodd"
                    />
                  </svg>
                  {bullet}
                </li>
              ))}
              </ul>
            </Reveal>
          </div>
          <Reveal delay={220} className="flex justify-center lg:justify-end">
            <PhoneFrame label="App preview — screenshot coming soon" float />
          </Reveal>
        </div>
      </section>

      {/* Problem */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow="The problem"
          title={PERSONAL_PROBLEM.heading}
          intro={PERSONAL_PROBLEM.intro}
          align="left"
        />
        <div className="mt-10 grid gap-4 sm:grid-cols-2">
          {PERSONAL_PROBLEM.items.map((item, index) => (
            <Reveal key={item.title} delay={index * 70} className="h-full">
              <article className={`surface card-grad card-hover h-full rounded-xl p-6 ${cardTone(index)}`}>
                <h3 className="font-display text-lg font-semibold tracking-tight">{item.title}</h3>
                <p className="mt-2 text-sm leading-6 text-ink-muted">{item.description}</p>
              </article>
            </Reveal>
          ))}
        </div>
      </section>

      {/* Solution */}
      <section className="border-y border-line bg-panel">
        <div className="mx-auto grid max-w-6xl gap-10 px-4 py-16 sm:px-6 sm:py-20 lg:grid-cols-2 lg:items-center">
          <div>
            <SectionHeading eyebrow="The solution" title={PERSONAL_SOLUTION.heading} intro={PERSONAL_SOLUTION.intro} align="left" />
          </div>
          <ul className="grid gap-3">
            {PERSONAL_SOLUTION.bullets.map((bullet, index) => (
              <Reveal key={bullet} delay={index * 70} as="li" className={`surface surface-grad card-hover rounded-xl p-4 ${cardTone(index)}`}>
                <span className="flex items-start gap-3 text-sm text-ink-muted">
                  <svg
                    aria-hidden="true"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    className="mt-0.5 h-4 w-4 shrink-0 text-gold"
                  >
                    <path
                      fillRule="evenodd"
                      d="M16.7 5.3a1 1 0 0 1 0 1.4l-7.5 7.5a1 1 0 0 1-1.4 0l-3.5-3.5a1 1 0 1 1 1.4-1.4l2.8 2.8 6.8-6.8a1 1 0 0 1 1.4 0Z"
                      clipRule="evenodd"
                    />
                  </svg>
                  {bullet}
                </span>
              </Reveal>
            ))}
          </ul>
        </div>
      </section>

      {/* Features */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow="Features"
          title="Everything you need to manage your vehicle"
        />
        <div className="mt-10">
          <FeatureGrid items={PERSONAL_FEATURES} />
        </div>
      </section>

      {/* Benefits */}
      <section className="border-y border-line bg-panel">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
          <SectionHeading eyebrow="Benefits" title="Why use AutoX?" />
          <div className="mt-10">
            <BenefitList items={PERSONAL_BENEFITS} />
          </div>
        </div>
      </section>

      {/* How to start */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow="How to start"
          title="Get started in 3 simple steps"
          intro="You are minutes away from total control of your vehicle."
        />
        <div className="mt-10">
          <StepList items={PERSONAL_STEPS} />
        </div>
      </section>

      <CtaBanner
        title="Start free — no catch"
        subtitle="One vehicle, full history, zero cost. Upgrade only when you need more."
        primary={{ href: "/pricing", label: "See plans" }}
        secondary={{ href: "/#download", label: "Download the app" }}
      />
    </>
  );
}
