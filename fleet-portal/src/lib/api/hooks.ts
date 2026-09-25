"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiDelete, apiGet, apiPatch, apiPost } from "./client";
import { ensureFreshToken } from "@/lib/auth/token-store";
import { apiBaseUrl } from "@/lib/api/config";
import { parseApiError } from "@/lib/api/errors";
import type {
  Assignment,
  FleetAnalytics,
  FleetVehicle,
  ImportJob,
  Inspection,
  InspectionTemplate,
  LemonReport,
  OrgContext,
  OrgMember,
  OrgWorkshop,
  TransferredVehicle,
  VehicleCreateInput,
  WarrantyTemplate,
  WorkOrder,
} from "@/lib/api/types";

// ── Organization ──

export function useOrganization() {
  return useQuery({
    queryKey: ["fleet", "organization"],
    queryFn: () => apiGet<OrgContext>("/organizations/me"),
  });
}

export function orgPath(orgId: string | null, suffix: string): string {
  return `/organizations/${orgId}${suffix}`;
}

// ── Analytics / Dashboard ──

export function useFleetAnalytics(orgId: string | null) {
  return useQuery({
    queryKey: ["fleet", "analytics", orgId],
    queryFn: () => apiGet<FleetAnalytics>(orgPath(orgId, "/analytics/fleet")),
    enabled: Boolean(orgId),
  });
}

export function useLemons(orgId: string | null) {
  return useQuery({
    queryKey: ["fleet", "lemons", orgId],
    queryFn: () => apiGet<LemonReport>(orgPath(orgId, "/analytics/lemons")),
    enabled: Boolean(orgId),
  });
}

// ── Vehicles ──

export function useVehicles(orgId: string | null) {
  return useQuery({
    queryKey: ["fleet", "vehicles", orgId],
    queryFn: () => apiGet<{ items: FleetVehicle[] }>(orgPath(orgId, "/vehicles")),
    enabled: Boolean(orgId),
  });
}

export function useCreateVehicle(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: VehicleCreateInput) =>
      apiPost<FleetVehicle>(orgPath(orgId, "/vehicles"), body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "vehicles", orgId] });
      qc.invalidateQueries({ queryKey: ["fleet", "analytics", orgId] });
    },
  });
}

export function useUpdateVehicleStatus(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ vehicleId, status }: { vehicleId: string; status: string }) =>
      apiPatch<FleetVehicle>(orgPath(orgId, `/vehicles/${vehicleId}`), { status }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "vehicles", orgId] });
    },
  });
}

export function useBulkVehicleStatus(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      vehicleIds,
      status,
    }: {
      vehicleIds: string[];
      status: string;
    }) => {
      const results: { vehicleId: string; ok: boolean; message?: string }[] = [];
      for (const vehicleId of vehicleIds) {
        try {
          await apiPatch<FleetVehicle>(orgPath(orgId, `/vehicles/${vehicleId}`), {
            status,
          });
          results.push({ vehicleId, ok: true });
        } catch (error) {
          results.push({
            vehicleId,
            ok: false,
            message: error instanceof Error ? error.message : "Failed",
          });
        }
      }
      return results;
    },
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "vehicles", orgId] });
    },
  });
}

export function useVehicleAnalytics(orgId: string | null, vehicleId: string | null) {
  return useQuery({
    queryKey: ["fleet", "vehicle-analytics", orgId, vehicleId],
    queryFn: () =>
      apiGet<Record<string, number>>(
        orgPath(orgId, `/analytics/vehicle/${vehicleId}`),
      ),
    enabled: Boolean(orgId && vehicleId),
  });
}

export function useImportVehicleCsv(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (file: File) => {
      const token = await ensureFreshToken();
      const form = new FormData();
      form.append("file", file);
      const res = await fetch(`${apiBaseUrl()}${orgPath(orgId, "/vehicles/import")}`, {
        method: "POST",
        headers: token ? { authorization: `Bearer ${token}` } : undefined,
        body: form,
      });
      if (!res.ok) throw await parseApiError(res);
      return (await res.json()) as ImportJob;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "vehicles", orgId] });
    },
  });
}

export function useImportJob(orgId: string | null, jobId: string | null) {
  return useQuery({
    queryKey: ["fleet", "import-job", orgId, jobId],
    queryFn: () =>
      apiGet<ImportJob>(orgPath(orgId, `/vehicles/import/${jobId}`)),
    enabled: Boolean(orgId && jobId),
    refetchInterval: (query) =>
      query.state.data?.status === "processing" ? 1500 : false,
  });
}

