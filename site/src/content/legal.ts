export type LegalLink = { href: string; label: string; after?: string };

export type LegalBlock =
  | { type: "p"; text: string; link?: LegalLink }
  | { type: "list"; items: LegalItem[] };

export type LegalItem = { label?: string; text: string; link?: LegalLink };

export type LegalSection = {
  id: string;
  title: string;
  /** Short label for the anchor pill navigation; defaults to `title`. */
  nav?: string;
  blocks: LegalBlock[];
};

export type LegalDoc = {
  eyebrow: string;
  title: string;
  intro: string;
  lastUpdated: string;
  lede: string[];
  sections: LegalSection[];
  footnote?: string;
};

export const SUPPORT_EMAIL = process.env.NEXT_PUBLIC_SUPPORT_EMAIL || "support@autoxmm.com";

export function emailLink(label = SUPPORT_EMAIL): LegalLink {
  return { href: `mailto:${SUPPORT_EMAIL}`, label };
}
