import { Reveal } from "./reveal";

type FeatureItem = {
  title: string;
  description: string;
  chips?: readonly string[];
};

export function FeatureGrid({ items }: { items: readonly FeatureItem[] }) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {items.map((item, index) => (
        <Reveal key={item.title} delay={index * 70} className="h-full">
          <article className="surface card-hover flex h-full flex-col gap-3 rounded-xl p-6">
            <h3 className="font-display text-xl font-semibold tracking-tight">{item.title}</h3>
            <p className="text-sm leading-6 text-ink-muted">{item.description}</p>
            {item.chips && (
              <div className="mt-auto flex flex-wrap gap-2 pt-2">
                {item.chips.map((chip) => (
                  <span
                    key={chip}
                    className="rounded-full bg-panel px-2.5 py-1 text-xs text-ink-caption"
                  >
                    {chip}
                  </span>
                ))}
              </div>
            )}
          </article>
        </Reveal>
      ))}
    </div>
  );
}
