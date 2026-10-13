type PhoneFrameProps = {
  /** Caption rendered under the frame, e.g. the screen name. */
  label?: string;
  /** Skeleton line widths (percent) for the placeholder content. */
  className?: string;
  ariaHidden?: boolean;
};

const SKELETON_ROWS = [92, 74, 84, 66, 88, 70, 80, 58];

/**
 * Device-shaped placeholder for an app screenshot. Real screenshots will
 * replace the skeleton interior later; the frame itself stays stable.
 */
export function PhoneFrame({ label, className = "", ariaHidden }: PhoneFrameProps) {
  return (
    <figure className={`flex flex-col items-center gap-3 ${className}`}>
      <div
        aria-hidden={ariaHidden ? "true" : undefined}
        className="relative w-[220px] rounded-[28px] border border-line-strong bg-card p-2 shadow-lg sm:w-[248px]"
      >
        <div className="relative overflow-hidden rounded-[22px] bg-panel">
          <div className="flex justify-center py-2">
            <span className="h-1.5 w-16 rounded-full bg-skeleton" />
          </div>
          <div className="space-y-3 px-4 pb-6">
            <div className="h-24 rounded-md bg-skeleton" />
            {SKELETON_ROWS.map((width, index) => (
              <div key={index} className="flex items-center gap-3">
                <span className="h-8 w-8 shrink-0 rounded-md bg-skeleton" />
                <span className="h-2.5 rounded-full bg-skeleton" style={{ width: `${width}%` }} />
              </div>
            ))}
          </div>
        </div>
      </div>
      {label && <figcaption className="text-xs text-ink-caption">{label}</figcaption>}
    </figure>
  );
}
