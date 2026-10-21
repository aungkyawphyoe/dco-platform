"use client";

import { useEffect, useState } from "react";
import type { ResolvedTheme } from "@/lib/theme";

/**
 * Resolved site theme (`html.light` / `html.dark`) for components whose
 * rendering depends on it — theme-specific screenshot variants.
 *
 * Initial state matches the SSR default (dark), then syncs to the live class
 * so the nav ThemeToggle swaps the asset in place without a reload. The
 * pre-paint init script keeps the class authoritative even for system theme.
 */
export function useResolvedTheme(): ResolvedTheme {
  const [theme, setTheme] = useState<ResolvedTheme>("dark");

  useEffect(() => {
    const read = () => {
      const next = document.documentElement.classList.contains("light") ? "light" : "dark";
      setTheme((current) => (current === next ? current : next));
    };
    read();
    const observer = new MutationObserver(read);
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] });
    return () => observer.disconnect();
  }, []);

  return theme;
}
