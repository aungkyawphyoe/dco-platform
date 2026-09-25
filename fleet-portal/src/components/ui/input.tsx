"use client";

import { useId } from "react";

export function Input({
  label,
  error,
  hint,
  ...props
}: React.InputHTMLAttributes<HTMLInputElement> & {
  label: string;
  error?: string | null;
  hint?: string;
}) {
  const id = useId();
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className="text-label uppercase tracking-wide text-ink-caption">
        {label}
      </label>
      <input
        id={id}
        className={`h-11 rounded-md bg-field px-3 text-body text-ink placeholder:text-ink-faint border transition-colors duration-150 focus:outline-none focus:ring-2 ${
          error ? "border-danger ring-danger/40" : "border-line-strong focus:ring-focus"
        }`}
        aria-invalid={Boolean(error)}
        {...props}
      />
      {error ? (
        <p className="text-xs text-danger">{error}</p>
      ) : hint ? (
        <p className="text-xs text-ink-caption">{hint}</p>
      ) : null}
    </div>
  );
}
