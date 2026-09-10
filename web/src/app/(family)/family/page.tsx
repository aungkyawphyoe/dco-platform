"use client";

import { useQuery } from "@tanstack/react-query";
import { apiGet } from "@/lib/api/client";
import { Table, TableBody, TableCell, TableHead, TableHeadCell, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { QrCodeModal } from "@/components/ui/qr-code-modal";
import { useState } from "react";

interface FamilyDashboardData {
  family: {
    id: string;
    name: string;
    share_code: string;
    qr_code_data: { code: string; family_id: string; expires_at: string } | null;
    status: string;
    created_by: string;
    created_at: string;
    my_role: string;
  };
  members: Array<{
    id: string;
    user_id: string;
    email: string;
    display_name: string | null;
    role: string;
    joined_at: string;
    invited_by: string | null;
    vehicle_count: number;
    license_status: string | null;
  }>;
  vehicles: Array<{
    id: string;
    nickname: string;
    license_plate: string;
    make: string;
    model: string;
    year: number;
    owner: { id: string; display_name: string };
    driver_count: number;
  }>;
}

export default function FamilyDashboardPage() {
  const [showQr, setShowQr] = useState(false);
  const { data, isLoading, error } = useQuery({
    queryKey: ["family", "dashboard"],
    queryFn: () => apiGet<FamilyDashboardData>("/families/me?include=members,vehicles,grants,licenses"),
    staleTime: 30_000,
  });

  if (isLoading) {
    return (
      <div className="flex flex-col gap-8">
        <div className="grid gap-4 md:grid-cols-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="rounded-lg border border-line-subtle bg-card p-6 animate-pulse">
              <div className="h-4 w-1/3 bg-line-subtle rounded mb-2" />
              <div className="h-8 w-1/2 bg-line-subtle rounded" />
            </div>
          ))}
        </div>
        <div className="rounded-lg border border-line-subtle bg-card p-6 animate-pulse">
          <div className="h-4 w-1/4 bg-line-subtle rounded mb-4" />
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-10 w-full bg-line-subtle rounded" />
            ))}
          </div>
        </div>
        <div className="rounded-lg border border-line-subtle bg-card p-6 animate-pulse">
          <div className="h-4 w-1/4 bg-line-subtle rounded mb-4" />
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-10 w-full bg-line-subtle rounded" />
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-lg border border-line-subtle bg-card p-6 text-center">
        <p className="text-danger">Failed to load family data: {String(error)}</p>
        <Button onClick={() => window.location.reload()} className="mt-4">
          Retry
        </Button>
      </div>
    );
  }

  if (!data) return null;

  const family = data.family;
  const members = data.members;
  const vehicles = data.vehicles;

  return (
    <div className="flex flex-col gap-8">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-semibold text-gold">{family.name}</h1>
          <p className="text-sm text-ink-caption mt-1">
            Share Code: <code className="font-mono text-gold">{family.share_code}</code>
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="secondary" size="sm" onClick={() => navigator.clipboard.writeText(family.share_code)}>
            Copy Code
          </Button>
          <Button variant="secondary" size="sm" onClick={() => setShowQr(true)}>
            Show QR
          </Button>
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <KpiCard title="Members" value={members.length} icon="👥" />
        <KpiCard title="Vehicles" value={vehicles.length} icon="🚗" />
        <KpiCard
          title="Drivers"
          value={members.filter((m: { role: string }) => m.role === "driver").length}
          icon="🚙"
        />
      </div>

      <div className="rounded-lg border border-line-subtle bg-card">
        <div className="flex items-center justify-between p-4 border-b border-line-subtle">
          <h2 className="font-display text-lg font-semibold">Vehicles</h2>
          <Button variant="secondary" size="sm" onClick={() => setShowQr(true)}>
            QR
          </Button>
        </div>
        <div className="overflow-x-auto">
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Nickname</TableHeadCell>
                <TableHeadCell>Plate</TableHeadCell>
                <TableHeadCell>Make/Model</TableHeadCell>
                <TableHeadCell>Owner</TableHeadCell>
                <TableHeadCell>Drivers</TableHeadCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {vehicles.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="text-center text-ink-caption py-8">
                    No vehicles in family yet.
                  </TableCell>
                </TableRow>
              ) : (
                vehicles.map((vehicle: { id: string; nickname?: string; license_plate: string; make: string; model: string; year: number; owner: { id: string; display_name: string }; driver_count: number }) => (
                  <TableRow key={vehicle.id}>
                    <TableCell>{vehicle.nickname || "—"}</TableCell>
                    <TableCell>{vehicle.license_plate}</TableCell>
                    <TableCell>
                      {vehicle.year} {vehicle.make} {vehicle.model}
                    </TableCell>
                    <TableCell>{vehicle.owner.display_name} {vehicle.owner.id === family.created_by ? "(You)" : ""}</TableCell>
                    <TableCell>
                      <Badge tone="neutral">{vehicle.driver_count}</Badge>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </div>
      </div>

      <div className="rounded-lg border border-line-subtle bg-card">
        <div className="flex items-center justify-between p-4 border-b border-line-subtle">
          <h2 className="font-display text-lg font-semibold">Members</h2>
          <Button variant="secondary" size="sm" onClick={() => setShowQr(true)}>
            QR
          </Button>
        </div>
        <div className="overflow-x-auto">
          <Table>
            <TableHead>
              <TableRow>
                <TableHeadCell>Name</TableHeadCell>
                <TableHeadCell>Email</TableHeadCell>
                <TableHeadCell>Role</TableHeadCell>
                <TableHeadCell>Vehicles</TableHeadCell>
                <TableHeadCell>License</TableHeadCell>
                <TableHeadCell>Joined</TableHeadCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {members.map((member) => (
                <TableRow key={member.id}>
                  <TableCell>{member.display_name ?? "—"}</TableCell>
                  <TableCell>{member.email}</TableCell>
                  <TableCell>
                    <RoleBadge role={member.role} />
                  </TableCell>
                  <TableCell>{member.vehicle_count}</TableCell>
                  <TableCell>
                    <LicenseStatusBadge status={member.license_status} />
                  </TableCell>
                  <TableCell>{new Date(member.joined_at).toLocaleDateString()}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      </div>

      <QrCodeModal
        open={showQr}
        onClose={() => setShowQr(false)}
        data={`dco://family/join?code=${family.share_code}`}
        label={`Join ${family.name}`}
        code={family.share_code}
      />
    </div>
  );
}

function KpiCard({ title, value, icon }: { title: string; value: number; icon: string }) {
  return (
    <div className="rounded-lg border border-line-subtle bg-card p-6">
      <div className="text-3xl mb-2">{icon}</div>
      <p className="text-ink-caption">{title}</p>
      <p className="font-display text-3xl font-semibold text-gold mt-1">{value}</p>
    </div>
  );
}

function RoleBadge({ role }: { role: string }) {
  const config = {
    primary_owner: { tone: "info" as const, label: "Primary Owner" },
    member: { tone: "neutral" as const, label: "Member" },
    driver: { tone: "success" as const, label: "Driver" },
  };
  const c = config[role as keyof typeof config] || { tone: "neutral" as const, label: role };
  return <Badge tone={c.tone}>{c.label}</Badge>;
}

function LicenseStatusBadge({ status }: { status: string | null }) {
  if (!status || status === "none") return <Badge tone="neutral">No License</Badge>;
  const config = {
    valid: { tone: "success" as const, label: "Valid" },
    expiring_soon: { tone: "warning" as const, label: "Expiring Soon" },
    expired: { tone: "danger" as const, label: "Expired" },
  };
  const c = config[status as keyof typeof config] || { tone: "neutral" as const, label: status };
  return <Badge tone={c.tone}>{c.label}</Badge>;
}
