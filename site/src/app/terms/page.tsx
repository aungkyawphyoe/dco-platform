import type { Metadata } from "next";
import { TERMS_DOC } from "@/content/terms";
import { getSiteCopy } from "@/i18n/dictionary";
import { LegalPage } from "@/components/legal/legal-page";
import { CtaBanner } from "@/components/marketing/cta-banner";

export const metadata: Metadata = {
  title: "Terms of Service",
  description:
    "The terms that govern your use of AutoX — the mobile apps, fleet portal and website, including accounts, billing, refunds and acceptable use.",
};

export default async function TermsPage() {
  const { d } = await getSiteCopy();
  const cta = d.legalCta.terms;

  return (
    <>
      <LegalPage doc={TERMS_DOC} />
      <CtaBanner
        title={cta.title}
        subtitle={cta.subtitle}
        primary={{ href: "/pricing", label: cta.primary }}
        secondary={{ href: "/#download", label: cta.secondary }}
        badgeLabels={d.storeBadges}
      />
    </>
  );
}
