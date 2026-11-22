import { StoreBadges } from "@/components/marketing/store-badges";
import { HighlightedTitle } from "@/components/marketing/highlighted-title";
import { DemoInvitation } from "@/components/demo/demo-invitation";
import Link from "next/link";
import { getSiteCopy } from "@/i18n/dictionary";
import { HighwayPoster } from "@/components/marketing/highway-poster";
import { ProductTour } from "@/components/marketing/product-tour";
import { GarageArt } from "@/components/marketing/garage-art";
import { RecordList } from "@/components/marketing/record-list";
import { StepList } from "@/components/marketing/step-list";
import { PathCards } from "@/components/marketing/path-cards";
import { HAS_STORE } from "@/content/site";

const paths = ["/personal", "/fleet"];
const featureGroups = [[0, 4], [1, 3], [2, 5]];

export default async function HomePage() {
  const { d } = await getSiteCopy();
  const h = d.home;
  return (
    <>
      <section className="highway-hero">
        <HighwayPoster labels={h.motion} />
        <div className="highway-copy">
          <h1><span className="section-label">{h.hero.eyebrow}</span><HighlightedTitle title={h.hero.title} highlight={h.hero.titleHighlight} /></h1>
          <p>{h.hero.subtitle}</p>
          <div className="actions">
            {h.paths.map((item, index) => <Link key={item.title} className={index ? "action secondary" : "action"} href={paths[index]}>{item.cta}</Link>)}
          </div>
        </div>
      </section>
      <dl className="value-strip">{h.valueChips.map(item => (
        <div key={item.title}><dt>{item.title}</dt><dd>{item.description}</dd></div>
      ))}</dl>
      <ProductTour copy={h.showcaseSection} />
      <section className="frame-section paired service-history">
        <div><h2><span className="section-label">{d.sectionLabels.serviceHistory}</span><HighlightedTitle title={h.offlineTitle} highlight={h.offlineTitleHighlight} /></h2><p className="intro">{h.offlineBody}</p></div>
        <GarageArt kind="serviceHistory" />
      </section>
      <section className="frame-section">
        <h2><span className="section-label">{h.featuresSection.eyebrow}</span><HighlightedTitle title={h.featuresSection.title} highlight={h.featuresSection.titleHighlight} /></h2><p className="intro">{h.featuresSection.intro}</p>
        <div className="catalog">{featureGroups.map((indices, i) => (
          <div key={i}><h3>{h.catalogGroups[i]}</h3><RecordList items={indices.map(j => h.features[j])} /></div>
        ))}</div>
      </section>
      <section className="frame-section">
        <h2><span className="section-label">{h.pathsSection.eyebrow}</span><HighlightedTitle title={h.pathsSection.title} highlight={h.pathsSection.titleHighlight} /></h2><p className="intro">{h.pathsSection.intro}</p>
        <div className="mt-8"><PathCards items={h.paths.map((item, i) => ({ ...item, href: paths[i] }))} /></div>
      </section>
      <section className="frame-section paired">
        <div className="audiences-visual">
          <h2><span className="section-label">{h.audiencesSection.eyebrow}</span>{h.audiencesSection.title}</h2>
          <GarageArt kind="globe" />
        </div>
        <dl className="record-list">{h.audiences.map(item => <div key={item.title}>
          <dt>{item.title}</dt><dd>{item.bullets.join(" / ")}</dd>
        </div>)}</dl>
      </section>
      <section className="frame-section">
        <h2><span className="section-label">{h.stepsSection.eyebrow}</span><HighlightedTitle title={h.stepsSection.title} highlight={h.stepsSection.titleHighlight} /></h2><p className="intro">{h.stepsSection.intro}</p>
        <div className="mt-8"><StepList items={h.steps} /></div>
      </section>
      <section id="download" className="closing">
        <h2><span className="section-label">{d.sectionLabels.download}</span>{h.download.title}</h2>
        <p>{HAS_STORE ? h.download.intro : h.paths[0].description}</p>
        {HAS_STORE ? <><StoreBadges labels={d.storeBadges} /><small>{h.download.note}</small></> :
          <Link className="action" href="/personal">{h.paths[0].cta}</Link>}
        <div className="text-links"><Link href="/pricing">{h.cta.primary}</Link><Link href="/faq">{h.cta.secondary}</Link></div>
      </section>
      <DemoInvitation copy={d.demo} />
    </>
  );
}
