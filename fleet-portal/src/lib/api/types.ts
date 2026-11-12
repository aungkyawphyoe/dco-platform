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
  license_expiry_date?: string | null;
  license_status?: "valid" | "expired" | "expiring_soon" | null;
  status: "active" | "deactivated";
  user_id: string;
  email: string;
  display_name: string | null;
  role: string;
  can_complete_handover?: boolean;
};

export type InviteMemberResult = OrgMember & {
  account_created: boolean;
  temporary_password: string | null;
};

export type FleetVehicle = {
  base_currency?: string | null;
  id: string;
  name: string;
  make: string;
  model: string;
  year: number;
  license_plate: string;
  vin: string;
  fuel_type: string;
  vehicle_class?: string;
  mileage: number;
  mileage_unit?: string;
  lifecycle_template: string;
  status: string;
  revenue_label: string | null;
  assigned_driver_id: string | null;
  added_at: string | null;
};

export type VehicleClass = "car" | "motorcycle" | "truck" | "van" | "bus";
export type LifecycleTemplate = "showroom" | "taxi_fleet" | "rental" | "commercial";
export type FuelType = "petrol" | "electric" | "hybrid_plugin";

export const vehicleClassOptions: { value: VehicleClass; label: string }[] = [
  { value: "car", label: "Car" },
  { value: "motorcycle", label: "Motorcycle" },
  { value: "truck", label: "Truck" },
  { value: "van", label: "Van" },
  { value: "bus", label: "Bus" },
];

export const lifecycleTemplateOptions: { value: LifecycleTemplate; label: string }[] = [
  { value: "showroom", label: "Showroom" },
  { value: "taxi_fleet", label: "Taxi fleet" },
  { value: "rental", label: "Rental" },
  { value: "commercial", label: "Commercial" },
];

export const fuelTypeOptions: { value: FuelType; label: string }[] = [
  { value: "petrol", label: "Petrol" },
  { value: "electric", label: "Electric" },
  { value: "hybrid_plugin", label: "Hybrid" },
];

export type VehiclePlanItem = {
  id: string;
  vehicle_id: string;
  name: string;
  time_count?: number | null;
  time_unit?: "days" | "months" | "years" | null;
  warning_days?: number | null;
  warning_distance?: number | null;
  interval_days?: number | null;
  interval_distance?: number | null;
  next_due_mileage?: number | null;
  next_due_on?: string | null;
  initial_service_required?: boolean;
  enabled: boolean;
  notes?: string | null;
  catalog_key?: string | null;
  created_by?: string | null;
};

// ── Showroom handover ───────────────────────────────────────────────────────

export type HandoverBuyer = {
  user_id: string;
  display_name: string | null;
  email_masked: string | null;
  phone_masked: string | null;
  eligible: boolean;
  reason: string | null;
};

export type HandoverPlanItem = {
  name: string;
  interval_days?: number | null;
  time_count?: number | null;
  time_unit?: "days" | "months" | "years" | null;
  warning_days?: number | null;
  warning_distance?: number | null;
  interval_distance?: number | null;
  next_due_on?: string | null;
  next_due_mileage?: number | null;
  initial_service_required?: boolean;
  notes?: string | null;
};

export type HandoverWarrantyChoice = "undecided" | "none" | "template";

export type HandoverWarrantySnapshot = {
  template_id: string;
  name: string;
  duration_years: number;
  mileage_limit_km: number;
  coverage_categories: string[];
  exclusions: string | null;
  approved_workshops: { id: string; name: string }[];
  captured_at: string;
};

export type HandoverIssue = {
  code: string;
  message: string;
  details?: { work_order_ids?: string[]; [key: string]: unknown };
};

export type HandoverStatus = "draft" | "completed" | "cancelled";

export type VehicleHandover = {
  id: string;
  org_id: string;
  vehicle_id: string;
  buyer: HandoverBuyer;
  status: HandoverStatus;
  revision: number;
  reviewed_revision: number | null;
  reviewed_by: string | null;
  reviewed_at: string | null;
  sale_date: string | null;
  current_mileage_km: number | null;
  plan: HandoverPlanItem[];
  warranty_choice: HandoverWarrantyChoice;
  warranty_template_id: string | null;
  warranty: HandoverWarrantySnapshot | null;
  result: Record<string, unknown> | null;
  cancellation_reason: string | null;
  created_by: string;
  created_at: string | null;
  updated_at: string | null;
  completed_by: string | null;
  completed_at: string | null;
  cancelled_by: string | null;
  cancelled_at: string | null;
};

export type VehicleHandoverDetail = VehicleHandover & {
  blocking_issues: HandoverIssue[];
  ready_to_review: boolean;
};

export type HandoverCompletion = {
  id: string;
  status: string;
  idempotent: boolean;
  vehicle_id?: string;
  buyer_user_id?: string;
  transferred_vehicle_id?: string;
  sale_date?: string;
  current_mileage_km?: number;
  plan_item_ids?: string[];
  warranty_instance_id?: string | null;
  completed_at?: string;
  delivery?: { queued: number; delivered: number };
};

export type HandoverDraftInput = {
  sale_date?: string | null;
  current_mileage_km?: number | null;
  plan?: HandoverPlanItem[];
  warranty_choice?: HandoverWarrantyChoice;
  warranty_template_id?: string | null;
};

export type ServiceRecordLine = {
  id?: string;
  plan_item_id?: string | null;
  name: string;
  line_cost?: number | null;
};

export type VehicleServiceRecord = {
  currency: string;
  id: string;
  vehicle_id: string;
  serviced_on: string;
  odometer: number;
  total_cost: number;
  workshop_name?: string | null;
  notes?: string | null;
  created_by?: string | null;
  items: ServiceRecordLine[];
};

export type WorkOrder = {
  currency: string;
  completion_cost: number | null;
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
  plan_item_id?: string | null;
  assigned_to: string | null;
  resolved_by: string | null;
  resolved_at: string | null;
  resolution_notes: string | null;
  cancellation_reason?: string | null;
  cancelled_by?: string | null;
  cancelled_at?: string | null;
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
  vehicle_name: string;
  vehicle_license_plate: string;
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

export type VehicleCostMetrics = {
  vehicle_id: string;
  tco: number;
  cost_per_km: number;
  total_km_driven: number;
  maintenance_cost: number;
  fuel_cost: number;
  wear_cost: number;
  utilization_rate: number;
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
  fuel_type: FuelType;
  vehicle_class?: VehicleClass;
  mileage: number;
  lifecycle_template: LifecycleTemplate;
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
  cancelled: "neutral",
};

export const inspectionStatusTone: Record<string, "success" | "warning" | "danger" | "info" | "neutral"> = {
  in_progress: "info",
  completed: "success",
  failed: "danger",
};
