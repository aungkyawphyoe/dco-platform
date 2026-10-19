"use client";

import { useEffect, useState } from "react";

export function SearchInput({
  value: externalValue,
  onChange,
  placeholder = "Search...",
  className = "",
}: {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  className?: string;
}) {
  const [local, setLocal] = useState(externalValue);

  useEffect(() => {
    setLocal(externalValue);
  }, [externalValue]);

  useEffect(() => {
    const timer = setTimeout(() => {
      if (local !== externalValue) onChange(local);
    }, 300);
    return () => clearTimeout(timer);
  }, [local, externalValue, onChange]);

  return (
    <div className={`relative ${className}`}>
      <svg
        className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-faint"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        strokeWidth={2}
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
        />
      </svg>
      <input
        type="text"
        value={local}
        onChange={(e) => setLocal(e.target.value)}
        placeholder={placeholder}
        className="h-11 w-full rounded-md bg-field pl-10 pr-3 text-body text-ink placeholder:text-ink-faint border border-line-strong transition-colors duration-150 focus:outline-none focus:ring-2 focus:ring-focus"
      />
    </div>
  );
}
