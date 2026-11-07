import type { Metadata } from "next";
import Link from "next/link";
import { getSiteCopy } from "@/i18n/dictionary";
import { cardTone, pillTone } from "@/lib/tone";
import { AuroraBackdrop } from "@/components/marketing/aurora-backdrop";
import { BenefitList } from "@/components/marketing/benefit-list";
import { BrowserFrame } from "@/components/marketing/browser-frame";
import { CtaBanner } from "@/components/marketing/cta-banner";
import { FeatureGrid } from "@/components/marketing/feature-grid";
import { Reveal } from "@/components/marketing/reveal";
import { SectionHeading } from "@/components/marketing/section-heading";
import { StepList } from "@/components/marketing/step-list";

export async function generateMetadata(): Promise<Metadata> {
  const { d } = await getSiteCopy();
  return {
    title: d.meta.pages.fleet.title,
    description: d.meta.pages.fleet.description,
  };
}

function RequestDemoLink({ className, label }: { className: string; label: string }) {
  return (
    <Link href="/demo" className={className}>
      {label}
    </Link>
  );
}

export default async function FleetPage() {
  const { d } = await getSiteCopy();
  const f = d.fleet;

  return (
    <>
      {/* Hero */}
      <section className="relative isolate flex min-h-svh flex-col items-center justify-center overflow-hidden border-b border-line pt-20 sm:pt-24">
        <AuroraBackdrop dots orbs />
        <div className="mx-auto grid w-full max-w-6xl gap-10 px-4 py-16 sm:px-6 sm:py-20 lg:grid-cols-[1fr_1.15fr] lg:items-center">
          <div className="flex flex-col items-start gap-6">
            <Reveal delay={0} className="flex flex-wrap items-center gap-3">
              <span className="pill pill-gold">{f.hero.eyebrow}</span>
              <span className="pill pill-info">{f.hero.badge}</span>
            </Reveal>
            <Reveal delay={80}>
              <h1 className="font-display text-4xl font-semibold leading-[1.1] tracking-tight sm:text-5xl">
                {f.hero.title}
              </h1>
            </Reveal>
            <Reveal delay={160}>
              <p className="max-w-xl text-base leading-7 text-ink-muted sm:text-lg">{f.hero.subtitle}</p>
            </Reveal>
            <Reveal delay={240}>
              <ul className="grid gap-2.5 sm:grid-cols-2">
                {f.hero.bullets.map((bullet) => (
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
            <Reveal delay={320} className="flex flex-col gap-3">
              <div className="flex flex-wrap gap-3">
                <RequestDemoLink
                  className="btn-gloss inline-flex h-11 items-center rounded-full px-6 text-sm font-semibold"
                  label={f.hero.requestDemo}
                />
                <Link
                  href="/pricing"
                  className="surface card-hover inline-flex h-11 items-center rounded-full px-6 text-sm font-semibold text-ink"
                >
                  {f.hero.seePricing}
                </Link>
              </div>
              <p className="text-xs text-ink-caption">{f.hero.noSignup}</p>
            </Reveal>
          </div>
          <Reveal delay={220} className="flex justify-center lg:justify-end">
            <BrowserFrame
              src={{ dark: "/screenshots/portal-dashboard-dark.webp", light: "/screenshots/portal-dashboard-light.webp" }}
              alt={f.hero.browserAlt}
              label={f.hero.browserLabel}
              priority
            />
          </Reveal>
        </div>
      </section>

      {/* Challenges */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow={f.challenges.eyebrow}
          title={f.challenges.heading}
          intro={f.challenges.intro}
          align="left"
        />
        <div className="mt-10 grid gap-4 sm:grid-cols-2">
          {f.challenges.items.map((item, index) => (
            <Reveal key={item.title} delay={index * 70} className="h-full">
              <article className={`surface card-grad card-hover h-full rounded-xl p-6 ${cardTone(index)}`}>
                <h3 className="font-display text-lg font-semibold tracking-tight">{item.title}</h3>
                <p className="mt-2 text-sm leading-6 text-ink-muted">{item.description}</p>
              </article>
            </Reveal>
          ))}
        </div>
      </section>

      {/* Steps */}
      <section className="border-y border-line bg-panel">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
          <SectionHeading
            eyebrow={f.stepsSection.eyebrow}
            title={f.stepsSection.title}
            intro={f.stepsSection.intro}
          />
          <div className="mt-10">
            <StepList items={f.steps} />
          </div>
          <div className="mt-10 flex flex-col items-center gap-2">
            <RequestDemoLink
              className="btn-gloss inline-flex h-11 items-center rounded-full px-6 text-sm font-semibold"
              label={f.hero.requestDemo}
            />
            <p className="text-xs text-ink-caption">{f.stepsSection.note}</p>
          </div>
        </div>
      </section>

      {/* Modules */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow={f.modulesSection.eyebrow}
          title={f.modulesSection.title}
        />
        <div className="mt-10">
          <FeatureGrid items={f.modules} />
        </div>
      </section>

      {/* Benefits */}
      <section className="border-y border-line bg-panel">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
          <SectionHeading
            eyebrow={f.benefitsSection.eyebrow}
            title={f.benefitsSection.title}
          />
          <div className="mt-10">
            <BenefitList items={f.benefits} />
          </div>
        </div>
      </section>

      {/* Comparison */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow={f.comparison.eyebrow}
          title={f.comparison.title}
        />
        <Reveal className="surface mt-10 overflow-hidden rounded-xl">
          <div className="grid grid-cols-2 border-b border-line bg-panel">
            <div className="px-5 py-3 text-xs font-medium uppercase tracking-wide text-ink-faint">
              {f.comparison.manual}
            </div>
            <div className="border-l border-line px-5 py-3 text-xs font-medium uppercase tracking-wide text-gold">
              {f.comparison.dco}
            </div>
          </div>
          {f.comparison.rows.map((row) => (
            <div key={row.manual} className="grid grid-cols-2 border-b border-line-subtle last:border-0">
              <div className="px-5 py-4 text-sm text-ink-muted">{row.manual}</div>
              <div className="border-l border-line-subtle px-5 py-4 text-sm text-ink">{row.dco}</div>
            </div>
          ))}
        </Reveal>
      </section>

      {/* Industries */}
      <section className="border-y border-line bg-panel">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
          <SectionHeading
            eyebrow={f.industriesSection.eyebrow}
            title={f.industriesSection.title}
          />
          <Reveal className="mt-10 flex flex-wrap justify-center gap-3">
            {f.industries.map((industry, index) => (
              <span
                key={industry}
                className={`pill ${pillTone(index)} px-4 py-2 text-sm transition-transform duration-200 ease-out-soft hover:-translate-y-0.5`}
              >
                {industry}
              </span>
            ))}
          </Reveal>
        </div>
      </section>

      <CtaBanner
        title={f.cta.title}
        subtitle={f.cta.subtitle}
        showBadges={false}
        primary={{ href: "/demo", label: f.cta.primary }}
        secondary={{ href: "/pricing", label: f.cta.secondary }}
        badgeLabels={d.storeBadges}
      />
    </>
  );
}
