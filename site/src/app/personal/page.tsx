import type { Metadata } from "next";
import { getSiteCopy } from "@/i18n/dictionary";
import Link from "next/link";
import { GarageArt } from "@/components/marketing/garage-art";
import { RecordList } from "@/components/marketing/record-list";
import { StepList } from "@/components/marketing/step-list";
import { CtaBanner } from "@/components/marketing/cta-banner";
import { PhoneFrame } from "@/components/marketing/phone-frame";
import { ScreenDetail } from "@/components/marketing/screen-detail";

export async function generateMetadata(): Promise<Metadata> {
  const { d } = await getSiteCopy();
  return {
    title: d.meta.pages.personal.title,
    description: d.meta.pages.personal.description,
  };
}

export default async function PersonalPage() {
  const { d } = await getSiteCopy();
  const p = d.personal;
  const tour = d.home.showcaseSection;
  return <>
    <section className="frame-section paired route-hero">
      <div>
        <span className="scope-label">{p.hero.eyebrow} / {p.hero.badge}</span>
        <h1>{p.hero.title}</h1><p className="intro">{p.hero.subtitle}</p>
        <ul className="bullet-list">{p.hero.bullets.map(item => <li key={item}>{item}</li>)}</ul>
        <Link href="/#download" className="action">{p.cta.secondary}</Link>
      </div>
      <PhoneFrame src={{dark: "/screenshots/app-garage-dark.webp", light: "/screenshots/app-garage-light.webp"}}
        alt={p.hero.phoneAlt} label={p.hero.phoneLabel} priority />
    </section>
    <section className="frame-section paired">
      <div><h2>{p.problem.heading}</h2><p className="intro">{p.problem.intro}</p></div>
      <RecordList items={p.problem.items} />
    </section>
    <section className="frame-section paired">
      <div><h2>{p.solution.heading}</h2><p className="intro">{p.solution.intro}</p>
        <ul className="bullet-list">{p.solution.bullets.map(item => <li key={item}>{item}</li>)}</ul>
      </div><GarageArt kind="dossier" />
    </section>
    <section className="frame-section">
      <h2>{p.featuresSection.title}</h2>
      {([[0, 2], [1, 4], [3, 5]] as const).map(([first, second], i) => (
        <div className="feature-band" key={first}>
          <RecordList items={[p.features[first], p.features[second]]} />
          {i === 2 ? <GarageArt kind="dossier" /> : <figure className="capture-stage">
            <ScreenDetail subject={i === 0 ? "fuel" : "maintenance"} alt={i === 0 ? tour.fuelAlt : tour.maintenanceAlt} />
            <figcaption>{i === 0 ? tour.fuelCaption : tour.maintenanceCaption}</figcaption>
          </figure>}
        </div>
      ))}
    </section>
    <section className="frame-section paired"><h2>{p.benefitsSection.title}</h2><RecordList items={p.benefits} /></section>
    <section className="frame-section"><h2>{p.stepsSection.title}</h2><p className="intro">{p.stepsSection.intro}</p>
      <div className="mt-8"><StepList items={p.steps} /></div>
    </section>
    <CtaBanner title={p.cta.title} subtitle={p.cta.subtitle} primary={{href:"/pricing",label:p.cta.primary}}
      secondary={{href:"/#download",label:p.cta.secondary}} badgeLabels={d.storeBadges} showBadges={false} />
  </>;
}
