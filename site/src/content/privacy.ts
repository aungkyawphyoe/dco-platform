import type { LegalDoc } from "./legal";
import { emailLink } from "./legal";

export const PRIVACY_DOC: LegalDoc = {
  eyebrow: "Legal",
  title: "Privacy Policy",
  intro: "How AutoX collects, uses and protects your information across the apps, portal and website.",
  lastUpdated: "October 22, 2026",
  lede: [
    'Welcome to AutoX! We value your privacy and are committed to protecting your personal data. This Privacy Policy explains how AutoX ("we," "us," or "our") collects, uses, processes and protects information when you use our website, our mobile applications for Android and iOS, the AutoX web fleet portal, and any related services (collectively, the "Service").',
    "By using the Service, you consent to the collection and use of information described below.",
  ],
  sections: [
    {
      id: "information",
      title: "Information we collect",
      nav: "Data we collect",
      blocks: [
        {
          type: "p",
          text: "We collect only the data needed to run your digital garage:",
        },
        {
          type: "list",
          items: [
            {
              label: "Account information",
              text: "Your name, email address and profile settings when you register, plus the Google or Apple identifiers used if you sign in with a social account. Passwords are stored only as salted one-way hashes.",
            },
            {
              label: "Vehicle and records data",
              text: "Vehicle make, model, year, mileage logs, fuel and charging entries, maintenance and service history, expenses, insurance and registration details, and any photos or PDFs (receipts, invoices, policies) you attach to a vehicle.",
            },
            {
              label: "Shared and fleet data",
              text: "Vehicles you share with other people, and — for organizations — vehicles, work orders, inspections and reports your organization manages. People you share with can see the records shared with them.",
            },
            {
              label: "Reminder preferences",
              text: "The maintenance and renewal reminders you configure, by date or mileage.",
            },
            {
              label: "Technical and usage data",
              text: "IP address, device type, app and operating system version, request timestamps, and crash or diagnostic logs — used for security, monitoring and error tracking.",
            },
            {
              label: "Payment details",
              text: "Processed by our payment providers and the app stores. We do not store raw credit card numbers on our servers.",
            },
          ],
        },
      ],
    },
    {
      id: "use",
      title: "How we use your information",
      nav: "How we use it",
      blocks: [
        {
          type: "p",
          text: "We process your data to operate and improve the Service, specifically to:",
        },
        {
          type: "list",
          items: [
            {
              label: "Run your account",
              text: "Identify you, store your records and sync them across your devices — the app works offline and keeps a local copy on your device that synchronises when you are online.",
            },
            {
              label: "Reminders",
              text: "Deliver the maintenance and renewal notifications you configure.",
            },
            {
              label: "Billing",
              text: "Process payments and manage active subscriptions.",
            },
            {
              label: "Support and improvement",
              text: "Respond to requests, monitor and improve application performance, fix bugs and secure our systems.",
            },
            {
              label: "Legal compliance",
              text: "Meet obligations required by applicable law.",
            },
          ],
        },
      ],
    },
    {
      id: "sharing",
      title: "How we share your information",
      nav: "Sharing",
      blocks: [
        {
          type: "p",
          text: "We do not sell, rent or trade your personal data. We disclose it only to trusted vendors essential to running the Service:",
        },
        {
          type: "list",
          items: [
            {
              label: "Cloud infrastructure",
              text: "Microsoft Azure hosts the Service (Azure Container Apps, PostgreSQL database) and stores uploaded documents and photos (Azure Blob Storage).",
            },
            {
              label: "Payment providers",
              text: "2C2P, MyanmarPay, KBZPay, AYA Pay and Wave Money for MMK payments; Stripe for USD card payments; Google Play and Apple App Store billing for in-app subscriptions.",
            },
            {
              label: "Email delivery",
              text: "Azure Communication Services sends service emails such as verification codes, password resets and invitations.",
            },
            {
              label: "People you share with",
              text: "Other users you share a vehicle with, and members of your organization, can access the records shared with them.",
            },
            {
              label: "Legal compliance",
              text: "If required by law, we may disclose information to comply with valid legal process or to protect the rights and safety of the Service and its users.",
            },
          ],
        },
      ],
    },
    {
      id: "retention",
      title: "Data retention and deletion",
      nav: "Retention",
      blocks: [
        {
          type: "p",
          text: "We retain your personal data and vehicle records only as long as your account remains active or as needed to provide the Service. You can delete your account at any time from the app's Settings; deletion permanently removes your data and cannot be recovered. Data we are legally required to keep (for example, financial records) is retained only for as long as the law obliges.",
        },
      ],
    },
    {
      id: "rights",
      title: "Your data protection rights",
      nav: "Your rights",
      blocks: [
        {
          type: "p",
          text: "Depending on where you live, applicable data protection laws may give you the right to access, correct, delete or export a copy of your personal data, to object to or restrict certain processing, and to withdraw consent at any time for features that rely on optional data. You can view, correct and export much of your data directly in the app, and delete your account in Settings. To exercise any other right, contact us at ",
          link: emailLink(),
        },
      ],
    },
    {
      id: "cookies",
      title: "Cookies and local storage",
      nav: "Cookies",
      blocks: [
        {
          type: "p",
          text: "The AutoX website stores a single cookie (dco_theme) to remember your light or dark theme preference; it contains no personal information. We do not use advertising or cross-site tracking cookies. Authenticated surfaces use session cookies to keep you signed in, and the mobile app keeps an offline copy of your data in local storage on your device.",
        },
      ],
    },
    {
      id: "children",
      title: "Children's privacy",
      blocks: [
        {
          type: "p",
          text: "The Service is not directed at children under 16, and we do not knowingly collect personal information from them. If we learn that a child under 16 has provided us with personal information, we will take prompt steps to delete it.",
        },
      ],
    },
    {
      id: "security",
      title: "Security",
      blocks: [
        {
          type: "p",
          text: "We protect your data with measures appropriate to the risk: HTTPS encryption in transit, bcrypt-hashed passwords, short-lived JWT sessions, role-based access control, and server-side authorisation so that each user can only access their own vehicles and organizations. No method of transmission or storage is completely secure, and we cannot guarantee absolute security.",
        },
      ],
    },
    {
      id: "updates",
      title: "Updates to this privacy policy",
      nav: "Updates",
      blocks: [
        {
          type: "p",
          text: "We may periodically update this Privacy Policy to reflect product changes or regulatory requirements. Material changes will be announced in the app or by email. Your continued use of the Service after an update constitutes acceptance of the revised policy.",
        },
      ],
    },
    {
      id: "contact",
      title: "Contact us",
      nav: "Contact",
      blocks: [
        {
          type: "p",
          text: "If you have any questions about this Privacy Policy or how we handle your data, please contact us at ",
          link: emailLink(),
        },
      ],
    },
  ],
  footnote: "By using AutoX, you consent to the terms of this Privacy Policy.",
};
