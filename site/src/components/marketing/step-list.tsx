type StepItem = {
  title: string;
  description: string;
};

export function StepList({ items }: { items: readonly StepItem[] }) {
  return (
    <ol className="grid gap-6 sm:grid-cols-3">
      {items.map((item, index) => (
        <li key={item.title} className="flex flex-col gap-3">
          <span className="flex h-10 w-10 items-center justify-center rounded-full border border-gold/40 bg-panel font-display text-base font-semibold text-gold">
            {index + 1}
          </span>
          <div>
            <h3 className="font-display text-lg font-semibold tracking-tight">{item.title}</h3>
            <p className="mt-1.5 text-sm leading-6 text-ink-muted">{item.description}</p>
          </div>
        </li>
      ))}
    </ol>
  );
}
