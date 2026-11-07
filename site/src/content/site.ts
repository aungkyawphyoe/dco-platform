export const NAV_ITEMS = [
  { href: "/personal", key: "personal" },
  { href: "/fleet", key: "fleet" },
  { href: "/pricing", key: "pricing" },
  { href: "/faq", key: "faq" },
] as const;

export const APP_STORE_URL = process.env.NEXT_PUBLIC_APP_STORE_URL || "#";
export const PLAY_STORE_URL = process.env.NEXT_PUBLIC_PLAY_STORE_URL || "#";
export const FLEET_CONTACT_EMAIL = process.env.NEXT_PUBLIC_FLEET_CONTACT_EMAIL || "";

/** Destination for demo requests when no form endpoint is configured. */
export const DEMO_REQUEST_EMAIL =
  process.env.NEXT_PUBLIC_DEMO_REQUEST_EMAIL || FLEET_CONTACT_EMAIL || "support@autoxmm.com";
