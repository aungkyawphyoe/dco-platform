import { Badge } from "./badge";

export function SectionHeading({
  title,
  count,
  children,
  className = "",
}: {
  title: string;
  count?: number;
  children?: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`flex flex-wrap items-center justify-between gap-2 border-b border-line-subtle px-5 py-4 ${className}`}
    >
      <div className="flex items-center gap-2">
        <h2 className="font-display text-base font-semibold text-ink">{title}</h2>
        {count !== undefined ? <Badge tone="neutral">{count}</Badge> : null}
      </div>
      {children}
    </div>
  );
}
