export type ThemeMode = "light" | "dark" | "system";
export type ResolvedTheme = "light" | "dark";

export const THEME_COOKIE = "dco_theme";
export const THEME_MODES: readonly ThemeMode[] = ["light", "dark", "system"] as const;

export function parseThemeMode(raw: string | null | undefined): ThemeMode {
  return raw === "light" || raw === "dark" ? raw : "system";
}

/**
 * Class rendered on <html> during SSR. An explicit cookie choice wins;
 * system/missing defaults to dark, and the pre-paint script corrects it
 * to prefers-color-scheme before first paint (no flash).
 */
export function themeClassFromCookie(raw: string | null | undefined): ResolvedTheme {
  const mode = parseThemeMode(raw);
  return mode === "system" ? "dark" : mode;
}

/**
 * Inlined at the top of <body>. Runs before first paint so the html class,
 * color-scheme, and CSS variables match the cookie (or OS preference) even
 * when the server could not know the system theme.
 */
export const THEME_INIT_SCRIPT = `(function(){try{var m=/(?:^|;\\s*)${THEME_COOKIE}=([^;]+)/.exec(document.cookie);var t=m?decodeURIComponent(m[1]):"system";if(t!=="light"&&t!=="dark"){t=window.matchMedia("(prefers-color-scheme: light)").matches?"light":"dark";}var e=document.documentElement;e.classList.remove("light","dark");e.classList.add(t);e.style.colorScheme=t;}catch(e){}})();`;
