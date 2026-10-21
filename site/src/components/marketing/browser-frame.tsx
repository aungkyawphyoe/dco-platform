"use client";

import Image from "next/image";
import { useState } from "react";
import type { ResolvedTheme } from "@/lib/theme";
import { useResolvedTheme } from "@/lib/use-resolved-theme";

type ThemedScreenshot = Partial<Record<ResolvedTheme, string>>;

type BrowserFrameProps = {
  /** Caption rendered under the frame, e.g. the page name. */
  label?: string;
  className?: string;
  /**
   * Screenshot path under `public/`, e.g. `/screenshots/portal-dashboard-light.webp`,
   * or one path per theme — the frame follows the site theme toggle live.
   * While an asset is missing the wireframe interior renders instead.
   */
  src?: string | ThemedScreenshot;
  alt?: string;
  /** Above-the-fold only; leave off for lazy-loaded showcase rows. */
  priority?: boolean;
};

/**
 * Browser-chromed frame for a fleet portal screenshot. Falls back to a
 * wireframe interior when the asset is absent or fails to load.
 */
export function BrowserFrame({ label, className = "", src, alt, priority }: BrowserFrameProps) {
  const theme = useResolvedTheme();
  const [failedSrc, setFailedSrc] = useState<string | null>(null);
  const path = typeof src === "string" ? src : src?.[theme] ?? src?.dark ?? null;
  const imageSrc = path && path !== failedSrc ? path : null;

  return (
    <figure className={`flex w-full flex-col items-center gap-3 ${className}`}>
      <div className="glass w-full max-w-2xl rounded-2xl p-2 shadow-float">
        <div className="surface relative overflow-hidden rounded-xl">
          <div className="flex items-center gap-2 border-b border-line-subtle px-3 py-2">
            <span className="h-2.5 w-2.5 rounded-full bg-skeleton" />
            <span className="h-2.5 w-2.5 rounded-full bg-skeleton" />
            <span className="h-2.5 w-2.5 rounded-full bg-skeleton" />
            <span className="ml-2 h-5 flex-1 rounded-md bg-skeleton/70" />
          </div>
          {imageSrc ? (
            <div className="relative aspect-[16/10] w-full overflow-hidden">
              <Image
                src={imageSrc}
                alt={alt ?? label ?? "Fleet portal screenshot"}
                fill
                priority={priority}
                sizes="(min-width: 1024px) 672px, 100vw"
                className="object-cover object-top"
                onError={() => setFailedSrc(imageSrc)}
              />
            </div>
          ) : (
            <div className="space-y-3 p-4">
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                {[0, 1, 2, 3].map((index) => (
                  <div key={index} className="rounded-md bg-skeleton/80 p-3">
                    <span className="block h-2 w-12 rounded-full bg-skeleton" />
                    <span className="mt-2 block h-5 w-16 rounded-full bg-skeleton/80" />
                  </div>
                ))}
              </div>
              <div className="h-40 rounded-md bg-skeleton/60" />
              <div className="grid gap-2 sm:grid-cols-2">
                <div className="h-16 rounded-md bg-skeleton/70" />
                <div className="h-16 rounded-md bg-skeleton/70" />
              </div>
            </div>
          )}
        </div>
      </div>
      {label && <figcaption className="text-xs text-ink-caption">{label}</figcaption>}
    </figure>
  );
}
