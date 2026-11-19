"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { NAV_ITEMS } from "@/content/site";
import type { Locale } from "@/i18n/locales";
import type { Dictionary } from "@/i18n/types";
import { LanguageToggle } from "./language-toggle";
import { ThemeToggle } from "./theme-toggle";

type SiteNavProps = {
  locale: Locale;
  labels: Dictionary["nav"];
  language: Dictionary["language"];
  theme: Dictionary["theme"];
};

export function SiteNav({ locale, labels, language, theme }: SiteNavProps) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  const menuButton = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    if (!open) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setOpen(false);
        menuButton.current?.focus();
      }
    }
    const close = () => setOpen(false);
    document.addEventListener("keydown", onKey);
    window.addEventListener("popstate", close);
    return () => {
      document.removeEventListener("keydown", onKey);
      window.removeEventListener("popstate", close);
    };
  }, [open]);

  function navLink(href: string, label: string) {
    return <Link key={href} href={href} aria-current={pathname === href ? "page" : undefined}
      onClick={() => setOpen(false)}>{label}</Link>;
  }
  return (
    <header className="site-header">
      <div className="nav-rail">
        <Link href="/" className="wordmark" onClick={() => setOpen(false)}>
          <Image src="/logo.png" alt="" width={32} height={32} />AutoX
        </Link>
        <nav className="desktop-links" aria-label={labels.primaryAria}>
          {NAV_ITEMS.map(item => navLink(item.href, labels.links[item.key]))}
        </nav>
        <div className="nav-tools">
          <LanguageToggle locale={locale} labels={language} />
          <ThemeToggle labels={theme} />
          <Link href="/demo" className="action nav-demo" aria-current={pathname === "/demo" ? "page" : undefined}>{labels.requestDemo}</Link>
          <button type="button" ref={menuButton} className="menu-toggle" aria-expanded={open}
            aria-controls="mobile-nav" aria-label={open ? labels.closeMenu : labels.openMenu}
            onClick={() => setOpen(!open)}>{open ? "×" : "☰"}</button>
        </div>
      </div>
      <nav id="mobile-nav" hidden={!open} aria-label={labels.mobileAria} className="mobile-links">
        {navLink("/", labels.home)}
        {NAV_ITEMS.map(item => navLink(item.href, labels.links[item.key]))}
        {navLink("/demo", labels.requestDemo)}
      </nav>
    </header>
  );
}
