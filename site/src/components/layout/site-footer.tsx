import Image from "next/image";
import Link from "next/link";
import { NAV_LINKS } from "@/content/site";

const PLATFORMS = [
  { label: "Android", note: "Google Play" },
  { label: "iOS", note: "App Store" },
] as const;

export function SiteFooter() {
  return (
    <footer className="border-t border-line bg-panel">
      <div className="mx-auto max-w-6xl px-4 py-12 sm:px-6">
        <div className="flex flex-col gap-10 md:flex-row md:justify-between">
          <div className="max-w-sm">
            <div className="flex items-center gap-2.5">
              <Image src="/dco-logo.png" alt="DCO" width={28} height={28} className="rounded-sm" />
              <span className="font-display text-lg font-semibold tracking-tight">DCO</span>
            </div>
            <p className="mt-3 text-sm leading-6 text-ink-muted">
              Digital Car Ownership — the digital garage for every vehicle you own. Track fuel, maintenance and
              costs, offline-first.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-8 sm:grid-cols-3">
            <div>
              <h3 className="text-xs font-medium uppercase tracking-wide text-ink-faint">Product</h3>
              <ul className="mt-3 space-y-2.5">
                {NAV_LINKS.map((link) => (
                  <li key={link.href}>
                    <Link href={link.href} className="text-sm text-ink-muted transition-colors duration-150 hover:text-gold">
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <h3 className="text-xs font-medium uppercase tracking-wide text-ink-faint">Platforms</h3>
              <ul className="mt-3 space-y-2.5">
                {PLATFORMS.map((platform) => (
                  <li key={platform.label} className="text-sm text-ink-muted">
                    {platform.label} <span className="text-ink-faint">· {platform.note}</span>
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <h3 className="text-xs font-medium uppercase tracking-wide text-ink-faint">Company</h3>
              <ul className="mt-3 space-y-2.5">
                <li>
                  <Link href="/faq" className="text-sm text-ink-muted transition-colors duration-150 hover:text-gold">
                    Help center
                  </Link>
                </li>
                <li className="text-sm text-ink-faint">Terms of Service</li>
                <li className="text-sm text-ink-faint">Privacy Policy</li>
              </ul>
            </div>
          </div>
        </div>

        <div className="mt-10 border-t border-line pt-6">
          <p className="text-xs text-ink-faint">© {new Date().getFullYear()} DCO. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}
