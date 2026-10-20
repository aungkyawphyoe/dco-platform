import Link from "next/link";

export function PageHeader({
  title,
  description,
  meta,
  status,
  backHref,
  backLabel = "Back",
  actions,
}: {
  title: string;
  description?: string;
  meta?: React.ReactNode;
  status?: React.ReactNode;
  backHref?: string;
  backLabel?: string;
  actions?: React.ReactNode;
}) {
  const subline = meta ?? description;
  return (
    <header className="flex flex-col gap-4">
      {backHref ? (
        <Link
          href={backHref}
          className="w-fit text-sm text-ink-caption transition-colors hover:text-ink"
        >
          {backLabel}
        </Link>
      ) : null}
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="flex flex-wrap items-center gap-3">
            <h1 className="font-display text-2xl font-semibold tracking-tight text-ink">
              {title}
            </h1>
            {status}
          </div>
          {subline ? (
            <p className="mt-1.5 text-sm text-ink-caption">{subline}</p>
          ) : null}
        </div>
        {actions ? (
          <div className="flex flex-wrap items-center gap-2">{actions}</div>
        ) : null}
      </div>
    </header>
  );
}
