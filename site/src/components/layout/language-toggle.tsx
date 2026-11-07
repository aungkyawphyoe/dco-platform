"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { LOCALE_COOKIE, type Locale } from "@/i18n/locales";
import type { Dictionary } from "@/i18n/types";

type LanguageToggleProps = {
  locale: Locale;
  labels: Dictionary["language"];
};

export function LanguageToggle({ locale, labels }: LanguageToggleProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function choose(next: Locale) {
    if (next === locale || pending) return;
    document.cookie = `${LOCALE_COOKIE}=${next}; path=/; max-age=31536000; samesite=lax`;
    document.documentElement.lang = next;
    startTransition(() => router.refresh());
  }

  const itemClass = (active: boolean) =>
    `rounded-full px-2.5 py-1.5 text-xs font-semibold transition-[color,background-color,box-shadow] duration-200 ease-out-soft focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus ${
      active ? "btn-gloss" : "text-ink-muted hover:text-ink"
    }`;

  return (
    <div
      role="group"
      aria-label={labels.group}
      aria-busy={pending || undefined}
      className="glass inline-flex h-9 items-center gap-0.5 rounded-full p-0.5"
    >
      <button
        type="button"
        lang="en"
        aria-pressed={locale === "en"}
        aria-label={labels.english}
        onClick={() => choose("en")}
        className={itemClass(locale === "en")}
      >
        {labels.englishShort}
      </button>
      <button
        type="button"
        lang="my"
        aria-pressed={locale === "my"}
        aria-label={labels.burmese}
        onClick={() => choose("my")}
        className={itemClass(locale === "my")}
      >
        {labels.burmeseShort}
      </button>
    </div>
  );
}
