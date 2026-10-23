import type { Metadata } from "next";
import { ACCOUNT_DELETION_DOC } from "@/content/account-deletion";
import { LegalPage } from "@/components/legal/legal-page";

export const metadata: Metadata = {
  title: "Account Deletion",
  description:
    "How to delete your AutoX account from the mobile app or by request — what is deleted, what is retained, and how to remove specific data without closing your account.",
};

export default function AccountDeletionPage() {
  return <LegalPage doc={ACCOUNT_DELETION_DOC} />;
}
