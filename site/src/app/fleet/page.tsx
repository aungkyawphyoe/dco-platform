import type { Metadata } from "next";
import Link from "next/link";
import {
  FLEET_BENEFITS,
  FLEET_CHALLENGES,
  FLEET_COMPARISON,
  FLEET_HERO,
  FLEET_INDUSTRIES,
  FLEET_MODULES,
  FLEET_STEPS,
} from "@/content/fleet";
import { FLEET_CONTACT_EMAIL } from "@/content/site";
import { BenefitList } from "@/components/marketing/benefit-list";
import { CtaBanner } from "@/components/marketing/cta-banner";
import { FeatureGrid } from "@/components/marketing/feature-grid";
import { SectionHeading } from "@/components/marketing/section-heading";
import { StepList } from "@/components/marketing/step-list";

export const metadata: Metadata = {
  title: "Fleet Management",
  description:
    "Organize your company's vehicles, drivers, work orders and costs in one system — fleet portal plus mobile Fleet and Driver modes.",
};

function ContactSalesLink({ className }: { className: string }) {
  const href = FLEET_CONTACT_EMAIL ? `mailto:${FLEET_CONTACT_EMAIL}` : "/faq#fleet";
  return (
    <Link href={href} className={className}>
      Contact sales
    </Link>
  );
}

