type BenefitItem = {
  title: string;
  description: string;
};

export function BenefitList({ items }: { items: readonly BenefitItem[] }) {
  return (
    <div className="grid gap-4 sm:grid-cols-2">
      {items.map((item, index) => (
        <article key={item.title} className="flex gap-4 rounded-lg border border-line-subtle bg-card p-6">
          <span className="font-mono text-sm font-medium text-gold">{String(index + 1).padStart(2, "0")}</span>
          <div>
            <h3 className="font-display text-lg font-semibold tracking-tight">{item.title}</h3>
            <p className="mt-1.5 text-sm leading-6 text-ink-muted">{item.description}</p>
          </div>
        </article>
      ))}
    </div>
  );
}
