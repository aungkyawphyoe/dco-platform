import { cookies } from "next/headers";
import { DEFAULT_LOCALE, isLocale, LOCALE_COOKIE, type Locale } from "./locales";
import type { Dictionary } from "./types";
import en from "./dictionaries/en.json";
import my from "./dictionaries/my.json";

/**
 * Fills empty translations from the English catalogue, recursively. Arrays are
 * merged item-by-item so a partially translated list still renders.
 */
function merge<T>(base: T, override: unknown): T {
  if (typeof base === "string") {
    return (typeof override === "string" && override.trim() ? override : base) as T;
  }

  if (Array.isArray(base)) {
    if (!Array.isArray(override)) return base;
    return base.map((item, index) => merge(item, override[index])) as T;
  }

  if (base && typeof base === "object") {
    const result = { ...(base as Record<string, unknown>) };
    if (override && typeof override === "object") {
      const values = override as Record<string, unknown>;
      for (const key of Object.keys(result)) {
        result[key] = merge(result[key], values[key]);
      }
    }
    return result as T;
  }

  return base;
}

export function getDictionary(locale: Locale): Dictionary {
  if (locale === DEFAULT_LOCALE) return en;
  return merge(en, my);
}

export async function getLocale(): Promise<Locale> {
  const store = await cookies();
  const value = store.get(LOCALE_COOKIE)?.value;
  return isLocale(value) ? value : DEFAULT_LOCALE;
}

/** Locale plus the merged dictionary, for server components and metadata. */
export async function getSiteCopy(): Promise<{ locale: Locale; d: Dictionary }> {
  const locale = await getLocale();
  return { locale, d: getDictionary(locale) };
}
