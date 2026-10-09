"use client";

import type { Plan } from "../plans";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiDelete, apiGet, apiPatch, apiPost } from "./client";
import type { components } from "./schema";

type AdminDashboard = components["schemas"]["AdminDashboard"];
type AdminUserListItem = components["schemas"]["AdminUserListItem"];
type AdminUserProfile = components["schemas"]["AdminUserProfile"];
type Partner = components["schemas"]["Partner"];
type PartnerWrite = components["schemas"]["PartnerWrite"];

// ── Dashboard ──

export function useAdminDashboard() {
  return useQuery({
    queryKey: ["admin", "dashboard"],
    queryFn: () => apiGet<AdminDashboard>("/admin/dashboard"),
  });
}

// ── Users ──

export function useAdminUsers(query: { q?: string; status?: string }) {
  const params = new URLSearchParams();
  if (query.q) params.set("q", query.q);
  if (query.status) params.set("status", query.status);
  const qs = params.toString();
  const path = `/admin/users${qs ? `?${qs}` : ""}`;

  return useQuery({
    queryKey: ["admin", "users", query],
    queryFn: () => apiGet<{ items?: AdminUserListItem[] }>(path),
  });
}

export function useAdminUser(id: string | null) {
  return useQuery({
    queryKey: ["admin", "users", id],
    queryFn: () => apiGet<AdminUserProfile>(`/admin/users/${id}`),
    enabled: Boolean(id),
  });
}

export function useUpdateUserPlan() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, plan }: { id: string; plan: Plan }) =>
      apiPatch<AdminUserProfile>(`/admin/users/${id}`, { plan }),
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ["admin", "users"] });
      qc.invalidateQueries({ queryKey: ["admin", "users", variables.id] });
    },
  });
}

export function useDeactivateUser() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      apiPost<AdminUserProfile>(`/admin/users/${id}/deactivate`),
    onSuccess: (_data, id) => {
      qc.invalidateQueries({ queryKey: ["admin", "users"] });
      qc.invalidateQueries({ queryKey: ["admin", "users", id] });
    },
  });
}

export function useReactivateUser() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      apiPost<AdminUserProfile>(`/admin/users/${id}/reactivate`),
    onSuccess: (_data, id) => {
      qc.invalidateQueries({ queryKey: ["admin", "users"] });
      qc.invalidateQueries({ queryKey: ["admin", "users", id] });
    },
  });
}

export function useSendPasswordReset() {
  return useMutation({
    mutationFn: (id: string) =>
      apiPost<void>(`/admin/users/${id}/send-password-reset`),
  });
}

export function useCreateUser() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: {
      email: string;
      temporary_password: string;
      display_name?: string;
      role?: "owner" | "admin";
      plan?: Plan;
    }) => apiPost<AdminUserProfile>("/admin/users", body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "users"] });
    },
  });
}

export function useDeleteUser() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      apiPost<void>(`/admin/users/${id}/delete`),
    onSuccess: (_data, id) => {
      qc.invalidateQueries({ queryKey: ["admin", "users"] });
      qc.invalidateQueries({ queryKey: ["admin", "users", id] });
    },
  });
}

export function useUpdateUserProfile() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      id,
      ...body
    }: {
      id: string;
      display_name?: string | null;
      contact_phone?: string | null;
      address?: string | null;
      plan?: Plan;
    }) => apiPatch<AdminUserProfile>(`/admin/users/${id}/profile`, body),
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ["admin", "users"] });
      qc.invalidateQueries({ queryKey: ["admin", "users", variables.id] });
    },
  });
}

// ── Partners ──

export function useAdminPartners(query: {
  q?: string;
  type?: string;
  status?: string;
}) {
  const params = new URLSearchParams();
  if (query.q) params.set("q", query.q);
  if (query.type) params.set("type", query.type);
  if (query.status) params.set("status", query.status);
  const qs = params.toString();
  const path = `/admin/partners${qs ? `?${qs}` : ""}`;

  return useQuery({
    queryKey: ["admin", "partners", query],
    queryFn: () => apiGet<{ items?: Partner[] }>(path),
  });
}

export function useAdminPartner(id: string | null) {
  return useQuery({
    queryKey: ["admin", "partners", id],
    queryFn: () => apiGet<Partner>(`/admin/partners/${id}`),
    enabled: Boolean(id),
  });
}

export function useCreatePartner() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: PartnerWrite) =>
      apiPost<Partner>("/admin/partners", body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "partners"] });
    },
  });
}

export function useUpdatePartner() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...body }: PartnerWrite & { id: string }) =>
      apiPatch<Partner>(`/admin/partners/${id}`, body),
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ["admin", "partners"] });
      qc.invalidateQueries({ queryKey: ["admin", "partners", variables.id] });
    },
  });
}

