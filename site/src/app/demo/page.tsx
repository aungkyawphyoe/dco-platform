import { HighlightedTitle } from "@/components/marketing/highlighted-title";
import type { Metadata } from "next";
import { getSiteCopy } from "@/i18n/dictionary";
import { DemoForm } from "@/components/demo/demo-form";
import { DEMO_REQUEST_EMAIL } from "@/content/site";
import { GarageArt } from "@/components/marketing/garage-art";
import { RecordList } from "@/components/marketing/record-list";

export async function generateMetadata(): Promise<Metadata> {
  const { d } = await getSiteCopy();
  return {
    title: d.meta.pages.demo.title,
    description: d.meta.pages.demo.description,
  };
}

export default async function DemoPage() {
  const { d } = await getSiteCopy();
  const demo = d.demo;
  return <section className="frame-section demo-layout">
    <div className="demo-intro"><h1><span className="section-label">{demo.eyebrow}</span><HighlightedTitle title={demo.title} highlight={demo.titleHighlight} /></h1><p className="intro">{demo.subtitle}</p></div>
    <div className="demo-form"><DemoForm copy={demo.form} /></div>
    <div className="demo-proof">
      <GarageArt kind="workshop" /><RecordList items={demo.proof} />
      <p className="fine-print">{demo.preferEmail} <a href={`mailto:${DEMO_REQUEST_EMAIL}`}>{DEMO_REQUEST_EMAIL}</a></p>
    </div>
  </section>;
}
