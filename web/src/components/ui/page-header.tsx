export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string;
  description?: string;
  actions?: React.ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-4 border-b border-line-subtle pb-5">
      <div>
        <h1 className="font-display text-2xl font-semibold tracking-tight text-ink">
          {title}
        </h1>
        {description ? (
          <p className="mt-1 text-sm text-ink-caption">{description}</p>
        ) : null}
      </div>
      {actions ? <div className="flex items-center gap-2">{actions}</div> : null}
    </div>
  );
}
