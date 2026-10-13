import type { FaqCategory } from "@/content/faq";

export function FaqCategorySection({ category }: { category: FaqCategory }) {
  return (
    <section id={category.id} className="scroll-mt-24">
      <h2 className="font-display text-2xl font-semibold tracking-tight">{category.label}</h2>
      <div className="mt-4 divide-y divide-line rounded-xl border border-line-subtle bg-card">
        {category.items.map((item) => (
          <details key={item.q} className="group px-5 py-4">
            <summary className="flex cursor-pointer list-none items-start justify-between gap-4 text-base font-medium text-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus [&::-webkit-details-marker]:hidden">
              {item.q}
              <svg
                aria-hidden="true"
                viewBox="0 0 20 20"
                fill="currentColor"
                className="mt-1 h-4 w-4 shrink-0 text-ink-faint transition-transform duration-150 group-open:rotate-45"
              >
                <path d="M10 4a1 1 0 0 1 1 1v4h4a1 1 0 1 1 0 2h-4v4a1 1 0 1 1-2 0v-4H5a1 1 0 1 1 0-2h4V5a1 1 0 0 1 1-1Z" />
              </svg>
            </summary>
            <p className="mt-3 max-w-3xl text-sm leading-6 text-ink-muted">{item.a}</p>
          </details>
        ))}
      </div>
    </section>
  );
}
