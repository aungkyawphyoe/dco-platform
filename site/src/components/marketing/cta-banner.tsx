import Link from "next/link";
import { StoreBadges } from "./store-badges";

type CtaBannerProps = {
  title: string;
  subtitle?: string;
  showBadges?: boolean;
  primary?: { href: string; label: string };
  secondary?: { href: string; label: string };
};

export function CtaBanner({ title, subtitle, showBadges = true, primary, secondary }: CtaBannerProps) {
  return (
    <section className="border-t border-line bg-panel">
      <div className="mx-auto flex max-w-6xl flex-col items-center gap-6 px-4 py-16 text-center sm:px-6 sm:py-20">
        <h2 className="max-w-2xl font-display text-3xl font-semibold leading-tight tracking-tight sm:text-4xl">
          {title}
        </h2>
        {subtitle && <p className="max-w-xl text-base leading-7 text-ink-muted sm:text-lg">{subtitle}</p>}
        {(primary || secondary) && (
          <div className="flex flex-wrap items-center justify-center gap-3">
            {primary && (
              <Link
                href={primary.href}
                className="inline-flex h-11 items-center rounded-md bg-btn-primary px-6 text-sm font-semibold text-on-gold transition-colors duration-150 hover:bg-btn-primary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
              >
                {primary.label}
              </Link>
            )}
            {secondary && (
              <Link
                href={secondary.href}
                className="inline-flex h-11 items-center rounded-md border border-line-strong bg-card px-6 text-sm font-semibold text-ink transition-colors duration-150 hover:bg-skeleton focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
              >
                {secondary.label}
              </Link>
            )}
          </div>
        )}
        {showBadges && <StoreBadges className="justify-center" />}
      </div>
    </section>
  );
}
