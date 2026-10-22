import type { Metadata } from "next";
import { PRIVACY_DOC } from "@/content/privacy";
import { LegalPage } from "@/components/legal/legal-page";
import { CtaBanner } from "@/components/marketing/cta-banner";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "How AutoX collects, uses and protects your information across the mobile apps, fleet portal and website — including data sharing, retention, cookies and your rights.",
};

export default function PrivacyPage() {
  return (
    <>
      <LegalPage doc={PRIVACY_DOC} />
      <CtaBanner
        title="Start with zero commitment"
        subtitle="The free plan includes your first vehicles, records and reminders."
        primary={{ href: "/pricing", label: "See pricing" }}
        secondary={{ href: "/faq", label: "Visit the help center" }}
        showBadges={false}
      />
    </>
  );
}
