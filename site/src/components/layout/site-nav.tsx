"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { NAV_LINKS } from "@/content/site";
import { ThemeToggle } from "./theme-toggle";

export function SiteNav() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  return (
    <header className="fixed inset-x-0 top-0 z-40 px-3 pt-3 sm:px-4 sm:pt-4">
      <div className="glass shadow-float mx-auto flex h-16 max-w-6xl items-center justify-between gap-4 rounded-full px-4 sm:px-5">
        <Link
          href="/"
          className="flex items-center gap-2.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
          onClick={() => setOpen(false)}
        >
          <Image src="/logo.png" alt="AutoX" width={30} height={30} className="rounded-sm" />
          <span className="font-display text-lg font-semibold tracking-tight">AutoX</span>
        </Link>

        <nav aria-label="Primary" className="hidden items-center gap-1 md:flex">
          {NAV_LINKS.map((link) => {
            const active = pathname === link.href;
            return (
              <Link
                key={link.href}
                href={link.href}
                aria-current={active ? "page" : undefined}
                className={`rounded-full px-4 py-1.5 text-sm font-medium transition-[color,background-color,box-shadow] duration-200 ease-out-soft focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus ${
                  active
                    ? "btn-gloss shadow-glow"
                    : "text-ink-muted hover:bg-ink/[0.05] hover:text-ink"
                }`}
              >
                {link.label}
              </Link>
            );
          })}
        </nav>

        <div className="flex items-center gap-2">
          <ThemeToggle />
          <Link
            href="/#download"
            className="btn-gloss hidden h-9 items-center rounded-full px-5 text-sm font-semibold sm:inline-flex"
          >
            Get the app
          </Link>
          <button
            type="button"
            aria-expanded={open}
            aria-controls="mobile-nav"
            aria-label={open ? "Close menu" : "Open menu"}
            onClick={() => setOpen((v) => !v)}
            className="flex h-9 w-9 items-center justify-center rounded-full border border-line-strong text-ink-muted transition-colors duration-200 ease-out-soft hover:border-gold/40 hover:text-gold md:hidden focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
          >
            <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="h-5 w-5">
              {open ? <path d="M6 6l12 12M18 6L6 18" strokeLinecap="round" /> : <path d="M4 7h16M4 12h16M4 17h16" strokeLinecap="round" />}
            </svg>
          </button>
        </div>
      </div>

      {open && (
        <nav
          id="mobile-nav"
          aria-label="Primary mobile"
          className="glass shadow-float mx-auto mt-2 max-w-6xl rounded-2xl px-3 py-3 backdrop-blur-xl md:hidden"
        >
          {NAV_LINKS.map((link) => {
            const active = pathname === link.href;
            return (
              <Link
                key={link.href}
                href={link.href}
                aria-current={active ? "page" : undefined}
                onClick={() => setOpen(false)}
                className={`block rounded-full px-4 py-2.5 text-base font-medium transition-colors duration-150 ${
                  active ? "btn-gloss shadow-glow" : "text-ink-muted hover:text-ink"
                }`}
              >
                {link.label}
              </Link>
            );
          })}
          <Link
            href="/#download"
            onClick={() => setOpen(false)}
            className="btn-gloss mt-2 flex h-11 items-center justify-center rounded-full px-4 text-sm font-semibold"
          >
            Get the app
          </Link>
        </nav>
      )}
    </header>
  );
}