export async function downloadReport(
  orgId: string,
  type: "vehicles" | "fleet" | "lemons",
): Promise<void> {
  const token = await ensureFreshToken();
  const res = await fetch(
    `${apiBaseUrl()}${orgPath(orgId, `/reports/export?type=${type}`)}`,
    { headers: token ? { authorization: `Bearer ${token}` } : undefined },
  );
  if (!res.ok) throw await parseApiError(res);
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `fleet-${type}-${new Date().toISOString().slice(0, 10)}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

// ── Members ──

export function useMembers(orgId: string | null) {
  return useQuery({
    queryKey: ["fleet", "members", orgId],
    queryFn: () => apiGet<{ items: OrgMember[] }>(orgPath(orgId, "/members")),
    enabled: Boolean(orgId),
  });
}

export function useInviteMember(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: { email: string; role: string }) =>
      apiPost<OrgMember>(orgPath(orgId, "/members"), body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "members", orgId] });
    },
  });
}

export function useUpdateMember(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      userId,
      ...body
    }: { userId: string; role?: string; remove?: boolean }) =>
      apiPatch<OrgMember | void>(orgPath(orgId, `/members/${userId}`), body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "members", orgId] });
    },
  });
}

// ── Workshops ──

export function useWorkshops(orgId: string | null) {
  return useQuery({
    queryKey: ["fleet", "workshops", orgId],
    queryFn: () => apiGet<{ items: OrgWorkshop[] }>(orgPath(orgId, "/workshops")),
    enabled: Boolean(orgId),
  });
}

export function useApproveWorkshop(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (partnerId: string) =>
      apiPost<OrgWorkshop>(orgPath(orgId, "/workshops"), { partner_id: partnerId }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "workshops", orgId] });
    },
  });
}

export function useRevokeWorkshop(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (partnerId: string) =>
      apiDelete(orgPath(orgId, `/workshops/${partnerId}`)),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "workshops", orgId] });
    },
  });
}

// ── Warranty templates ──

export function useWarrantyTemplates(orgId: string | null) {
  return useQuery({
    queryKey: ["fleet", "warranty-templates", orgId],
    queryFn: () =>
      apiGet<{ items: WarrantyTemplate[] }>(orgPath(orgId, "/warranty-templates")),
    enabled: Boolean(orgId),
  });
}

export function useCreateWarrantyTemplate(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: {
      name: string;
      duration_years: number;
      mileage_limit_km: number;
      coverage_categories?: string[];
      exclusions?: string | null;
      approved_workshop_ids?: string[];
    }) => apiPost<WarrantyTemplate>(orgPath(orgId, "/warranty-templates"), body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "warranty-templates", orgId] });
    },
  });
}

export function useUpdateWarrantyTemplate(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      id,
      ...body
    }: {
      id: string;
      name?: string;
      duration_years?: number;
      mileage_limit_km?: number;
      coverage_categories?: string[];
      exclusions?: string | null;
      approved_workshop_ids?: string[];
    }) => apiPatch<WarrantyTemplate>(orgPath(orgId, `/warranty-templates/${id}`), body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "warranty-templates", orgId] });
    },
  });
}

export function useDeleteWarrantyTemplate(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      apiDelete(orgPath(orgId, `/warranty-templates/${id}`)),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "warranty-templates", orgId] });
    },
  });
}

// ── Work orders ──

export function useWorkOrders(orgId: string | null) {
  return useQuery({
    queryKey: ["fleet", "work-orders", orgId],
    queryFn: () => apiGet<{ items: WorkOrder[] }>(orgPath(orgId, "/work-orders")),
    enabled: Boolean(orgId),
  });
}

export function useUpdateWorkOrder(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      id,
      ...body
    }: {
      id: string;
      status?: string;
      assigned_to?: string | null;
      resolution_notes?: string | null;
    }) => apiPatch<WorkOrder>(orgPath(orgId, `/work-orders/${id}`), body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "work-orders", orgId] });
      qc.invalidateQueries({ queryKey: ["fleet", "analytics", orgId] });
    },
  });
}

// ── Inspections ──

export function useInspectionTemplates(orgId: string | null) {
  return useQuery({
    queryKey: ["fleet", "inspection-templates", orgId],
    queryFn: () =>
      apiGet<{ items: InspectionTemplate[] }>(
        orgPath(orgId, "/inspection-templates"),
      ),
    enabled: Boolean(orgId),
  });
}

export function useCreateInspectionTemplate(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: {
      name: string;
      items: { item_name: string; required: boolean }[];
    }) =>
      apiPost<InspectionTemplate>(orgPath(orgId, "/inspection-templates"), body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "inspection-templates", orgId] });
    },
  });
}

export function useDeleteInspectionTemplate(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      apiDelete(orgPath(orgId, `/inspection-templates/${id}`)),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "inspection-templates", orgId] });
    },
  });
}

export function useInspections(orgId: string | null) {
  return useQuery({
    queryKey: ["fleet", "inspections", orgId],
    queryFn: () => apiGet<{ items: Inspection[] }>(orgPath(orgId, "/inspections")),
    enabled: Boolean(orgId),
  });
}

// ── Assignments ──

export function useAssignments(orgId: string | null) {
  return useQuery({
    queryKey: ["fleet", "assignments", orgId],
    queryFn: () => apiGet<{ items: Assignment[] }>(orgPath(orgId, "/assignments")),
    enabled: Boolean(orgId),
  });
}

export function useCreateAssignment(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: { vehicle_id: string; driver_id: string }) =>
      apiPost<Assignment>(orgPath(orgId, "/assignments"), body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "assignments", orgId] });
      qc.invalidateQueries({ queryKey: ["fleet", "vehicles", orgId] });
    },
  });
}

export function useRemoveAssignment(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (assignmentId: string) =>
      apiDelete(orgPath(orgId, `/assignments/${assignmentId}`)),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "assignments", orgId] });
      qc.invalidateQueries({ queryKey: ["fleet", "vehicles", orgId] });
    },
  });
}

// ── Transferred ──

export function useTransferred(orgId: string | null) {
  return useQuery({
    queryKey: ["fleet", "transferred", orgId],
    queryFn: () =>
      apiGet<{ items: TransferredVehicle[] }>(orgPath(orgId, "/transferred")),
    enabled: Boolean(orgId),
  });
}

// ── Org settings ──

export function useUpdateLemonThreshold(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: { multiplier?: number; absolute_cost_per_km?: number }) =>
      apiPost<{ lemon_threshold: unknown }>(
        orgPath(orgId, "/analytics/lemon-threshold"),
        body,
      ),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "organization"] });
      qc.invalidateQueries({ queryKey: ["fleet", "analytics", orgId] });
      qc.invalidateQueries({ queryKey: ["fleet", "lemons", orgId] });
    },
  });
}
