import { HighlightedTitle } from "@/components/marketing/highlighted-title";
import type { Metadata } from "next";
import { getSiteCopy } from "@/i18n/dictionary";
import { GarageArt } from "@/components/marketing/garage-art";
import { RecordList } from "@/components/marketing/record-list";
import { StepList } from "@/components/marketing/step-list";
import { CtaBanner } from "@/components/marketing/cta-banner";
import { PhoneFrame } from "@/components/marketing/phone-frame";
import { ScreenDetail } from "@/components/marketing/screen-detail";
import { StoreBadges } from "@/components/marketing/store-badges";

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
        <h1><HighlightedTitle title={p.hero.title} highlight={p.hero.titleHighlight} /></h1><p className="intro">{p.hero.subtitle}</p>
        <ul className="bullet-list">{p.hero.bullets.map(item => <li key={item}>{item}</li>)}</ul>
        <StoreBadges labels={d.storeBadges} />
      </div>
      <PhoneFrame src={{dark: "/screenshots/app-garage-dark.webp", light: "/screenshots/app-garage-light.webp"}}
        alt={p.hero.phoneAlt} label={p.hero.phoneLabel} priority />
    </section>
    <section className="frame-section paired">
      <div><h2><span className="section-label">{p.problem.eyebrow}</span><HighlightedTitle title={p.problem.heading} highlight={p.problem.headingHighlight} /></h2><p className="intro">{p.problem.intro}</p></div>
      <RecordList items={p.problem.items} />
    </section>
    <section className="frame-section paired">
      <div><h2><span className="section-label">{p.solution.eyebrow}</span><HighlightedTitle title={p.solution.heading} highlight={p.solution.headingHighlight} /></h2><p className="intro">{p.solution.intro}</p>
        <ul className="bullet-list">{p.solution.bullets.map(item => <li key={item}>{item}</li>)}</ul>
      </div><GarageArt kind="dossier" />
    </section>
    <section className="frame-section">
      <h2><span className="section-label">{p.featuresSection.eyebrow}</span><HighlightedTitle title={p.featuresSection.title} highlight={p.featuresSection.titleHighlight} /></h2>
      {([[0, 2], [1, 4], [3, 5]] as const).map(([first, second], i) => (
        <div className="feature-band" key={first}>
          <RecordList items={[p.features[first], p.features[second]]} />
          {i === 2 ? <GarageArt kind="keys" /> : <figure className="capture-stage">
            <ScreenDetail subject={i === 0 ? "fuel" : "maintenance"} alt={i === 0 ? tour.fuelAlt : tour.maintenanceAlt} />
            <figcaption>{i === 0 ? tour.fuelCaption : tour.maintenanceCaption}</figcaption>
          </figure>}
        </div>
      ))}
    </section>
    <section className="frame-section paired">
      <div className="benefits-visual">
        <h2><span className="section-label">{p.benefitsSection.eyebrow}</span>{p.benefitsSection.title}</h2>
        <GarageArt kind="question" />
      </div>
      <RecordList items={p.benefits} />
    </section>
    <section className="frame-section"><h2><span className="section-label">{p.stepsSection.eyebrow}</span><HighlightedTitle title={p.stepsSection.title} highlight={p.stepsSection.titleHighlight} /></h2><p className="intro">{p.stepsSection.intro}</p>
      <div className="mt-8"><StepList items={p.steps} /></div>
    </section>
    <CtaBanner label={d.sectionLabels.nextSteps} title={p.cta.title} subtitle={p.cta.subtitle} primary={{href:"/pricing",label:p.cta.primary}}
      secondary={{href:"/#download",label:p.cta.secondary}} badgeLabels={d.storeBadges} showBadges={false} />
  </>;
}
