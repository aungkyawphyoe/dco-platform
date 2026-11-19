import type { Metadata } from "next";
import { getSiteCopy } from "@/i18n/dictionary";
import Link from "next/link";
import { GarageArt } from "@/components/marketing/garage-art";
import { RecordList } from "@/components/marketing/record-list";
import { StepList } from "@/components/marketing/step-list";
import { CtaBanner } from "@/components/marketing/cta-banner";
import { BrowserFrame } from "@/components/marketing/browser-frame";

export async function generateMetadata(): Promise<Metadata> {
  const { d } = await getSiteCopy();
  return {
    title: d.meta.pages.fleet.title,
    description: d.meta.pages.fleet.description,
  };
}

export default async function FleetPage() {
  const { d } = await getSiteCopy();
  const f = d.fleet;
  const moduleBands = [
    { pair: [0, 1], art: "checklist" }, { pair: [2, 4], art: "workshop" },
    { pair: [3, 7], art: "dossier" }, { pair: [5, 6], art: "receipt" },
  ] as const;
  return <>
    <section className="frame-section paired route-hero fleet-hero">
      <div>
        <span className="scope-label">{f.hero.eyebrow} / {f.hero.badge}</span>
        <h1>{f.hero.title}</h1><p className="intro">{f.hero.subtitle}</p>
        <ul className="bullet-list">{f.hero.bullets.map(item => <li key={item}>{item}</li>)}</ul>
        <div className="actions"><Link className="action" href="/demo">{f.hero.requestDemo}</Link>
          <Link className="action secondary" href="/pricing">{f.hero.seePricing}</Link></div>
        <p className="fine-print">{f.hero.noSignup}</p>
      </div>
      <BrowserFrame src={{dark:"/screenshots/portal-dashboard-dark.webp",light:"/screenshots/portal-dashboard-light.webp"}}
        alt={f.hero.browserAlt} label={f.hero.browserLabel} priority />
    </section>
    <section className="frame-section paired"><div><h2>{f.challenges.heading}</h2><p className="intro">{f.challenges.intro}</p></div>
      <RecordList items={f.challenges.items} /></section>
    <section className="frame-section paired"><h2>{f.benefitsSection.title}</h2><RecordList items={f.benefits} /></section>
    <section className="frame-section"><h2>{f.stepsSection.title}</h2><p className="intro">{f.stepsSection.intro}</p>
      <div className="my-8"><StepList items={f.steps} /></div>
      <Link className="action" href="/demo">{f.hero.requestDemo}</Link><p className="fine-print">{f.stepsSection.note}</p>
    </section>
    <section className="frame-section"><h2>{f.modulesSection.title}</h2>
      {moduleBands.map(({pair, art}) => <div key={art} className="feature-band">
        <RecordList items={pair.map(i => f.modules[i])} /><GarageArt kind={art} />
      </div>)}
    </section>
    <section className="frame-section"><h2 id="fleet-comparison">{f.comparison.title}</h2>
      <table className="fleet-comparison" aria-labelledby="fleet-comparison">
        <thead><tr><th scope="col">{f.comparison.manual}</th><th scope="col">{f.comparison.dco}</th></tr></thead>
        <tbody>{f.comparison.rows.map(row => <tr key={row.manual}><td>{row.manual}</td><td>{row.dco}</td></tr>)}</tbody>
      </table>
    </section>
    <section className="frame-section paired"><h2>{f.industriesSection.title}</h2>
      <ul className="industry-list">{f.industries.map(item => <li key={item}>{item}</li>)}</ul>
    </section>
    <CtaBanner title={f.cta.title} subtitle={f.cta.subtitle} primary={{href:"/demo",label:f.cta.primary}}
      secondary={{href:"/pricing",label:f.cta.secondary}} badgeLabels={d.storeBadges} showBadges={false} />
  </>;
}
