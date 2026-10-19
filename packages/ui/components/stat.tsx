/// A labelled figure. Numerals are set in the mono face by default.
export function Stat({
  label,
  value,
  hint,
  mono = true,
  className = "",
}: {
  label: string;
  value: React.ReactNode;
  hint?: string;
  mono?: boolean;
  className?: string;
}) {
  return (
    <div className={className}>
      <p className="text-xs text-ink-caption">{label}</p>
      <p className={`mt-1 text-sm text-ink ${mono ? "font-mono" : ""}`}>{value}</p>
      {hint ? <p className="mt-0.5 text-xs text-ink-faint">{hint}</p> : null}
    </div>
  );
}
