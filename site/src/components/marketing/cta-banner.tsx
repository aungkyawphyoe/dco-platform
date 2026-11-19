import Link from "next/link";
import type { Dictionary } from "@/i18n/types";
import { StoreBadges } from "./store-badges";

type CtaBannerProps = {
  title: string;
  subtitle?: string;
  showBadges?: boolean;
  primary?: { href: string; label: string };
  secondary?: { href: string; label: string };
  badgeLabels: Dictionary["storeBadges"];
};

export function CtaBanner({
  title,
  subtitle,
  showBadges = true,
  primary,
  secondary,
  badgeLabels,
}: CtaBannerProps) {
  return (
    <section className="closing">
      <h2>{title}</h2>
      {subtitle && <p>{subtitle}</p>}
      <div className="actions">
        {primary && <Link className="action" href={primary.href}>{primary.label}</Link>}
        {secondary && <Link className="action secondary" href={secondary.href}>{secondary.label}</Link>}
      </div>
      {showBadges && <StoreBadges labels={badgeLabels} />}
    </section>
  );
}
