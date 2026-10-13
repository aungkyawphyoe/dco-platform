import Link from "next/link";
import { StoreBadges } from "./store-badges";
import { Reveal } from "./reveal";

type CtaBannerProps = {
  title: string;
  subtitle?: string;
  showBadges?: boolean;
  primary?: { href: string; label: string };
  secondary?: { href: string; label: string };
};

export function CtaBanner({ title, subtitle, showBadges = true, primary, secondary }: CtaBannerProps) {
  return (
    <section className="border-t border-line">
      <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-20">
        <Reveal className="surface relative overflow-hidden rounded-2xl px-6 py-14 text-center sm:px-12 sm:py-16">
          <div aria-hidden="true" className="bg-aurora pointer-events-none absolute inset-0 mask-fade-strong" />
          <div aria-hidden="true" className="pointer-events-none absolute -right-16 -top-16 h-56 w-56 rounded-full bg-gold/10 blur-3xl" />
          <div className="relative flex flex-col items-center gap-6">
            <h2 className="max-w-2xl font-display text-3xl font-semibold leading-tight tracking-tight sm:text-4xl">
              {title}
            </h2>
            {subtitle && <p className="max-w-xl text-base leading-7 text-ink-muted sm:text-lg">{subtitle}</p>}
            {(primary || secondary) && (
              <div className="flex flex-wrap items-center justify-center gap-3">
                {primary && (
                  <Link
                    href={primary.href}
                    className="btn-gloss inline-flex h-11 items-center rounded-full px-7 text-sm font-semibold"
                  >
                    {primary.label}
                  </Link>
                )}
                {secondary && (
                  <Link
                    href={secondary.href}
                    className="surface card-hover inline-flex h-11 items-center rounded-full px-7 text-sm font-semibold text-ink"
                  >
                    {secondary.label}
                  </Link>
                )}
              </div>
            )}
            {showBadges && <StoreBadges className="justify-center" />}
          </div>
        </Reveal>
      </div>
    </section>
  );
}
