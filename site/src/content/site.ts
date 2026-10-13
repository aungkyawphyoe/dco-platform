export const NAV_LINKS = [
  { href: "/personal", label: "Personal" },
  { href: "/fleet", label: "Fleet" },
  { href: "/pricing", label: "Pricing" },
  { href: "/faq", label: "FAQ" },
] as const;

export const APP_STORE_URL = process.env.NEXT_PUBLIC_APP_STORE_URL || "#";
export const PLAY_STORE_URL = process.env.NEXT_PUBLIC_PLAY_STORE_URL || "#";
export const FLEET_CONTACT_EMAIL = process.env.NEXT_PUBLIC_FLEET_CONTACT_EMAIL || "";
