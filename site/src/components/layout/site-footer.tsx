import { FooterMark } from "./footer-mark";
import Link from "next/link";
import { DEMO_REQUEST_EMAIL, NAV_ITEMS } from "@/content/site";
import type { Dictionary } from "@/i18n/types";

type SiteFooterProps = {
  labels: Dictionary["footer"];
  navLabels: Dictionary["nav"]["links"];
};

export function SiteFooter({ labels, navLabels }: SiteFooterProps) {
  const groups = [
    { title: labels.product, links: NAV_ITEMS.filter(item => item.key !== "faq").map(item => [item.href, navLabels[item.key]]) },
    { title: labels.helpCenter, links: [["/faq", navLabels.faq], ["/demo", labels.requestDemo]] },
    { title: labels.legal, links: [["/privacy", labels.privacy], ["/terms", labels.terms], ["/account-deletion", labels.deleteAccount]] },
  ];
  return (
    <footer className="site-footer">
      <div className="footer-rail">
        <div className="footer-grid">
          <div className="footer-brand">
            <FooterMark />
            <p>{labels.tagline}</p>
          </div>
          {groups.map(group => <div key={group.title}>
            <h2>{group.title}</h2>
            <ul>{group.links.map(([href, label]) => <li key={href}><Link href={href}>{label}</Link></li>)}</ul>
          </div>)}
          <div className="footer-support">
            <h2>{labels.contact}</h2>
            <a href={`mailto:${DEMO_REQUEST_EMAIL}`}>{DEMO_REQUEST_EMAIL}</a>
          </div>
        </div>
        <div className="footer-contact">
          <small>{labels.rights.replace("{year}", String(new Date().getFullYear()))}</small>
        </div>
      </div>
      <div className="footer-terrain" aria-hidden="true" />
    </footer>
  );
}
