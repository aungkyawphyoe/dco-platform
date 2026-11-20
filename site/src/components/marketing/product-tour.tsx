"use client";

import { HighlightedTitle } from "@/components/marketing/highlighted-title";
import { useId, useRef, useState, type KeyboardEvent } from "react";
import type { Dictionary } from "@/i18n/types";
import { ScreenDetail } from "./screen-detail";

const subjects = ["dashboard", "fuel", "maintenance"] as const;

export function ProductTour({ copy }: { copy: Dictionary["home"]["showcaseSection"] }) {
  const [index, setIndex] = useState(0);
  const tabs = useRef<(HTMLButtonElement | null)[]>([]);
  const id = useId();
  const subject = subjects[index];
  function navigate(event: KeyboardEvent, current: number) {
    if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
    const directions: Record<string, number> = {
      ArrowDown: (current + 1) % subjects.length, ArrowUp: (current + subjects.length - 1) % subjects.length,
      Home: 0, End: subjects.length - 1,
    };
    const next = directions[event.key];
    if (next === undefined) return;
    event.preventDefault();
    setIndex(next);
    tabs.current[next]?.focus();
  }
  return (
    <section className="frame-section tour">
      <div>
        <h2><span className="section-label">{copy.eyebrow}</span><HighlightedTitle title={copy.title} highlight={copy.titleHighlight} /></h2>
        <p className="intro">{copy.intro}</p>
        <div className="tour-tabs" role="tablist" aria-orientation="vertical" aria-label={copy.title}>
          {subjects.map((item, i) => (
            <button key={item} ref={el => { tabs.current[i] = el; }} role="tab" id={id + item}
              aria-selected={i === index} aria-controls={id + "-panel"} tabIndex={i === index ? 0 : -1}
              onClick={() => setIndex(i)} onKeyDown={e => navigate(e, i)}>
              {copy[`${item}Label`]}<span aria-hidden="true">{i === index ? "−" : "+"}</span>
            </button>
          ))}
        </div>
      </div>
      <div role="tabpanel" id={id + "-panel"} aria-labelledby={id + subject} tabIndex={0} className="tour-stage">
        <ScreenDetail subject={subject} alt={copy[`${subject}Alt`]} />
        <p>{copy[`${subject}Caption`]}</p>
      </div>
    </section>
  );
}