// ── Organizations ──

type AdminOrganization = components["schemas"]["AdminOrganization"];
type AdminOrganizationDetail = components["schemas"]["AdminOrganizationDetail"];
type AdminOrganizationCreated = components["schemas"]["AdminOrganizationCreated"];
type AdminOrganizationStatus = components["schemas"]["AdminOrganizationStatus"];

export function useAdminOrganizations(query: { q?: string; status?: string }) {
  const params = new URLSearchParams();
  if (query.q) params.set("q", query.q);
  if (query.status) params.set("status", query.status);
  const qs = params.toString();
  const path = `/admin/organizations${qs ? `?${qs}` : ""}`;

  return useQuery({
    queryKey: ["admin", "organizations", query],
    queryFn: () => apiGet<{ items?: AdminOrganization[] }>(path),
  });
}

export function useAdminOrganization(id: string | null) {
  return useQuery({
    queryKey: ["admin", "organizations", id],
    queryFn: () => apiGet<AdminOrganizationDetail>(`/admin/organizations/${id}`),
    enabled: Boolean(id),
  });
}

export function useCreateOrganization() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: {
      name: string;
      type: AdminOrganization["type"];
      admin_email: string;
      admin_password?: string;
      contact_email?: string;
      contact_phone?: string;
    }) => apiPost<AdminOrganizationCreated>("/admin/organizations", body),
    onSuccess: (data) => {
      qc.invalidateQueries({ queryKey: ["admin", "organizations"] });
      qc.invalidateQueries({ queryKey: ["admin", "dashboard"] });
      return data;
    },
  });
}

export function useUpdateOrganization() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      id,
      ...body
    }: {
      id: string;
      name?: string;
      type?: AdminOrganization["type"];
      contact_email?: string | null;
      contact_phone?: string | null;
    }) => apiPatch<AdminOrganization>(`/admin/organizations/${id}`, body),
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ["admin", "organizations"] });
      qc.invalidateQueries({ queryKey: ["admin", "organizations", variables.id] });
    },
  });
}

export function useUpdateOrganizationStatus() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      id,
      status,
    }: {
      id: string;
      status: "active" | "suspended" | "archived";
    }) =>
      apiPatch<AdminOrganizationStatus>(`/admin/organizations/${id}/status`, {
        status,
      }),
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ["admin", "organizations"] });
      qc.invalidateQueries({ queryKey: ["admin", "organizations", variables.id] });
    },
  });
}

export function useResendOrganizationInvite() {
  return useMutation({
    mutationFn: (organizationId: string) =>
      apiPost<void>("/admin/support/invite-resend", {
        organization_id: organizationId,
      }),
  });
}

// ── Maintenance Catalog ──

type CatalogItem = components["schemas"]["MaintenanceCatalogItem"];
type CatalogItemWrite = components["schemas"]["MaintenanceCatalogItemWrite"];

export function useCatalogItems() {
  return useQuery({
    queryKey: ["admin", "catalog"],
    queryFn: () => apiGet<{ items?: CatalogItem[] }>("/admin/maintenance-catalog"),
  });
}

export function useCreateCatalogItem() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: CatalogItemWrite) =>
      apiPost<CatalogItem>("/admin/maintenance-catalog", body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "catalog"] });
    },
  });
}

export function useUpdateCatalogItem() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...body }: CatalogItemWrite & { id: string }) =>
      apiPatch<CatalogItem>(`/admin/maintenance-catalog/${id}`, body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "catalog"] });
    },
  });
}

