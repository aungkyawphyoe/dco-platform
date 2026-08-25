"use client";

import { useCallback, useEffect, useRef } from "react";
import { Button } from "./button";

export function Modal({
  open,
  onClose,
  title,
  children,
  confirmLabel = "Confirm",
  onConfirm,
  onSubmit,
  destructive = false,
  loading = false,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
  confirmLabel?: string;
  onConfirm?: () => void;
  onSubmit?: () => void;
  destructive?: boolean;
  loading?: boolean;
}) {
  const overlayRef = useRef<HTMLDivElement>(null);

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    },
    [onClose],
  );

  useEffect(() => {
    if (open) {
      document.addEventListener("keydown", handleKeyDown);
      document.body.style.overflow = "hidden";
    }
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = "";
    };
  }, [open, handleKeyDown]);

  if (!open) return null;

  return (
    <div
      ref={overlayRef}
      className="fixed inset-0 z-50 flex items-center justify-center bg-overlay"
      onClick={(e) => {
        if (e.target === overlayRef.current) onClose();
      }}
    >
      <div className="mx-4 w-full max-w-md rounded-lg border border-line-subtle bg-card p-6 shadow-xl">
        <h2 className="font-display text-lg font-semibold text-ink">
          {title}
        </h2>
        <div className="mt-4 text-sm text-ink-muted">{children}</div>
        <div className="mt-6 flex justify-end gap-3">
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant={destructive ? "destructive" : "primary"}
            size="sm"
            onClick={onSubmit ?? onConfirm}
            disabled={loading}
          >
            {loading ? "Working..." : confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  );
}
