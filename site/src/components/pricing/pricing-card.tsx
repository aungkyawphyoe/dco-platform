import Link from "next/link";
import { cardTone } from "@/lib/tone";
import {
  formatMmk,
  formatStorage,
  formatUsd,
  type BillingPeriod,
  type PricingPlan,
} from "@/lib/pricing";

type PricingCardProps = {
  plan: PricingPlan;
  period: BillingPeriod;
  index: number;
};

function badgeFor(plan: PricingPlan): string | null {
  if (plan.highlighted) return "Most popular";
  if (plan.audience === "fleet") return "For business";
  if (plan.id === "free") return null;
  return null;
}

export function PricingCard({ plan, period, index }: PricingCardProps) {
  const money = plan.prices[period];
  const badge = badgeFor(plan);
  const highlighted = plan.highlighted;

  return (
    <article
      className={`surface card-grad relative flex h-full flex-col gap-5 rounded-xl p-6 ${
        highlighted ? "tone-gold border-gold shadow-glow" : `card-hover ${cardTone(index)}`
      }`}
    >
      {badge && (
        <span
          className={`absolute -top-3 left-6 ${
            highlighted ? "btn-gloss rounded-full px-3 py-1 text-xs font-semibold" : "pill pill-info"
          }`}
        >
          {badge}
        </span>
      )}

      <header className="flex flex-col gap-1">
        <h3 className="font-display text-xl font-semibold tracking-tight">{plan.name}</h3>
        <p className="text-sm text-ink-muted">{plan.tagline}</p>
      </header>

      <div className="flex items-baseline gap-2">
        <span className="font-display text-4xl font-semibold tracking-tight">{formatMmk(money.mmk)}</span>
        <span className="text-sm text-ink-faint">/ {period === "monthly" ? "month" : "year"}</span>
      </div>
      <p className="-mt-3 text-xs text-ink-caption">
        {formatUsd(money.usd)} {period === "monthly" ? "/ month" : "/ year"} · billed {period === "annual" ? "yearly" : "monthly"}
      </p>

      <ul className="flex flex-col gap-2.5 border-t border-line-subtle pt-4">
        {plan.features.map((feature) => (
          <li key={feature} className="flex items-start gap-2 text-sm text-ink-muted">
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
            {feature}
          </li>
        ))}
        <li className="flex items-start gap-2 text-sm text-ink-faint">
          <span aria-hidden="true" className="mt-0.5 w-4 shrink-0 text-center">·</span>
          {formatStorage(plan.limits.storage_bytes)} storage
        </li>
      </ul>

      <div className="mt-auto">
        {plan.audience === "fleet" ? (
          <Link
            href="/fleet"
            className="surface card-hover flex h-11 w-full items-center justify-center rounded-full text-sm font-semibold text-ink"
          >
            Explore fleet plans
          </Link>
        ) : (
          <Link
            href={plan.id === "free" ? "/personal" : "/#download"}
            className={`flex h-11 w-full items-center justify-center rounded-full text-sm font-semibold ${
              highlighted
                ? "btn-gloss"
                : "surface card-hover text-ink"
            }`}
          >
            {plan.id === "free" ? "Start free" : "Get the app"}
          </Link>
        )}
      </div>
    </article>
  );
}
