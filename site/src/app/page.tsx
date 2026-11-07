import { getSiteCopy } from "@/i18n/dictionary";
import { AudienceGrid } from "@/components/marketing/audience-grid";
import { AuroraBackdrop } from "@/components/marketing/aurora-backdrop";
import { CtaBanner } from "@/components/marketing/cta-banner";
import { FeatureGrid } from "@/components/marketing/feature-grid";
import { PathCards } from "@/components/marketing/path-cards";
import { PhoneFrame } from "@/components/marketing/phone-frame";
import { Reveal } from "@/components/marketing/reveal";
import { SectionHeading } from "@/components/marketing/section-heading";
import { StepList } from "@/components/marketing/step-list";
import { StoreBadges } from "@/components/marketing/store-badges";

const PATH_HREFS = ["/personal", "/fleet"] as const;

export default async function HomePage() {
  const { d } = await getSiteCopy();
  const h = d.home;

  return (
    <>
      {/* Hero */}
      <section className="relative isolate flex min-h-svh flex-col items-center justify-center overflow-hidden border-b border-line pt-20 sm:pt-24">
        <AuroraBackdrop dots orbs />
        <div className="mx-auto grid w-full max-w-6xl gap-10 px-4 py-16 sm:px-6 sm:py-20 lg:grid-cols-[1.15fr_1fr] lg:items-center">
          <div className="flex flex-col items-start gap-6">
            <Reveal delay={0}>
              <span className="pill pill-gold">{h.hero.eyebrow}</span>
            </Reveal>
            <Reveal delay={80}>
              <h1 className="font-display text-4xl font-semibold leading-[1.1] tracking-tight sm:text-5xl lg:text-[3.4rem]">
                {h.hero.title}
              </h1>
            </Reveal>
            <Reveal delay={160}>
              <p className="max-w-xl text-base leading-7 text-ink-muted sm:text-lg">{h.hero.subtitle}</p>
            </Reveal>
            <Reveal delay={240}>
              <StoreBadges labels={d.storeBadges} />
            </Reveal>
            <Reveal delay={320} className="flex flex-wrap gap-x-6 gap-y-2">
              {h.valueChips.map((chip) => (
                <div key={chip.title} className="flex items-baseline gap-2">
                  <span className="text-sm font-semibold text-ink">{chip.title}</span>
                  <span className="text-xs text-ink-caption">{chip.description}</span>
                </div>
              ))}
            </Reveal>
          </div>
          <Reveal delay={220} className="flex justify-center lg:justify-end">
            <PhoneFrame
              src={{ dark: "/screenshots/app-dashboard-dark.webp", light: "/screenshots/app-dashboard-light.webp" }}
              alt={h.hero.dashboardAlt}
              label={h.hero.dashboardLabel}
              float
              priority
            />
          </Reveal>
        </div>
      </section>

      {/* Paths */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow={h.pathsSection.eyebrow}
          title={h.pathsSection.title}
          intro={h.pathsSection.intro}
        />
        <div className="mt-10">
          <PathCards items={h.paths.map((item, index) => ({ ...item, href: PATH_HREFS[index] }))} />
        </div>
      </section>

      {/* Features */}
      <section className="border-y border-line bg-panel">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
          <SectionHeading
            eyebrow={h.featuresSection.eyebrow}
            title={h.featuresSection.title}
            intro={h.featuresSection.intro}
          />
          <div className="mt-10">
            <FeatureGrid items={h.features} />
          </div>
        </div>
      </section>

      {/* Audiences */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow={h.audiencesSection.eyebrow}
          title={h.audiencesSection.title}
        />
        <div className="mt-10">
          <AudienceGrid items={h.audiences} />
        </div>
      </section>

      {/* How it works */}
      <section className="border-y border-line bg-panel">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
          <SectionHeading
            eyebrow={h.stepsSection.eyebrow}
            title={h.stepsSection.title}
            intro={h.stepsSection.intro}
          />
          <div className="mt-10">
            <StepList items={h.steps} />
          </div>
        </div>
      </section>

      {/* Screenshot showcase */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow={h.showcaseSection.eyebrow}
          title={h.showcaseSection.title}
          intro={h.showcaseSection.intro}
        />
        <div className="mt-10 flex flex-wrap items-start justify-center gap-8">
          <Reveal delay={0}>
            <PhoneFrame
              src={{ dark: "/screenshots/app-dashboard-dark.webp", light: "/screenshots/app-dashboard-light.webp" }}
              alt={h.showcaseSection.dashboardAlt}
              label={h.showcaseSection.dashboardLabel}
            />
          </Reveal>
          <Reveal delay={90}>
            <PhoneFrame
              src={{ dark: "/screenshots/app-fuel-dark.webp", light: "/screenshots/app-fuel-light.webp" }}
              alt={h.showcaseSection.fuelAlt}
              label={h.showcaseSection.fuelLabel}
            />
          </Reveal>
          <Reveal delay={180}>
            <PhoneFrame
              src={{ dark: "/screenshots/app-maintenance-dark.webp", light: "/screenshots/app-maintenance-light.webp" }}
              alt={h.showcaseSection.maintenanceAlt}
              label={h.showcaseSection.maintenanceLabel}
            />
          </Reveal>
        </div>
      </section>

      {/* Download CTA */}
      <section id="download" className="scroll-mt-20 border-t border-line bg-panel">
        <div className="mx-auto flex max-w-6xl flex-col items-center gap-6 px-4 py-16 text-center sm:px-6 sm:py-20">
          <h2 className="max-w-2xl font-display text-3xl font-semibold leading-tight tracking-tight sm:text-4xl">
            {h.download.title}
          </h2>
          <p className="max-w-xl text-base leading-7 text-ink-muted sm:text-lg">
            {h.download.intro}
          </p>
          <StoreBadges labels={d.storeBadges} className="justify-center" />
          <p className="text-xs text-ink-caption">{h.download.note}</p>
        </div>
      </section>

      <CtaBanner
        title={h.cta.title}
        subtitle={h.cta.subtitle}
        showBadges={false}
        primary={{ href: "/pricing", label: h.cta.primary }}
        secondary={{ href: "/faq", label: h.cta.secondary }}
        badgeLabels={d.storeBadges}
      />
    </>
  );
}
