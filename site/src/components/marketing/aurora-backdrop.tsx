type AuroraBackdropProps = {
  /** Full-bleed symmetric dot grid over the gradient (hero treatment). */
  dots?: boolean;
  /** Symmetric floating glow orbs (hero treatment). */
  orbs?: boolean;
  className?: string;
};

/**
 * Layered ambient background: symmetric gradient wash (`.bg-aurora`), optional
 * edge-to-edge dot grid, optional glow orbs. Parent must be
 * `relative isolate overflow-hidden`; content should follow this element in
 * DOM order so it paints above.
 */
export function AuroraBackdrop({ dots = false, orbs = false, className = "" }: AuroraBackdropProps) {
  return (
    <div aria-hidden="true" className={`pointer-events-none absolute inset-0 -z-10 ${className}`}>
      <div className="bg-aurora absolute inset-0 mask-fade-strong opacity-95" />
      {dots && <div className="bg-dots absolute inset-0 mask-fade-hero opacity-90" />}
      {orbs && (
        <>
          <div className="animate-float-slow absolute left-[6%] top-10 h-40 w-40 rounded-full bg-gold/10 blur-3xl sm:top-16" />
          <div className="animate-float absolute right-[6%] top-10 h-40 w-40 rounded-full bg-info/10 blur-3xl [animation-delay:-3s] sm:top-16" />
        </>
      )}
    </div>
  );
}
