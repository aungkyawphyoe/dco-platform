export type OrgContext = {
  organization: {
    id: string;
    name: string;
    type: string;
    plan: string;
    status: string;
    role: string;
    contact_email: string | null;
    contact_phone: string | null;
  } | null;
  fleet_access: boolean;
};

export type OrgMember = {
  user_id: string;
  email: string;
  display_name: string | null;
  role: string;
};

export type FleetVehicle = {
  id: string;
  name: string;
  make: string;
  model: string;
  year: number;
  license_plate: string;
  vin: string;
  fuel_type: string;
  mileage: number;
  mileage_unit?: string;
  lifecycle_template: string;
  status: string;
  revenue_label: string | null;
  assigned_driver_id: string | null;
  added_at: string | null;
};

export type WorkOrder = {
  id: string;
  org_id: string;
  vehicle_id: string;
  reported_by: string;
  reported_at: string | null;
  odometer_km: number;
  issue_type: string;
  description: string;
  urgency: string;
  photos: string[];
  status: string;
  assigned_to: string | null;
  resolved_by: string | null;
  resolved_at: string | null;
  resolution_notes: string | null;
  created_at: string | null;
  updated_at: string | null;
};

export type InspectionTemplateItem = {
  item_name: string;
  required: boolean;
};

export type InspectionTemplate = {
  id: string;
  org_id: string;
  name: string;
  items: InspectionTemplateItem[];
  created_at: string | null;
  updated_at: string | null;
};

export type InspectionItemResult = {
  item_name: string;
  result: string;
  photo_media_id?: string | null;
  notes?: string | null;
  required?: boolean;
};

export type Inspection = {
  id: string;
  org_id: string;
  vehicle_id: string;
  driver_id: string;
  template_id: string;
  inspection_type: string;
  started_at: string | null;
  completed_at: string | null;
  status: string;
  items: InspectionItemResult[];
  notes: string | null;
  created_at: string | null;
};

export type Assignment = {
  id: string;
  org_id: string;
  vehicle_id: string;
  driver_id: string;
  assigned_by: string;
  assigned_at: string | null;
  unassigned_at: string | null;
  status: string;
};

export type OrgWorkshop = {
  id: string;
  name: string;
  status: string;
  contact_email: string | null;
  contact_phone: string | null;
  added_at: string | null;
};

export type WarrantyTemplate = {
  id: string;
  org_id: string;
  name: string;
  duration_years: number;
  mileage_limit_km: number;
  coverage_categories: string[];
  exclusions: string | null;
  approved_workshop_ids: string[];
  created_at: string | null;
  updated_at: string | null;
};

export type TransferredVehicle = {
  id: string;
  vehicle: {
    id: string;
    name: string;
    make: string;
    model: string;
    year: number;
    plate: string;
  };
  buyer_user_id: string | null;
  transferred_by: string;
  transferred_at: string | null;
  warranty_instance_id: string | null;
};

export type VehicleCostMetric = {
  vehicle_id?: string;
  tco: number;
  total_km_driven: number;
  cost_per_km: number;
  [key: string]: unknown;
};

export type FleetAnalytics = {
  vehicle_count: number;
  total_fleet_spend: number;
  average_cost_per_km: number;
  lemon_count: number;
  open_work_orders: number;
  active_assignments: number;
  upcoming_maintenance_count: number;
  vehicles: VehicleCostMetric[];
};

export type LemonReport = {
  threshold_cost_per_km: number;
  items: (VehicleCostMetric & { name?: string; license_plate?: string })[];
};

export type ImportJob = {
  job_id: string;
  status: string;
  total_rows?: number;
  results?: { error?: string; plate?: string; [key: string]: unknown }[];
  completed_at?: string | null;
};

export type VehicleCreateInput = {
  id: string;
  name: string;
  make: string;
  model: string;
  year: number;
  license_plate: string;
  vin: string;
  fuel_type: "petrol" | "electric" | "hybrid_plugin";
  mileage: number;
  lifecycle_template: "showroom" | "taxi_fleet" | "rental" | "commercial";
  revenue_label?: string | null;
};

export const lifecycleTransitions: Record<string, Record<string, string[]>> = {
  showroom: {
    inventory: ["listed"],
    listed: ["inventory", "reserved"],
    reserved: ["listed", "sold"],
    sold: [],
  },
  taxi_fleet: {
    available: ["leased", "maintenance"],
    leased: ["maintenance", "available"],
    maintenance: ["available"],
  },
  rental: {
    available: ["rented"],
    rented: ["return"],
    return: ["inspection"],
    inspection: ["available"],
  },
  commercial: {
    available: ["in_service", "maintenance"],
    in_service: ["maintenance", "retired"],
    maintenance: ["available", "in_service", "retired"],
    retired: [],
  },
};

export const orgRoleLabel: Record<string, string> = {
  org_admin: "Org Admin",
  org_manager: "Manager",
  org_mechanic: "Mechanic",
  org_driver: "Driver",
};

export const workOrderStatusTone: Record<string, "success" | "warning" | "danger" | "info" | "neutral"> = {
  reported: "warning",
  in_progress: "info",
  completed: "success",
};

export const inspectionStatusTone: Record<string, "success" | "warning" | "danger" | "info" | "neutral"> = {
  in_progress: "info",
  completed: "success",
  failed: "danger",
};
