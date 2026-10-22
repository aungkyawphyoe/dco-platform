import type { Metadata } from "next";
import { TERMS_DOC } from "@/content/terms";
import { LegalPage } from "@/components/legal/legal-page";
import { CtaBanner } from "@/components/marketing/cta-banner";

export const metadata: Metadata = {
  title: "Terms of Service",
  description:
    "The terms that govern your use of AutoX — the mobile apps, fleet portal and website, including accounts, billing, refunds and acceptable use.",
};

export default function TermsPage() {
  return (
    <>
      <LegalPage doc={TERMS_DOC} />
      <CtaBanner
        title="Ready to start?"
        subtitle="Start with the free plan and try AutoX with zero commitment."
        primary={{ href: "/pricing", label: "See pricing" }}
        secondary={{ href: "/#download", label: "Download the app" }}
      />
    </>
  );
}
