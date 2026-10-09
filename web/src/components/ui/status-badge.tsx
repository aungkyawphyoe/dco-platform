import { Badge, type BadgeTone } from "./badge";

type UserStatus = "active" | "deactivated";
type PartnerStatus = "draft" | "pending_verification" | "verified" | "rejected";
import type { Plan } from "@/lib/plans";
type PartnerType = "workshop" | "insurer";

const userStatusTone: Record<UserStatus, BadgeTone> = {
  active: "success",
  deactivated: "danger",
};

const partnerStatusTone: Record<PartnerStatus, BadgeTone> = {
  draft: "neutral",
  pending_verification: "warning",
  verified: "success",
  rejected: "danger",
};

const planTone: Record<Plan, BadgeTone> = {
  free: "neutral",
  lite: "info",
  standard: "success",
  fleet: "info",
};

const partnerTypeTone: Record<PartnerType, BadgeTone> = {
  workshop: "info",
  insurer: "warning",
};

const partnerStatusLabel: Record<PartnerStatus, string> = {
  draft: "Draft",
  pending_verification: "Pending",
  verified: "Verified",
  rejected: "Rejected",
};

export function UserStatusBadge({ status }: { status?: string }) {
  const tone = userStatusTone[status as UserStatus] ?? "neutral";
  return <Badge tone={tone}>{status ?? "—"}</Badge>;
}

export function PartnerStatusBadge({ status }: { status?: string }) {
  const tone = partnerStatusTone[status as PartnerStatus] ?? "neutral";
  const label = partnerStatusLabel[status as PartnerStatus] ?? status ?? "—";
  return <Badge tone={tone}>{label}</Badge>;
}

export function PlanBadge({ plan }: { plan?: string }) {
  const tone = planTone[plan as Plan] ?? "neutral";
  return <Badge tone={tone}>{plan ?? "—"}</Badge>;
}

export function PartnerTypeBadge({ type }: { type?: string }) {
  const tone = partnerTypeTone[type as PartnerType] ?? "neutral";
  return (
    <Badge tone={tone}>
      {type ? type.charAt(0).toUpperCase() + type.slice(1) : "—"}
    </Badge>
  );
}

type OrgStatus = "pending" | "active" | "suspended" | "archived";

const orgStatusTone: Record<OrgStatus, BadgeTone> = {
  pending: "warning",
  active: "success",
  suspended: "danger",
  archived: "neutral",
};

const orgStatusLabel: Record<OrgStatus, string> = {
  pending: "Pending",
  active: "Active",
  suspended: "Suspended",
  archived: "Archived",
};

export function OrganizationStatusBadge({ status }: { status?: string }) {
  const tone = orgStatusTone[status as OrgStatus] ?? "neutral";
  const label = orgStatusLabel[status as OrgStatus] ?? status ?? "—";
  return <Badge tone={tone}>{label}</Badge>;
}

export function OrganizationTypeBadge({ type }: { type?: string }) {
  const label = type
    ? type
        .split("_")
        .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
        .join(" ")
    : "—";
  return <Badge tone="info">{label}</Badge>;
}
