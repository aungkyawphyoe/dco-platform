"use client";

/** Native buttons keep every history reachable with Tab, Enter, and Space. */
export function HistoryNavigation({
  label,
  options,
  value,
  onChange
}: {
  label: string;
  options: { value: string; label: string }[];
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <nav
      aria-label={label}
      className="flex flex-wrap gap-x-6 gap-y-1 border-b border-line-strong"
    >
      {options.map(option => (
        <button
          key={option.value}
          type="button"
          aria-current={value === option.value ? "page" : undefined}
          onClick={() => onChange(option.value)}
          className={`min-h-12 border-b-2 px-1 py-3 text-sm font-medium focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus ${
            value === option.value
              ? "border-gold text-gold"
              : "border-transparent text-ink-muted hover:border-line-strong hover:text-ink"
          }`}
        >
          {option.label}
        </button>
      ))}
    </nav>
  );
}
