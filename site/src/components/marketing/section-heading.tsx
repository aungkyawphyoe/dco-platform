import { Reveal } from "./reveal";

type SectionHeadingProps = {
  eyebrow?: string;
  title: string;
  intro?: string;
  align?: "left" | "center";
};

export function SectionHeading({ eyebrow, title, intro, align = "center" }: SectionHeadingProps) {
  const alignment = align === "center" ? "items-center text-center" : "items-start text-left";
  return (
    <Reveal className={`flex flex-col gap-3 ${alignment}`}>
      {eyebrow && (
        <span className="text-xs font-medium uppercase tracking-widest text-gold">{eyebrow}</span>
      )}
      <h2 className="max-w-3xl font-display text-3xl font-semibold leading-tight tracking-tight sm:text-4xl">
        {title}
      </h2>
      {intro && <p className="max-w-2xl text-base leading-7 text-ink-muted sm:text-lg">{intro}</p>}
    </Reveal>
  );
}
