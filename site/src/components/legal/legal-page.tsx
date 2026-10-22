import Link from "next/link";
import type { LegalBlock, LegalDoc, LegalLink } from "@/content/legal";
import { pillTone } from "@/lib/tone";
import { AuroraBackdrop } from "@/components/marketing/aurora-backdrop";
import { SectionHeading } from "@/components/marketing/section-heading";

function LegalTextLink({ link }: { link: LegalLink }) {
  const className =
    "font-medium text-gold underline decoration-gold/40 underline-offset-4 transition-colors duration-150 hover:decoration-gold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus";
  const content = (
    <>
      {link.label}
      {link.after ?? ""}
    </>
  );
  if (link.href.startsWith("mailto:")) {
    return (
      <a href={link.href} className={className}>
        {content}
      </a>
    );
  }
  return (
    <Link href={link.href} className={className}>
      {content}
    </Link>
  );
}

function LegalBlockView({ block }: { block: LegalBlock }) {
  if (block.type === "list") {
    return (
      <ul className="mt-4 space-y-3">
        {block.items.map((item, index) => (
          <li
            key={index}
            className="flex gap-3 text-sm leading-6 text-ink-muted sm:text-base sm:leading-7"
          >
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-gold" />
            <span>
              {item.label && <span className="font-medium text-ink">{item.label}: </span>}
              {item.text}
              {item.link && <LegalTextLink link={item.link} />}
            </span>
          </li>
        ))}
      </ul>
    );
  }
  return (
    <p className="mt-4 max-w-3xl text-sm leading-7 text-ink-muted sm:text-base">
      {block.text}
      {block.link && <LegalTextLink link={block.link} />}
    </p>
  );
}

export function LegalPage({ doc }: { doc: LegalDoc }) {
  return (
    <>
      <section className="relative isolate overflow-hidden border-b border-line">
        <AuroraBackdrop dots />
        <div className="mx-auto max-w-4xl px-4 pb-14 pt-24 sm:px-6 sm:pb-16 sm:pt-28">
          <SectionHeading eyebrow={doc.eyebrow} title={doc.title} intro={doc.intro} />
          <p className="mt-5 text-center text-xs uppercase tracking-widest text-ink-faint">
            Last updated {doc.lastUpdated}
          </p>
          <nav aria-label={`${doc.title} sections`} className="mt-8 flex flex-wrap justify-center gap-2">
            {doc.sections.map((section, index) => (
              <a
                key={section.id}
                href={`#${section.id}`}
                className={`pill ${pillTone(index)} px-4 py-1.5 text-sm transition-[filter,transform] duration-200 ease-out-soft hover:-translate-y-0.5 hover:brightness-110 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2                 focus-visible:outline-focus`}
              >
                {section.nav ?? section.title}
              </a>
            ))}
          </nav>
        </div>
      </section>

      <div className="mx-auto max-w-4xl px-4 py-12 sm:px-6 sm:py-16">
        <div className="flex flex-col gap-3">
          {doc.lede.map((text) => (
            <p key={text} className="text-sm leading-7 text-ink-muted sm:text-base">
              {text}
            </p>
          ))}
        </div>

        <div className="mt-10 flex flex-col gap-10">
          {doc.sections.map((section, index) => (
            <section key={section.id} id={section.id} className="scroll-mt-24">
              <h2 className="font-display text-xl font-semibold tracking-tight sm:text-2xl">
                <span aria-hidden="true" className="mr-2 text-gold">
                  {index + 1}.
                </span>
                {section.title}
              </h2>
              {section.blocks.map((block, blockIndex) => (
                <LegalBlockView key={blockIndex} block={block} />
              ))}
            </section>
          ))}
        </div>

        {doc.footnote && (
          <p className="mt-12 border-t border-line pt-6 text-sm leading-6 text-ink-faint">
            {doc.footnote}
          </p>
        )}
      </div>
    </>
  );
}
