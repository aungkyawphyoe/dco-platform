"use client";

import { useRouter } from "next/navigation";
import type { Dictionary } from "@/i18n/types";

export function DemoInvitation({ copy }: { copy: Dictionary["demo"] }) {
  const router = useRouter();
  return <section className="demo-invitation">
    <div className="invitation-panel">
      <div className="invitation-copy">
        <h2>{copy.title}</h2>
        <p>{copy.subtitle}</p>
        <form action="/demo" onSubmit={event => {
          event.preventDefault();
          const email = event.currentTarget.querySelector("input")?.value.trim() || "";
          try { sessionStorage.setItem("autox-demo-email", email); } catch {}
          router.push("/demo");
        }}>
          <input type="email" autoComplete="email" aria-label={copy.form.fields.email.label}
            placeholder={copy.form.fields.email.placeholder} />
          <button className="action">{copy.form.title} <span aria-hidden="true">→</span></button>
        </form>
      </div>
      <div aria-hidden="true" className="invitation-art" />
    </div>
  </section>;
}
