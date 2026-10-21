import { AUDIENCES, FEATURES, HERO, PATHS, STEPS, VALUE_CHIPS } from "@/content/features";
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

export default function HomePage() {
  return (
    <>
      {/* Hero */}
      <section className="relative isolate flex min-h-svh flex-col items-center justify-center overflow-hidden border-b border-line pt-20 sm:pt-24">
        <AuroraBackdrop dots orbs />
        <div className="mx-auto grid w-full max-w-6xl gap-10 px-4 py-16 sm:px-6 sm:py-20 lg:grid-cols-[1.15fr_1fr] lg:items-center">
          <div className="flex flex-col items-start gap-6">
            <Reveal delay={0}>
              <span className="pill pill-gold">{HERO.eyebrow}</span>
            </Reveal>
            <Reveal delay={80}>
              <h1 className="font-display text-4xl font-semibold leading-[1.1] tracking-tight sm:text-5xl lg:text-[3.4rem]">
                {HERO.title}
              </h1>
            </Reveal>
            <Reveal delay={160}>
              <p className="max-w-xl text-base leading-7 text-ink-muted sm:text-lg">{HERO.subtitle}</p>
            </Reveal>
            <Reveal delay={240}>
              <StoreBadges />
            </Reveal>
            <Reveal delay={320} className="flex flex-wrap gap-x-6 gap-y-2">
              {VALUE_CHIPS.map((chip) => (
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
              alt="AutoX dashboard showing the vehicle garage"
              label="Dashboard — your garage at a glance"
              float
              priority
            />
          </Reveal>
        </div>
      </section>

      {/* Paths */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow="Choose your path"
          title="How do you want to use AutoX?"
          intro="AutoX adapts to your needs — track your own vehicles or manage an entire fleet."
        />
        <div className="mt-10">
          <PathCards items={PATHS} />
        </div>
      </section>

      {/* Features */}
      <section className="border-y border-line bg-panel">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
          <SectionHeading
            eyebrow="Features"
            title="Everything you need to manage your vehicles"
            intro="One digital garage for fuel, charging, maintenance, costs and documents — offline-first."
          />
          <div className="mt-10">
            <FeatureGrid items={FEATURES} />
          </div>
        </div>
      </section>

      {/* Audiences */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow="Built for every driver"
          title="Every type of vehicle, every type of owner"
        />
        <div className="mt-10">
          <AudienceGrid items={AUDIENCES} />
        </div>
      </section>

      {/* How it works */}
      <section className="border-y border-line bg-panel">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
          <SectionHeading
            eyebrow="How it works"
            title="Start in 3 simple steps"
            intro="You are minutes away from a complete vehicle history."
          />
          <div className="mt-10">
            <StepList items={STEPS} />
          </div>
        </div>
      </section>

      {/* Screenshot showcase */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow="Explore the app"
          title="See your garage at a glance"
          intro="Fuel logs, maintenance plans and costs — captured straight from the app."
        />
        <div className="mt-10 flex flex-wrap items-start justify-center gap-8">
          <Reveal delay={0}>
            <PhoneFrame
              src={{ dark: "/screenshots/app-dashboard-dark.webp", light: "/screenshots/app-dashboard-light.webp" }}
              alt="Dashboard screen"
              label="Dashboard"
            />
          </Reveal>
          <Reveal delay={90}>
            <PhoneFrame
              src={{ dark: "/screenshots/app-fuel-dark.webp", light: "/screenshots/app-fuel-light.webp" }}
              alt="Fuel log screen"
              label="Fuel log"
            />
          </Reveal>
          <Reveal delay={180}>
            <PhoneFrame
              src={{ dark: "/screenshots/app-maintenance-dark.webp", light: "/screenshots/app-maintenance-light.webp" }}
              alt="Maintenance plan screen"
              label="Maintenance plan"
            />
          </Reveal>
        </div>
      </section>

      {/* Download CTA */}
      <section id="download" className="scroll-mt-20 border-t border-line bg-panel">
        <div className="mx-auto flex max-w-6xl flex-col items-center gap-6 px-4 py-16 text-center sm:px-6 sm:py-20">
          <h2 className="max-w-2xl font-display text-3xl font-semibold leading-tight tracking-tight sm:text-4xl">
            Start your digital garage now
          </h2>
          <p className="max-w-xl text-base leading-7 text-ink-muted sm:text-lg">
            Free forever for one vehicle. Download AutoX and log your first fill-up in under a minute.
          </p>
          <StoreBadges className="justify-center" />
          <p className="text-xs text-ink-caption">Android and iOS · Offline-first · No credit card</p>
        </div>
      </section>

      <CtaBanner
        title="Ready to take control?"
        subtitle="Pick the plan that fits — start free and upgrade any time."
        showBadges={false}
        primary={{ href: "/pricing", label: "See pricing" }}
        secondary={{ href: "/faq", label: "Read the FAQ" }}
      />
    </>
  );
}
