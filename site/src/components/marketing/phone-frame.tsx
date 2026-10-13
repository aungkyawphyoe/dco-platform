type PhoneFrameProps = {
  /** Caption rendered under the frame, e.g. the screen name. */
  label?: string;
  /** Ambient float loop (hero treatment). */
  float?: boolean;
  className?: string;
  ariaHidden?: boolean;
};

const SKELETON_ROWS = [92, 74, 84, 66, 88, 70, 80, 58];

/**
 * Device-shaped placeholder for an app screenshot. Real screenshots will
 * replace the skeleton interior later; the frame itself stays stable.
 */
export function PhoneFrame({ label, float = false, className = "", ariaHidden }: PhoneFrameProps) {
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
          <div className="relative space-y-3 px-4 pb-6">
            <div className="h-24 rounded-md bg-skeleton/80" />
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
