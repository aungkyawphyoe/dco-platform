import { cardTone } from "@/lib/tone";
import { Reveal } from "./reveal";

type AudienceItem = {
  title: string;
  bullets: readonly string[];
};

export function AudienceGrid({ items }: { items: readonly AudienceItem[] }) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {items.map((item, index) => (
        <Reveal key={item.title} delay={index * 70} className="h-full">
          <article className={`surface card-grad card-hover h-full rounded-xl p-6 ${cardTone(index)}`}>
            <h3 className="font-display text-lg font-semibold tracking-tight">{item.title}</h3>
            <ul className="mt-3 space-y-2">
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
          </article>
        </Reveal>
      ))}
    </div>
  );
}
