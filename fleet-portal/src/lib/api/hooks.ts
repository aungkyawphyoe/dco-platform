"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiDelete, apiGet, apiPatch, apiPost, apiPut, apiRequest } from "./client";
import { parseApiError } from "@/lib/api/errors";
import type {
  Assignment,
  FleetAnalytics,
  FleetVehicle,
  ImportJob,
  Inspection,
  InspectionTemplate,
  InviteMemberResult,
  LemonReport,
  OrgContext,
  OrgMember,
  OrgWorkshop,
  TransferredVehicle,
  VehicleCostMetrics,
  VehicleCreateInput,
  VehiclePlanItem,
  VehicleServiceRecord,
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
    mutationFn: ({ vehicleId, status, expectedStatus }: { vehicleId: string; status: string; expectedStatus: string }) =>
      apiPatch<FleetVehicle>(orgPath(orgId, `/vehicles/${vehicleId}`), { status, expected_status: expectedStatus }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "vehicles", orgId] });
    },
  });
}

export function useVehicleAnalytics(orgId: string | null, vehicleId: string | null) {
  return useQuery({
    queryKey: ["fleet", "vehicle-analytics", orgId, vehicleId],
    queryFn: () =>
      apiGet<VehicleCostMetrics>(
        orgPath(orgId, `/analytics/vehicle/${vehicleId}`),
      ),
    enabled: Boolean(orgId && vehicleId),
  });
}

export function useImportVehicleCsv(orgId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (file: File) => {
      const form = new FormData();
      form.append("file", file);
      const res = await apiRequest(orgPath(orgId, "/vehicles/import"), {
        method: "POST",
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
  const res = await apiRequest(orgPath(orgId, `/reports/export?type=${type}`));
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
    mutationFn: (body: { email: string; role: string; temporary_password?: string }) =>
      apiPost<InviteMemberResult>(orgPath(orgId, "/members"), body),
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
      completion_cost?: number;
      currency?: string;
    }) => apiPatch<WorkOrder>(orgPath(orgId, `/work-orders/${id}`), body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["fleet", "work-orders", orgId] });
      qc.invalidateQueries({ queryKey: ["fleet", "currency", orgId] });
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

// ── Vehicle detail: service history + maintenance plan (read-only) ──

export function useVehicleServiceRecords(orgId: string | null, vehicleId: string | null) {
  return useQuery({
    queryKey: ["fleet", "vehicle-service-records", orgId, vehicleId],
    queryFn: () =>
      apiGet<{ items: VehicleServiceRecord[] }>(
        orgPath(orgId, `/vehicles/${vehicleId}/service-records`),
      ),
    enabled: Boolean(orgId && vehicleId),
  });
}

export function useVehiclePlanItems(orgId: string | null, vehicleId: string | null) {
  return useQuery({
    queryKey: ["fleet", "vehicle-plan", orgId, vehicleId],
    queryFn: () =>
      apiGet<{ items: VehiclePlanItem[] }>(
        orgPath(orgId, `/vehicles/${vehicleId}/plan-items`),
      ),
    enabled: Boolean(orgId && vehicleId),
  });
}

export type SuggestedService = { catalog_key: string; name: string; source?: "global" | "org" };
export type ReminderWrite = {
  notes?: string | null;
  id: string;
  name: string;
  catalog_key: string | null;
  time_count?: number | null;
  time_unit?: "days" | "months" | "years" | null;
  warning_days?: number | null;
  warning_distance?: number | null;
  interval_days: number | null;
  interval_distance: number | null;
  next_due_on: string | null;
  next_due_mileage: number | null;
  enabled: boolean;
};

export function useServiceCatalog(orgId: string | null) {
  return useQuery({
    queryKey: ["fleet", "service-catalog", orgId],
    queryFn: () => apiGet<{ items: SuggestedService[] }>(orgPath(orgId, "/maintenance-catalog")),
    enabled: Boolean(orgId),
  });
}

export function useCreateServiceCatalogItem(orgId: string | null) {
  const cache = useQueryClient();
  return useMutation({
    mutationFn: (name: string) => apiPost<SuggestedService>(orgPath(orgId, "/maintenance-catalog"), { name }),
    onSuccess: () => cache.invalidateQueries({ queryKey: ["fleet", "service-catalog", orgId] }),
  });
}

export function useSaveReminder(orgId: string | null, vehicleId: string) {
  const cache = useQueryClient();
  return useMutation({
    mutationFn: ({ body, editing }: { body: ReminderWrite; editing: boolean }) =>
      editing
        ? apiPut<VehiclePlanItem>(orgPath(orgId, `/vehicles/${vehicleId}/plan-items`), body)
        : apiPost<VehiclePlanItem>(orgPath(orgId, `/vehicles/${vehicleId}/plan-items`), body),
    onSuccess: () => cache.invalidateQueries({ queryKey: ["fleet", "vehicle-plan", orgId, vehicleId] }),
  });
}
