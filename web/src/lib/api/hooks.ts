"use client";

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
    mutationFn: ({ id, plan }: { id: string; plan: "free" | "premium" }) =>
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
      plan?: "free" | "premium";
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
      plan?: "free" | "premium";
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
