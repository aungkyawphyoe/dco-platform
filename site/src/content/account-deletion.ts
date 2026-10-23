import type { LegalDoc } from "./legal";
import { emailLink } from "./legal";

export const ACCOUNT_DELETION_DOC: LegalDoc = {
  eyebrow: "Support",
  title: "Account and Data Deletion",
  intro: "How to delete your AutoX account, or delete specific data without closing your account.",
  lastUpdated: "October 22, 2026",
  lede: [
    "This page describes how to request deletion of your AutoX account on the Android and iOS apps, what happens to your data afterwards, and how to remove specific records without closing your account.",
  ],
  sections: [
    {
      id: "delete",
      title: "Delete your account",
      nav: "How to delete",
      blocks: [
        {
          type: "list",
          items: [
            {
              label: "In the app (Android and iOS)",
              text: "Go to Settings → Profile → Edit Profile → Delete Account, enter your password to confirm, and tap Delete. This is the fastest way.",
            },
            {
              label: "By request",
              text: "If you cannot access the app, email ",
              link: {
                ...emailLink(),
                after:
                  ' from your registered address, with the subject "Account deletion".',
              },
            },
          ],
        },
        {
          type: "p",
          text: "AutoX has no web version — account deletion is available in the mobile app only, or by email as described above.",
        },
      ],
    },
    {
      id: "happens",
      title: "What happens when you delete your account",
      nav: "What happens",
      blocks: [
        {
          type: "list",
          items: [
            {
              label: "Sign-in",
              text: "Your account is deactivated and you cannot sign in again on any device.",
            },
            {
              label: "Vehicles",
              text: "All your vehicles are archived together with their fuel, maintenance, expense and document history.",
            },
            {
              label: "Shares",
              text: "Vehicle shares you held on other people's vehicles are revoked, shares on your own vehicles are removed, and pending invitations are cancelled.",
            },
            {
              label: "Restore",
              text: "If you change your mind, contact us — your account can be restored, together with your archived vehicles.",
            },
          ],
        },
        {
          type: "p",
          text: "For full details on how we process personal data, see our ",
          link: { href: "/privacy", label: "Privacy Policy", after: "." },
        },
      ],
    },
    {
      id: "retained",
      title: "What is deleted and what is retained",
      nav: "Your data",
      blocks: [
        {
          type: "list",
          items: [
            {
              label: "Deleted when you delete your account",
              text: "Active sessions on your devices are revoked, your credentials can no longer be used to sign in, and all vehicle shares and invitations are removed.",
            },
            {
              label: "Retained",
              text: "Your profile, your vehicles and every record attached to them (fuel and charging logs, services, expenses, documents and photos) are retained after deactivation, so your account can be restored if you change your mind.",
            },
            {
              label: "Permanent erasure",
              text: "To have your personal data permanently erased instead, email ",
              link: {
                ...emailLink(),
                after: ' with the subject "Data deletion". We will remove your data and confirm once it is done.',
              },
            },
          ],
        },
      ],
    },
    {
      id: "subscriptions",
      title: "Subscriptions are not cancelled automatically",
      nav: "Subscriptions",
      blocks: [
        {
          type: "p",
          text: "Deleting your account does not cancel a recurring subscription. You remain responsible for cancelling any active subscription on the platform where it was purchased:",
        },
        {
          type: "list",
          items: [
            {
              label: "Google Play",
              text: "Play Store → Subscriptions → AutoX → Cancel subscription.",
            },
            {
              label: "App Store",
              text: "Settings → Apple Account → Subscriptions → AutoX → Cancel subscription.",
            },
            {
              label: "Direct payments",
              text: "Subscriptions paid with local payment methods or card are managed by us — email ",
              link: {
                ...emailLink(),
                after: " and we will cancel the subscription for you.",
              },
            },
          ],
        },
      ],
    },
    {
      id: "partial",
      title: "Delete data without closing your account",
      nav: "Partial deletion",
      blocks: [
        {
          type: "p",
          text: "You do not need to delete your entire account to remove data. Directly in the app you can:",
        },
        {
          type: "list",
          items: [
            {
              label: "Archive a vehicle",
              text: "Open the vehicle, tap Edit and choose “Archive vehicle”. The vehicle and its full history stop counting against your plan limits but remain stored.",
            },
            {
              label: "Delete a record",
              text: "Open the entry from History — fuel logs, service records and expenses can be deleted from their detail or edit screen, together with attached receipts.",
            },
            {
              label: "Delete a document",
              text: "Documents in a vehicle's vault can be deleted from the document's edit screen.",
            },
            {
              label: "By request",
              text: "If a particular deletion is not available in the app, email ",
              link: {
                ...emailLink(),
                after: ' with the subject "Data deletion".',
              },
            },
          ],
        },
      ],
    },
  ],
};
