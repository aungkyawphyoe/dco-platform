import { APP_STORE_URL, PLAY_STORE_URL } from "@/content/site";

type StoreBadgesProps = {
  className?: string;
  ariaLabel?: string;
};

/**
 * Badge-styled store buttons. Hrefs come from env placeholders until the
 * apps are published — without a URL they render as non-link badges with
 * pointer-events disabled is NOT applied, they keep href="#" so the
 * component shape stays identical when real URLs arrive.
 */
export function StoreBadges({ className = "", ariaLabel = "Download the app" }: StoreBadgesProps) {
  return (
    <div className={`flex flex-wrap items-center gap-3 ${className}`} role="group" aria-label={ariaLabel}>
      <a
        href={PLAY_STORE_URL}
        className="surface card-hover inline-flex h-12 items-center gap-3 rounded-full px-5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24" className="h-6 w-6" fill="currentColor">
          <path d="M3.6 2.3c-.3.3-.5.8-.5 1.4v16.6c0 .6.2 1.1.5 1.4l.1.1 9.3-9.3v-.2L3.7 2.3h-.1Zm12.5 6.4-2.2 2.2 2.2 2.2 5.1-3c.7-.4.7-1.1 0-1.5l-5.1-2.9v3Zm-3.2 3.2-9 9c.2.2.6.3 1 0l10.6-6.1-2.6-2.9Zm0-2.6 2.6-2.9L4.9 2.6c-.4-.2-.8-.2-1 0l9 9.1Z" />
        </svg>
        <span className="flex flex-col leading-tight">
          <span className="text-[10px] uppercase tracking-wide text-ink-faint">Get it on</span>
          <span className="font-display text-sm font-semibold text-ink">Google Play</span>
        </span>
      </a>
      <a
        href={APP_STORE_URL}
        className="surface card-hover inline-flex h-12 items-center gap-3 rounded-full px-5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24" className="h-6 w-6" fill="currentColor">
          <path d="M16.4 12.7c0-2.2 1.8-3.3 1.9-3.4-1-1.5-2.6-1.7-3.2-1.7-1.4-.1-2.7.8-3.4.8-.7 0-1.8-.8-3-.8-1.5 0-2.9.9-3.7 2.3-1.6 2.7-.4 6.8 1.1 9 .8 1.1 1.6 2.3 2.8 2.3 1.1 0 1.6-.7 2.9-.7 1.4 0 1.7.7 2.9.7 1.2 0 2-1.1 2.7-2.2.9-1.3 1.2-2.5 1.2-2.6-.1 0-2.2-.9-2.2-3.7ZM14.3 5.7c.6-.8 1-1.9.9-2.9-.9 0-2 .6-2.7 1.3-.6.7-1.1 1.8-.9 2.8 1 .1 2-.5 2.7-1.2Z" />
        </svg>
        <span className="flex flex-col leading-tight">
          <span className="text-[10px] uppercase tracking-wide text-ink-faint">Download on the</span>
          <span className="font-display text-sm font-semibold text-ink">App Store</span>
        </span>
      </a>
    </div>
  );
}
