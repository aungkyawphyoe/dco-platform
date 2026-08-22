export type BadgeTone = "success" | "warning" | "danger" | "info" | "neutral";

const toneClasses: Record<BadgeTone, string> = {
  success: "bg-success-dim text-success",
  warning: "bg-warning-dim text-warning",
  danger: "bg-danger-dim text-danger",
  info: "bg-info-dim text-info",
  neutral: "bg-panel text-ink-muted",
};

export function Badge({
  tone = "neutral",
  children,
}: {
  tone?: BadgeTone;
  children: React.ReactNode;
}) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium whitespace-nowrap ${toneClasses[tone]}`}
    >
      {children}
    </span>
  );
}

export const accountStatusTone: Record<string, BadgeTone> = {
  active: "success",
  deactivated: "danger",
};

export const partnerStatusTone: Record<string, BadgeTone> = {
  draft: "neutral",
  pending_verification: "warning",
  verified: "success",
  rejected: "danger",
};

export const planTone: Record<string, BadgeTone> = {
  free: "neutral",
  premium: "info",
};