export function useDeleteCatalogItem() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      apiDelete(`/admin/maintenance-catalog/${id}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "catalog"] });
    },
  });
}

// ── Organization Drivers (admin cross-org) ──

export type AdminOrgDriver = {
  user_id: string;
  username: string;
  display_name: string | null;
  email: string | null;
  status: "active" | "deactivated";
  must_change_password: boolean;
  joined_at: string;
};

export function useAdminOrgDrivers(orgId: string | null) {
  return useQuery({
    queryKey: ["admin", "organizations", orgId, "drivers"],
    queryFn: () => apiGet<{ items?: AdminOrgDriver[] }>(`/admin/organizations/${orgId}/drivers`),
    enabled: Boolean(orgId),
  });
}

export function useCreateOrgDriver() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      orgId,
      ...body
    }: {
      orgId: string;
      username: string;
      display_name: string;
      password: string;
    }) => apiPost<{ id: string; username: string; display_name: string | null; must_change_password: boolean }>(`/admin/organizations/${orgId}/drivers`, body),
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ["admin", "organizations", variables.orgId, "drivers"] });
      qc.invalidateQueries({ queryKey: ["admin", "organizations", variables.orgId] });
    },
  });
}

export function useUpdateOrgDriverStatus() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      orgId,
      userId,
      status,
    }: {
      orgId: string;
      userId: string;
      status: "active" | "deactivated";
    }) => apiPatch<{ status: string; user_id: string }>(`/admin/organizations/${orgId}/drivers/${userId}/status`, { status }),
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ["admin", "organizations", variables.orgId, "drivers"] });
      qc.invalidateQueries({ queryKey: ["admin", "organizations", variables.orgId] });
    },
  });
}

// ── Admin Fleet View ──

export type AdminFleetView = {
  organizations: {
    id: string;
    name: string;
    type: string;
    plan: string;
    status: string;
    member_count: number;
    vehicle_count: number;
  }[];
};

export function useAdminFleetView() {
  return useQuery({
    queryKey: ["admin", "fleet-view"],
    queryFn: () => apiGet<AdminFleetView>("/admin/fleet-view"),
  });
}

// ── Vehicle sharing (owner surface) ──

export type ShareAccessLevel = "view" | "add_edit_own";

export type VehicleShareRow = {
  id: string;
  vehicle_id: string;
  user_id: string;
  granted_by: string | null;
  access_level: ShareAccessLevel;
  status: "pending" | "active" | "revoked";
  invited_email: string | null;
  share_code: string | null;
  accepted_at: string | null;
  created_at: string;
  display_name: string | null;
  email: string | null;
};

export type ShareInvitationRow = {
  id: string;
  vehicle_id: string;
  invited_email: string | null;
  access_level: ShareAccessLevel;
  share_code: string | null;
  expires_at: string;
  created_at: string;
  accepted_at: string | null;
};

export type VehicleSharesDetail = {
  vehicle: {
    id: string;
    name: string;
    nickname: string | null;
    license_plate: string;
    make: string;
    model: string;
    year: number;
  };
  shares: VehicleShareRow[];
  pending_invites: ShareInvitationRow[];
  share_code: string | null;
  qr_code_data: { code: string; vehicle_id: string; expires_at: string } | null;
  limits: { per_vehicle: number; total: number; active_on_vehicle: number };
};

export type OwnerVehicle = {
  id: string;
  name: string;
  nickname: string | null;
  make: string;
  model: string;
  year: number;
  license_plate: string;
  archived: boolean;
  source?: "owned" | "shared";
  access_level?: ShareAccessLevel;
  owner?: { id: string; display_name: string | null; email: string | null };
};

export type CreatedShare = ShareInvitationRow & {
  invite_token?: string;
  invite_url?: string;
  share_code?: string | null;
  qr_code_data?: { code: string; vehicle_id: string; expires_at: string } | null;
  join_url?: string;
};

const shareKeys = (vehicleId: string) => ["vehicle", vehicleId, "shares"];

export function useOwnedVehicles() {
  return useQuery({
    queryKey: ["owner", "vehicles"],
    queryFn: () => apiGet<{ items?: OwnerVehicle[] }>("/vehicles"),
  });
}

export function useSharedVehicles() {
  return useQuery({
    queryKey: ["owner", "vehicles", "shared"],
    queryFn: () => apiGet<{ items?: OwnerVehicle[] }>("/vehicles/shared"),
  });
}

export function useVehicleShares(vehicleId: string | null) {
  return useQuery({
    queryKey: shareKeys(vehicleId ?? ""),
    queryFn: () => apiGet<VehicleSharesDetail>(`/vehicles/${vehicleId}/shares`),
    enabled: Boolean(vehicleId),
  });
}

export function useCreateVehicleShare(vehicleId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: {
      method: "email" | "code_qr";
      email?: string;
      access_level?: ShareAccessLevel;
    }) => apiPost<CreatedShare>(`/vehicles/${vehicleId}/shares`, body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: shareKeys(vehicleId) });
    },
  });
}

export function useUpdateVehicleShare(vehicleId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      shareId,
      ...body
    }: {
      shareId: string;
      access_level?: ShareAccessLevel;
      regenerate_code?: boolean;
    }) => apiPatch<VehicleShareRow>(`/vehicles/${vehicleId}/shares/${shareId}`, body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: shareKeys(vehicleId) });
    },
  });
}

export function useRevokeVehicleShare(vehicleId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (shareId: string) =>
      apiDelete(`/vehicles/${vehicleId}/shares/${shareId}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: shareKeys(vehicleId) });
    },
  });
}

export function useResendShareInvite(vehicleId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (inviteId: string) =>
      apiPost<ShareInvitationRow>(
        `/vehicles/${vehicleId}/invitations/${inviteId}/resend`,
      ),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: shareKeys(vehicleId) });
    },
  });
}

export function useCancelShareInvite(vehicleId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (inviteId: string) =>
      apiDelete(`/vehicles/${vehicleId}/invitations/${inviteId}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: shareKeys(vehicleId) });
    },
  });
}
