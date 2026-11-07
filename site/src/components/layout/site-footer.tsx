import Image from "next/image";
import Link from "next/link";
import { NAV_ITEMS } from "@/content/site";
import type { Dictionary } from "@/i18n/types";

type SiteFooterProps = {
  labels: Dictionary["footer"];
  navLabels: Dictionary["nav"]["links"];
};

export function SiteFooter({ labels, navLabels }: SiteFooterProps) {
  return (
    <footer className="border-t border-line bg-panel">
      <div className="mx-auto max-w-6xl px-4 py-12 sm:px-6">
        <div className="flex flex-col gap-10 md:flex-row md:justify-between">
          <div className="max-w-sm">
            <div className="flex items-center gap-2.5">
              <Image src="/logo.png" alt="AutoX" width={28} height={28} className="rounded-sm" />
              <span className="font-display text-lg font-semibold tracking-tight">AutoX</span>
            </div>
            <p className="mt-3 text-sm leading-6 text-ink-muted">{labels.tagline}</p>
          </div>

          <div className="grid grid-cols-2 gap-8 sm:grid-cols-3">
            <div>
              <h3 className="text-xs font-medium uppercase tracking-wide text-ink-faint">{labels.product}</h3>
              <ul className="mt-3 space-y-2.5">
                {NAV_ITEMS.map((link) => (
                  <li key={link.href}>
                    <Link href={link.href} className="text-sm text-ink-muted transition-colors duration-150 hover:text-gold">
                      {navLabels[link.key]}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <h3 className="text-xs font-medium uppercase tracking-wide text-ink-faint">{labels.platforms}</h3>
              <ul className="mt-3 space-y-2.5">
                <li className="text-sm text-ink-muted">
                  {labels.android} <span className="text-ink-faint">· {labels.googlePlay}</span>
                </li>
                <li className="text-sm text-ink-muted">
                  {labels.ios} <span className="text-ink-faint">· {labels.appStore}</span>
                </li>
              </ul>
            </div>
            <div>
              <h3 className="text-xs font-medium uppercase tracking-wide text-ink-faint">{labels.company}</h3>
              <ul className="mt-3 space-y-2.5">
                <li>
                  <Link href="/demo" className="text-sm text-ink-muted transition-colors duration-150 hover:text-gold">
                    {labels.requestDemo}
                  </Link>
                </li>
                <li>
                  <Link href="/faq" className="text-sm text-ink-muted transition-colors duration-150 hover:text-gold">
                    {labels.helpCenter}
                  </Link>
                </li>
                <li>
                  <Link href="/terms" className="text-sm text-ink-muted transition-colors duration-150 hover:text-gold">
                    {labels.terms}
                  </Link>
                </li>
                <li>
                  <Link href="/privacy" className="text-sm text-ink-muted transition-colors duration-150 hover:text-gold">
                    {labels.privacy}
                  </Link>
                </li>
                <li>
                  <Link href="/account-deletion" className="text-sm text-ink-muted transition-colors duration-150 hover:text-gold">
                    {labels.deleteAccount}
                  </Link>
                </li>
              </ul>
            </div>
          </div>
        </div>

        <div className="mt-10 border-t border-line pt-6">
          <p className="text-xs text-ink-faint">
            {labels.rights.replace("{year}", String(new Date().getFullYear()))}
          </p>
        </div>
      </div>
    </footer>
  );
}
