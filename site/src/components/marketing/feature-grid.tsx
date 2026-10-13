type FeatureItem = {
  title: string;
  description: string;
  chips?: readonly string[];
};

export function FeatureGrid({ items }: { items: readonly FeatureItem[] }) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {items.map((item) => (
        <article
          key={item.title}
          className="flex flex-col gap-3 rounded-lg border border-line-subtle bg-card p-6 transition-colors duration-150 hover:border-line-strong"
        >
          <h3 className="font-display text-xl font-semibold tracking-tight">{item.title}</h3>
          <p className="text-sm leading-6 text-ink-muted">{item.description}</p>
          {item.chips && (
            <div className="mt-auto flex flex-wrap gap-2 pt-2">
              {item.chips.map((chip) => (
                <span
                  key={chip}
                  className="rounded-full border border-line-subtle bg-panel px-2.5 py-1 text-xs text-ink-caption"
                >
                  {chip}
                </span>
              ))}
            </div>
          )}
        </article>
      ))}
    </div>
  );
}
