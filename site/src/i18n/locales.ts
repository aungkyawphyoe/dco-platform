export const LOCALES = ["en", "my"] as const;

export type Locale = (typeof LOCALES)[number];

export const DEFAULT_LOCALE: Locale = "en";

/** Cookie that stores the visitor's language preference. */
export const LOCALE_COOKIE = "dco_locale";

export function isLocale(value: string | undefined | null): value is Locale {
  return value === "en" || value === "my";
}
