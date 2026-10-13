import Link from "next/link";

type PathItem = {
  href: string;
  badge: string;
  title: string;
  description: string;
  bullets: readonly string[];
  cta: string;
};

export function PathCards({ items }: { items: readonly PathItem[] }) {
  return (
    <div className="grid gap-4 md:grid-cols-2">
      {items.map((item) => (
        <Link
          key={item.href}
          href={item.href}
          className="group flex flex-col gap-4 rounded-xl border border-line-subtle bg-card p-7 transition-colors duration-150 hover:border-gold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
        >
          <span className="w-fit rounded-full border border-line-subtle bg-panel px-3 py-1 text-xs font-medium text-ink-caption">
            {item.badge}
          </span>
          <div>
            <h3 className="font-display text-2xl font-semibold tracking-tight group-hover:text-gold">
              {item.title}
            </h3>
            <p className="mt-2 text-sm leading-6 text-ink-muted">{item.description}</p>
          </div>
          <ul className="space-y-2">
            {item.bullets.map((bullet) => (
              <li key={bullet} className="flex items-start gap-2 text-sm text-ink-muted">
                <svg
                  aria-hidden="true"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  className="mt-0.5 h-4 w-4 shrink-0 text-gold"
                >
                  <path
                    fillRule="evenodd"
                    d="M16.7 5.3a1 1 0 0 1 0 1.4l-7.5 7.5a1 1 0 0 1-1.4 0l-3.5-3.5a1 1 0 1 1 1.4-1.4l2.8 2.8 6.8-6.8a1 1 0 0 1 1.4 0Z"
                    clipRule="evenodd"
                  />
                </svg>
                {bullet}
              </li>
            ))}
          </ul>
          <span className="mt-auto inline-flex items-center gap-1.5 pt-2 text-sm font-semibold text-gold">
            {item.cta}
            <svg aria-hidden="true" viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4 transition-transform duration-150 group-hover:translate-x-0.5">
              <path d="M7.3 4.7a1 1 0 0 1 1.4 0l5 5a1 1 0 0 1 0 1.4l-5 5a1 1 0 0 1-1.4-1.4L10.6 11H4a1 1 0 1 1 0-2h6.6L7.3 6.1a1 1 0 0 1 0-1.4Z" />
            </svg>
          </span>
        </Link>
      ))}
    </div>
  );
}
