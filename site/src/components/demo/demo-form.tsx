"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { DEMO_REQUEST_EMAIL } from "@/content/site";
import type { Dictionary } from "@/i18n/types";

const DEMO_REQUEST_ENDPOINT = process.env.NEXT_PUBLIC_DEMO_REQUEST_ENDPOINT;

type FormCopy = Dictionary["demo"]["form"];

type Values = {
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  company: string;
  jobTitle: string;
  message: string;
};

type ErrorKey = keyof Values | "contact";
type Errors = Partial<Record<ErrorKey, string>>;
type Status = "idle" | "sending" | "sent" | "mailto" | "error";

const EMPTY: Values = {
  firstName: "",
  lastName: "",
  email: "",
  phone: "",
  company: "",
  jobTitle: "",
  message: "",
};

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validate(values: Values, messages: FormCopy["errors"]): Errors {
  const errors: Errors = {};

  if (!values.firstName.trim()) errors.firstName = messages.firstName;
  if (!values.lastName.trim()) errors.lastName = messages.lastName;

  const email = values.email.trim();
  const phone = values.phone.trim();

  if (email && !EMAIL_RE.test(email)) {
    errors.email = messages.email;
  }
  if (phone && (phone.replace(/\D/g, "").length < 7 || !/^[+()\d\s.-]+$/.test(phone))) {
    errors.phone = messages.phone;
  }
  if (!email && !phone) {
    errors.contact = messages.contact;
  }

  return errors;
}

