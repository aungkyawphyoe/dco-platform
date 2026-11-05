"use client";

import { useEffect, useId, useRef, type ReactNode } from "react";
import { Button } from "@dco/ui/components/button";

/** Native modal focus containment and Escape handling, with a desktop layout. */
export function ServiceDialog({ title, description, onClose, children, footer, busy = false }: {
  title: string;
  description?: string;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
  busy?: boolean;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const descriptionId = useId();
  useEffect(() => {
    const element = dialog.current;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    element?.showModal();
    return () => {
      element?.close();
      document.body.style.overflow = previousOverflow;
    };
  }, []);
  return (
    <dialog ref={dialog} aria-labelledby={titleId} aria-describedby={description ? descriptionId : undefined}
      onCancel={event => { event.preventDefault(); if (!busy) onClose(); }}
      className="fixed inset-0 m-auto max-h-[calc(100dvh_-_2rem)] w-[calc(100%_-_2rem)] max-w-2xl overflow-hidden rounded-lg border border-line-strong bg-card p-0 text-ink shadow-xl backdrop:bg-overlay">
      <div className="flex max-h-[calc(100dvh_-_2rem)] flex-col">
        <header className="flex shrink-0 items-start justify-between gap-4 border-b border-line px-6 py-5">
          <div>
            <h2 id={titleId} className="font-display text-xl font-semibold">{title}</h2>
            {description && <p id={descriptionId} className="mt-1 max-w-prose text-sm text-ink-caption">{description}</p>}
          </div>
          <Button variant="secondary" size="sm" disabled={busy} onClick={onClose}>Close</Button>
        </header>
        <div className="overflow-y-auto px-6 py-5">{children}</div>
        {footer && <footer className="flex shrink-0 justify-end gap-3 border-t border-line bg-panel px-6 py-4">{footer}</footer>}
      </div>
    </dialog>
  );
}
