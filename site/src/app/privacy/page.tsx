import type { Metadata } from "next";
import { PRIVACY_DOC } from "@/content/privacy";
import { getSiteCopy } from "@/i18n/dictionary";
import { LegalPage } from "@/components/legal/legal-page";
import { CtaBanner } from "@/components/marketing/cta-banner";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "How AutoX collects, uses and protects your information across the mobile apps, fleet portal and website — including data sharing, retention, cookies and your rights.",
};

export default async function PrivacyPage() {
  const { d } = await getSiteCopy();
  const cta = d.legalCta.privacy;

  return (
    <>
      <LegalPage doc={PRIVACY_DOC} />
      <CtaBanner
        title={cta.title}
        subtitle={cta.subtitle}
        primary={{ href: "/pricing", label: cta.primary }}
        secondary={{ href: "/faq", label: cta.secondary }}
        showBadges={false}
        badgeLabels={d.storeBadges}
      />
    </>
  );
}