function buildMailto(values: Values) {
  const subject = `Demo request — ${values.firstName.trim()} ${values.lastName.trim()}`;
  const body = [
    `First name: ${values.firstName.trim()}`,
    `Last name: ${values.lastName.trim()}`,
    `Email: ${values.email.trim() || "—"}`,
    `Phone: ${values.phone.trim() || "—"}`,
    `Company: ${values.company.trim() || "—"}`,
    `Job title: ${values.jobTitle.trim() || "—"}`,
    "",
    "What they want to see:",
    values.message.trim() || "—",
  ].join("\n");

  return `mailto:${DEMO_REQUEST_EMAIL}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
}

type TextFieldProps = {
  id: string;
  label: string;
  value: string;
  placeholder: string;
  onChange: (value: string) => void;
  required?: boolean;
  type?: "text" | "email" | "tel";
  autoComplete?: string;
  inputMode?: "text" | "email" | "tel";
  error?: string;
  describedBy?: string;
};

function TextField({
  id,
  label,
  value,
  placeholder,
  onChange,
  required,
  type = "text",
  autoComplete,
  inputMode,
  error,
  describedBy,
}: TextFieldProps) {
  const errorId = `${id}-error`;
  const describedByIds = [error ? errorId : null, describedBy].filter(Boolean).join(" ") || undefined;

  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className="text-[13px] font-medium text-ink">
        {label}
        {required && (
          <span aria-hidden="true" className="ml-0.5 text-gold">
            *
          </span>
        )}
      </label>
      <input
        id={id}
        name={id}
        type={type}
        inputMode={inputMode}
        autoComplete={autoComplete}
        required={required}
        value={value}
        placeholder={placeholder}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedByIds}
        onChange={(event) => onChange(event.target.value)}
        className={`h-11 w-full rounded-lg border bg-field px-3.5 text-sm text-ink placeholder:text-ink-faint transition-colors duration-150 ease-out-soft focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus ${
          error ? "border-danger" : "border-line-strong hover:border-gold/60 focus:border-gold"
        }`}
      />
      {error && (
        <p id={errorId} className="text-xs leading-5 text-danger">
          {error}
        </p>
      )}
    </div>
  );
}

export function DemoForm({ copy }: { copy: FormCopy }) {
  const [values, setValues] = useState<Values>(EMPTY);
  const [errors, setErrors] = useState<Errors>({});
  const [status, setStatus] = useState<Status>("idle");
  const [formError, setFormError] = useState("");
  const successRef = useRef<HTMLHeadingElement | null>(null);

  useEffect(() => {
    if (status === "sent" || status === "mailto") successRef.current?.focus();
  }, [status]);

  function setField(field: keyof Values, value: string) {
    setValues((current) => ({ ...current, [field]: value }));
    if (errors[field] || ((field === "email" || field === "phone") && errors.contact)) {
      setErrors((current) => {
        const next = { ...current };
        delete next[field];
        if (field === "email" || field === "phone") delete next.contact;
        return next;
      });
    }
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFormError("");

    const nextErrors = validate(values, copy.errors);
    setErrors(nextErrors);

    if (Object.keys(nextErrors).length > 0) {
      const firstKey = (["firstName", "lastName", "email", "phone"] as const).find(
        (key) => nextErrors[key],
      );
      const id = firstKey === "firstName"
        ? "demo-first-name"
        : firstKey === "lastName"
          ? "demo-last-name"
          : firstKey === "phone" && !nextErrors.email
            ? "demo-phone"
            : "demo-email";
      document.getElementById(id)?.focus();
      return;
    }

    const payload = {
      firstName: values.firstName.trim(),
      lastName: values.lastName.trim(),
      email: values.email.trim(),
      phone: values.phone.trim(),
      company: values.company.trim(),
      jobTitle: values.jobTitle.trim(),
      message: values.message.trim(),
      source: "marketing-site:/demo",
      submittedAt: new Date().toISOString(),
    };

    if (DEMO_REQUEST_ENDPOINT) {
      setStatus("sending");
      try {
        const response = await fetch(DEMO_REQUEST_ENDPOINT, {
          method: "POST",
          headers: { "Content-Type": "application/json", Accept: "application/json" },
          body: JSON.stringify(payload),
        });
        if (!response.ok) throw new Error(`Request failed with ${response.status}`);
        setStatus("sent");
      } catch {
        setStatus("error");
        setFormError(copy.errors.submit);
      }
      return;
    }

    // No form endpoint configured: hand the request to the visitor's mail app
    // with every field pre-filled, so the lead still reaches sales.
    const mailto = buildMailto(values);
    window.location.href = mailto;
    setStatus("mailto");
  }

  if (status === "sent" || status === "mailto") {
    const email = values.email.trim();
    const phone = values.phone.trim();
    const contact = email || phone;
    const contactPart = contact ? copy.success.sentContact.replace("{contact}", contact) : "";
    const sentBody = copy.success.sentBody
      .replace("{name}", values.firstName.trim() || copy.success.there)
      .replace("{contact}", contactPart);

    return (
      <div className="surface shadow-float rounded-2xl p-6 sm:p-8" role="status" aria-live="polite">
        <span className="flex h-12 w-12 items-center justify-center rounded-xl bg-gold/15 text-gold">
          <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" className="h-6 w-6">
            <path d="m5 12.5 4.5 4.5L19 7.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </span>
        <h2
          ref={successRef}
          tabIndex={-1}
          className="mt-5 font-display text-2xl font-semibold tracking-tight focus:outline-none"
        >
          {status === "sent" ? copy.success.sentTitle : copy.success.mailtoTitle}
        </h2>
        <p className="mt-2 max-w-md text-sm leading-6 text-ink-muted">
          {status === "sent" ? sentBody : copy.success.mailtoBody}
        </p>

        <div className="mt-6 flex flex-wrap items-center gap-3">
          {status === "mailto" ? (
            <a
              href={buildMailto(values)}
              className="btn-gloss inline-flex h-11 items-center rounded-full px-6 text-sm font-semibold"
            >
              {copy.openEmailApp}
            </a>
          ) : null}
          <button
            type="button"
            onClick={() => {
              setStatus("idle");
              setValues(EMPTY);
              setErrors({});
            }}
            className="surface card-hover inline-flex h-11 items-center rounded-full px-6 text-sm font-semibold text-ink"
          >
            {copy.sendAnother}
          </button>
        </div>
      </div>
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      noValidate
      className="surface shadow-float rounded-2xl p-5 sm:p-7 lg:p-8"
      aria-describedby="demo-form-note"
    >
      <div className="mb-6 flex items-start justify-between gap-4">
        <div>
          <h2 className="font-display text-2xl font-semibold tracking-tight">{copy.title}</h2>
          <p className="mt-1 text-sm leading-6 text-ink-muted">{copy.requiredNote}</p>
        </div>
        <span className="pill pill-gold shrink-0">{copy.duration}</span>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <TextField
          id="demo-first-name"
          label={copy.fields.firstName.label}
          required
          autoComplete="given-name"
          placeholder={copy.fields.firstName.placeholder}
          value={values.firstName}
          onChange={(value) => setField("firstName", value)}
          error={errors.firstName}
        />
        <TextField
          id="demo-last-name"
          label={copy.fields.lastName.label}
          required
          autoComplete="family-name"
          placeholder={copy.fields.lastName.placeholder}
          value={values.lastName}
          onChange={(value) => setField("lastName", value)}
          error={errors.lastName}
        />
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-2">
        <TextField
          id="demo-email"
          label={copy.fields.email.label}
          type="email"
          inputMode="email"
          autoComplete="email"
          placeholder={copy.fields.email.placeholder}
          value={values.email}
          onChange={(value) => setField("email", value)}
          error={errors.email}
          describedBy={errors.contact ? "demo-contact-error" : "demo-contact-hint"}
        />
        <TextField
          id="demo-phone"
          label={copy.fields.phone.label}
          type="tel"
          inputMode="tel"
          autoComplete="tel"
          placeholder={copy.fields.phone.placeholder}
          value={values.phone}
          onChange={(value) => setField("phone", value)}
          error={errors.phone}
          describedBy={errors.contact ? "demo-contact-error" : "demo-contact-hint"}
        />
      </div>

      {errors.contact ? (
        <p id="demo-contact-error" role="alert" className="mt-2 text-xs leading-5 text-danger">
          {errors.contact}
        </p>
      ) : (
        <p id="demo-contact-hint" className="mt-2 text-xs leading-5 text-ink-caption">
          {copy.contactHint}
        </p>
      )}

      <div className="mt-4 grid gap-4 sm:grid-cols-2">
        <TextField
          id="demo-company"
          label={copy.fields.company.label}
          autoComplete="organization"
          placeholder={copy.fields.company.placeholder}
          value={values.company}
          onChange={(value) => setField("company", value)}
        />
        <TextField
          id="demo-job-title"
          label={copy.fields.jobTitle.label}
          autoComplete="organization-title"
          placeholder={copy.fields.jobTitle.placeholder}
          value={values.jobTitle}
          onChange={(value) => setField("jobTitle", value)}
        />
      </div>

      <div className="mt-4 flex flex-col gap-1.5">
        <label htmlFor="demo-message" className="text-[13px] font-medium text-ink">
          {copy.message.label}
          <span className="ml-1 font-normal text-ink-caption">{copy.message.optional}</span>
        </label>
        <textarea
          id="demo-message"
          name="message"
          rows={4}
          maxLength={2000}
          value={values.message}
          placeholder={copy.message.placeholder}
          onChange={(event) => setField("message", event.target.value)}
          className="w-full resize-y rounded-lg border border-line-strong bg-field px-3.5 py-3 text-sm leading-6 text-ink placeholder:text-ink-faint transition-colors duration-150 ease-out-soft hover:border-gold/60 focus:border-gold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
        />
      </div>

      {formError && (
        <p role="alert" className="mt-4 text-sm leading-6 text-danger">
          {formError}{" "}
          <a href={`mailto:${DEMO_REQUEST_EMAIL}`} className="font-medium underline underline-offset-2">
            {DEMO_REQUEST_EMAIL}
          </a>
        </p>
      )}

      <button
        type="submit"
        disabled={status === "sending"}
        className="btn-gloss mt-6 inline-flex h-12 w-full items-center justify-center gap-2 rounded-full px-6 text-sm font-semibold disabled:pointer-events-none disabled:opacity-60"
      >
        {status === "sending" ? (
          <>
            <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" className="h-4 w-4 animate-spin">
              <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2.5" strokeOpacity="0.3" />
              <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" />
            </svg>
            {copy.sending}
          </>
        ) : (
          copy.sendRequest
        )}
      </button>

      <p id="demo-form-note" className="mt-4 text-xs leading-5 text-ink-caption">
        {copy.privacyNote}{" "}
        <a href="/privacy" className="text-gold underline underline-offset-2 hover:no-underline">
          {copy.privacyLink}
        </a>
        .
      </p>
    </form>
  );
}