export default function FleetPage() {
  return (
    <>
      {/* Hero */}
      <section className="border-b border-line">
        <div className="mx-auto grid max-w-6xl gap-10 px-4 py-16 sm:px-6 sm:py-20 lg:grid-cols-[1.15fr_1fr] lg:items-center">
          <div className="flex flex-col items-start gap-6">
            <span className="rounded-full border border-line-subtle bg-panel px-3 py-1 text-xs font-medium text-ink-caption">
              {FLEET_HERO.eyebrow}
            </span>
            <span className="rounded-full bg-info-dim px-3 py-1 text-xs font-semibold text-info">
              Fleet/Pro · Guided onboarding
            </span>
            <h1 className="font-display text-4xl font-semibold leading-[1.1] tracking-tight sm:text-5xl">
              {FLEET_HERO.title}
            </h1>
            <p className="max-w-xl text-base leading-7 text-ink-muted sm:text-lg">{FLEET_HERO.subtitle}</p>
            <ul className="grid gap-2.5 sm:grid-cols-2">
              {FLEET_HERO.bullets.map((bullet) => (
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
            <div className="flex flex-wrap gap-3">
              <ContactSalesLink className="inline-flex h-11 items-center rounded-md bg-btn-primary px-6 text-sm font-semibold text-on-gold transition-colors duration-150 hover:bg-btn-primary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus" />
              <Link
                href="/pricing"
                className="inline-flex h-11 items-center rounded-md border border-line-strong bg-card px-6 text-sm font-semibold text-ink transition-colors duration-150 hover:bg-skeleton focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
              >
                See pricing
              </Link>
            </div>
            <p className="text-xs text-ink-caption">No self-serve signup — we provision your workspace for you.</p>
          </div>
          <div className="flex flex-col items-center gap-4">
            <div className="w-full max-w-sm rounded-xl border border-line-subtle bg-card p-6">
              <div className="flex items-center justify-between border-b border-line-subtle pb-3">
                <span className="text-sm font-semibold">Active fleet</span>
                <span className="rounded-full bg-success-dim px-2 py-0.5 text-xs text-success">Live</span>
              </div>
              <ul className="mt-4 space-y-3">
                {[
                  ["CAM-001", "On route"],
                  ["CAM-002", "Maintenance"],
                  ["CAM-003", "Available"],
                  ["CAM-004", "On route"],
                ].map(([plate, status]) => (
                  <li key={plate} className="flex items-center justify-between text-sm">
                    <span className="font-mono text-xs text-ink-muted">{plate}</span>
                    <span className="text-xs text-ink-caption">{status}</span>
                  </li>
                ))}
              </ul>
              <div className="mt-5 grid grid-cols-2 gap-3 border-t border-line-subtle pt-4">
                <div>
                  <p className="text-xs text-ink-caption">Due services</p>
                  <p className="font-display text-xl font-semibold">2</p>
                </div>
                <div>
                  <p className="text-xs text-ink-caption">Pending alerts</p>
                  <p className="font-display text-xl font-semibold">0</p>
                </div>
              </div>
            </div>
            <p className="text-xs text-ink-caption">Fleet portal preview</p>
          </div>
        </div>
      </section>

      {/* Challenges */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow="The challenges"
          title={FLEET_CHALLENGES.heading}
          intro={FLEET_CHALLENGES.intro}
          align="left"
        />
        <div className="mt-10 grid gap-4 sm:grid-cols-2">
          {FLEET_CHALLENGES.items.map((item) => (
            <article key={item.title} className="rounded-lg border border-line-subtle bg-card p-6">
              <h3 className="font-display text-lg font-semibold tracking-tight">{item.title}</h3>
              <p className="mt-2 text-sm leading-6 text-ink-muted">{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      {/* Steps */}
      <section className="border-y border-line bg-panel">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
          <SectionHeading
            eyebrow="Get started"
            title="Your workspace is ready in 3 simple steps"
            intro="Fleet onboarding is guided from the first call."
          />
          <div className="mt-10">
            <StepList items={FLEET_STEPS} />
          </div>
          <div className="mt-10 flex flex-col items-center gap-2">
            <ContactSalesLink className="inline-flex h-11 items-center rounded-md bg-btn-primary px-6 text-sm font-semibold text-on-gold transition-colors duration-150 hover:bg-btn-primary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus" />
            <p className="text-xs text-ink-caption">No credit card — we start with a conversation.</p>
          </div>
        </div>
      </section>

      {/* Modules */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow="System modules"
          title="Everything your fleet needs, in one place"
        />
        <div className="mt-10">
          <FeatureGrid items={FLEET_MODULES} />
        </div>
      </section>

      {/* Benefits */}
      <section className="border-y border-line bg-panel">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
          <SectionHeading
            eyebrow="Benefits"
            title="Results that impact your bottom line"
          />
          <div className="mt-10">
            <BenefitList items={FLEET_BENEFITS} />
          </div>
        </div>
      </section>

      {/* Comparison */}
      <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <SectionHeading
          eyebrow="Spreadsheets vs AutoX"
          title={FLEET_COMPARISON.heading}
        />
        <div className="mt-10 overflow-hidden rounded-xl border border-line-subtle bg-card">
          <div className="grid grid-cols-2 border-b border-line bg-panel">
            <div className="px-5 py-3 text-xs font-medium uppercase tracking-wide text-ink-faint">
              Manual control
            </div>
            <div className="border-l border-line px-5 py-3 text-xs font-medium uppercase tracking-wide text-gold">
              With AutoX
            </div>
          </div>
          {FLEET_COMPARISON.rows.map((row) => (
            <div key={row.manual} className="grid grid-cols-2 border-b border-line-subtle last:border-0">
              <div className="px-5 py-4 text-sm text-ink-muted">{row.manual}</div>
              <div className="border-l border-line-subtle px-5 py-4 text-sm text-ink">{row.dco}</div>
            </div>
          ))}
        </div>
      </section>

      {/* Industries */}
      <section className="border-y border-line bg-panel">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
          <SectionHeading
            eyebrow="For companies in every industry"
            title="Built for operations that run on vehicles"
          />
          <div className="mt-10 flex flex-wrap justify-center gap-3">
            {FLEET_INDUSTRIES.map((industry) => (
              <span
                key={industry}
                className="rounded-full border border-line-subtle bg-card px-4 py-2 text-sm text-ink-muted"
              >
                {industry}
              </span>
            ))}
          </div>
        </div>
      </section>

      <CtaBanner
        title="Take control of your fleet"
        subtitle="Talk to us about your operation and we will set up your organization workspace."
        showBadges={false}
        primary={{ href: FLEET_CONTACT_EMAIL ? `mailto:${FLEET_CONTACT_EMAIL}` : "/faq#fleet", label: "Contact sales" }}
        secondary={{ href: "/pricing", label: "See pricing" }}
      />
    </>
  );
}
