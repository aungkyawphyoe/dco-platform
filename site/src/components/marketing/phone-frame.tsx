"use client";

import Image from "next/image";
import { useState } from "react";
import type { ResolvedTheme } from "@/lib/theme";
import { useResolvedTheme } from "@/lib/use-resolved-theme";

type ThemedScreenshot = Partial<Record<ResolvedTheme, string>>;

type PhoneFrameProps = {
  /** Caption rendered under the frame, e.g. the screen name. */
  label?: string;
  /** Ambient float loop (hero treatment). */
  float?: boolean;
  className?: string;
  ariaHidden?: boolean;
  /**
   * Screenshot path under `public/`, e.g. `/screenshots/app-dashboard.webp`,
   * or one path per theme — the frame follows the site theme toggle live.
   * While an asset is missing the skeleton interior renders instead, so the
   * frame is safe to ship before the screenshots land.
   */
  src?: string | ThemedScreenshot;
  alt?: string;
  /** Above-the-fold only; leave off for lazy-loaded showcase rows. */
  priority?: boolean;
};

const SKELETON_ROWS = [92, 74, 84, 66, 88, 70, 80, 58];

/**
 * Device-shaped frame for an app screenshot. Renders the provided image at the
 * asset's phone aspect ratio, falling back to the skeleton interior when the
 * asset is absent or fails to load.
 */
export function PhoneFrame({ label, float = false, className = "", ariaHidden, src, alt, priority }: PhoneFrameProps) {
  const theme = useResolvedTheme();
  const [failedSrc, setFailedSrc] = useState<string | null>(null);
  const path = typeof src === "string" ? src : src?.[theme] ?? src?.dark ?? null;
  const imageSrc = path && path !== failedSrc ? path : null;

  return (
    <figure className={`flex flex-col items-center gap-3 ${className}`}>
      <div
        aria-hidden={ariaHidden ? "true" : undefined}
        className={`glass relative w-[220px] rounded-[32px] p-2 shadow-float sm:w-[248px] ${float ? "animate-float" : ""}`}
      >
        <div className="surface relative overflow-hidden rounded-[26px]">
          <div className="bg-gold-wash absolute inset-x-0 top-0 h-28 opacity-80" />
          <div className="relative flex justify-center py-2">
            <span className="h-1.5 w-16 rounded-full bg-skeleton" />
          </div>
          {imageSrc ? (
            <div className="relative aspect-[500/1060] w-full overflow-hidden">
              <Image
                src={imageSrc}
                alt={alt ?? label ?? "App screenshot"}
                fill
                priority={priority}
                sizes="(min-width: 640px) 248px, 220px"
                className="object-cover object-top"
                onError={() => setFailedSrc(imageSrc)}
              />
            </div>
          ) : (
            <div className="relative space-y-3 px-4 pb-6">
              <div className="h-24 rounded-md bg-skeleton/80" />
              {SKELETON_ROWS.map((width, index) => (
                <div key={index} className="flex items-center gap-3">
                  <span className="h-8 w-8 shrink-0 rounded-md bg-skeleton" />
                  <span className="h-2.5 rounded-full bg-skeleton" style={{ width: `${width}%` }} />
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
      {label && <figcaption className="text-xs text-ink-caption">{label}</figcaption>}
    </figure>
  );
}
