import type { Metadata } from "next";
import { DEMO_REQUEST_EMAIL } from "@/content/site";
import { getSiteCopy } from "@/i18n/dictionary";
import type { Dictionary } from "@/i18n/types";
import { AuroraBackdrop } from "@/components/marketing/aurora-backdrop";
import { Reveal } from "@/components/marketing/reveal";
import { DemoForm } from "@/components/demo/demo-form";

export async function generateMetadata(): Promise<Metadata> {
  const { d } = await getSiteCopy();
  return {
    title: d.meta.pages.demo.title,
    description: d.meta.pages.demo.description,
  };
}

function RouteMap({ labels }: { labels: Dictionary["demo"]["route"] }) {
  return (
    <div aria-hidden="true" className="mt-10 hidden select-none lg:block">
      <svg viewBox="0 0 420 152" fill="none" className="w-full text-gold">
        <path
          pathLength={1}
          d="M70 116C112 116 132 36 210 36S308 116 350 116"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinecap="round"
          className="route-line"
        />
        <g className="route-node" style={{ animationDelay: "0.55s" }}>
          <circle cx="70" cy="116" r="10" fill="currentColor" opacity="0.14" />
          <circle cx="70" cy="116" r="3.5" fill="currentColor" />
        </g>
        <g className="route-node" style={{ animationDelay: "0.8s" }}>
          <circle cx="210" cy="36" r="10" fill="currentColor" opacity="0.14" />
          <circle cx="210" cy="36" r="3.5" fill="currentColor" />
        </g>
        <g className="route-node" style={{ animationDelay: "1.05s" }}>
          <circle cx="350" cy="116" r="10" fill="currentColor" opacity="0.14" />
          <circle cx="350" cy="116" r="3.5" fill="currentColor" />
        </g>
      </svg>
      <div className="mt-1 grid grid-cols-3 gap-4 text-center">
        <div>
          <p className="font-display text-sm font-semibold tracking-tight">{labels.vehicles.title}</p>
          <p className="mt-0.5 font-mono text-[11px] text-ink-faint">{labels.vehicles.note}</p>
        </div>
        <div>
          <p className="font-display text-sm font-semibold tracking-tight">{labels.drivers.title}</p>
          <p className="mt-0.5 font-mono text-[11px] text-ink-faint">{labels.drivers.note}</p>
        </div>
        <div>
          <p className="font-display text-sm font-semibold tracking-tight">{labels.reports.title}</p>
          <p className="mt-0.5 font-mono text-[11px] text-ink-faint">{labels.reports.note}</p>
        </div>
      </div>
    </div>
  );
}

export default async function DemoPage() {
  const { d } = await getSiteCopy();
  const demo = d.demo;

  return (
    <section className="relative isolate flex min-h-svh flex-col overflow-hidden pt-20 sm:pt-24">
      <AuroraBackdrop dots orbs />
      <div className="mx-auto grid w-full max-w-6xl items-start gap-10 px-4 py-10 sm:px-6 sm:py-14 lg:grid-cols-[0.92fr_1.08fr] lg:gap-14 lg:py-16">
        <div className="lg:sticky lg:top-28">
          <Reveal>
            <span className="pill pill-gold">{demo.eyebrow}</span>
          </Reveal>
          <Reveal delay={70}>
            <h1 className="mt-5 max-w-lg font-display text-4xl font-semibold leading-[1.08] tracking-tight sm:text-5xl">
              {demo.title}
            </h1>
          </Reveal>
          <Reveal delay={140}>
            <p className="mt-5 max-w-md text-base leading-7 text-ink-muted sm:text-lg">
              {demo.subtitle}
            </p>
          </Reveal>

          <Reveal delay={210}>
            <RouteMap labels={demo.route} />
          </Reveal>

          <Reveal delay={280}>
            <ul className="mt-10 hidden max-w-md space-y-5 border-t border-line pt-8 lg:block">
              {demo.proof.map((item) => (
                <li key={item.title} className="flex gap-3">
                  <span className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-gold/15 text-gold">
                    <svg aria-hidden="true" viewBox="0 0 20 20" fill="currentColor" className="h-3 w-3">
                      <path
                        fillRule="evenodd"
                        d="M16.7 5.3a1 1 0 0 1 0 1.4l-7.5 7.5a1 1 0 0 1-1.4 0l-3.5-3.5a1 1 0 1 1 1.4-1.4l2.8 2.8 6.8-6.8a1 1 0 0 1 1.4 0Z"
                        clipRule="evenodd"
                      />
                    </svg>
                  </span>
                  <div>
                    <p className="text-sm font-medium text-ink">{item.title}</p>
                    <p className="mt-0.5 text-sm leading-6 text-ink-muted">{item.description}</p>
                  </div>
                </li>
              ))}
            </ul>
          </Reveal>

          <Reveal delay={340}>
            <p className="mt-8 hidden text-sm leading-6 text-ink-muted lg:block">
              {demo.preferEmail}{" "}
              <a
                href={`mailto:${DEMO_REQUEST_EMAIL}`}
                className="font-medium text-gold underline underline-offset-2 hover:no-underline"
              >
                {DEMO_REQUEST_EMAIL}
              </a>
            </p>
          </Reveal>
        </div>

        <Reveal delay={120} className="w-full">
          <DemoForm copy={demo.form} />
        </Reveal>
      </div>
    </section>
  );
}
