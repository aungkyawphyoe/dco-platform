import {
  bigint,
  boolean,
  date,
  integer,
  jsonb,
  numeric,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uuid,
  index,
  unique,
  uniqueIndex,
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";

export const roleEnum = pgEnum("user_role", ["owner", "admin"]);
export const planEnum = pgEnum("user_plan", ["free", "premium"]);
export const accountStatusEnum = pgEnum("account_status", ["active", "deactivated"]);
export const vehicleFuelEnum = pgEnum("vehicle_fuel_type", ["petrol", "electric", "hybrid_plugin"]);
export const mileageUnitEnum = pgEnum("mileage_unit", ["mi", "km"]);
export const documentCategoryEnum = pgEnum("document_category", [
  "insurance",
  "registration",
  "invoice",
  "warranty",
  "receipt",
  "other",
]);
export const expenseCategoryEnum = pgEnum("expense_category", [
  "fuel",
  "maintenance",
  "insurance",
  "parking",
  "tolls",
  "parts",
  "other",
]);
export const partnerTypeEnum = pgEnum("partner_type", ["workshop", "insurer"]);
export const partnerStatusEnum = pgEnum("partner_status", [
  "draft",
  "pending_verification",
  "verified",
  "rejected",
]);
export const fuelKindEnum = pgEnum("fuel_kind", ["liquid", "electric"]);
export const fuelLogKindEnum = pgEnum("fuel_log_kind", ["refuel", "charge"]);
export const changeOpEnum = pgEnum("change_op", ["upsert", "archive", "delete"]);
export const notificationStatusEnum = pgEnum("notification_status", [
  "unread",
  "read",
  "done",
  "dismissed",
]);
export const dueReasonEnum = pgEnum("due_reason", ["date", "mileage", "both"]);
export const familyRoleEnum = pgEnum("family_role", ["primary_owner", "member", "driver"]);
export const grantPermissionEnum = pgEnum("grant_permission", ["full", "drive_only"]);
export const familyStatusEnum = pgEnum("family_status", ["active", "archived"]);
export const organizationTypeEnum = pgEnum("organization_type", [
  "showroom",
  "dealership",
  "taxi_fleet",
  "rental",
  "commercial",
  "logistics",
]);
export const organizationPlanEnum = pgEnum("organization_plan", ["enterprise"]);
export const organizationStatusEnum = pgEnum("organization_status", ["pending", "active", "suspended", "archived"]);
export const organizationRoleEnum = pgEnum("organization_role", ["org_admin", "org_manager", "org_mechanic", "org_driver"]);
export const lifecycleTemplateEnum = pgEnum("lifecycle_template", ["showroom", "taxi_fleet", "rental", "commercial"]);
export const assignmentStatusEnum = pgEnum("assignment_status", ["active", "completed"]);
export const workOrderIssueTypeEnum = pgEnum("work_order_issue_type", ["breakdown", "accident", "wear_tear", "scheduled_service", "other"]);
export const workOrderUrgencyEnum = pgEnum("work_order_urgency", ["low", "medium", "high", "critical"]);
export const workOrderStatusEnum = pgEnum("work_order_status", ["reported", "in_progress", "completed"]);
export const warrantyStatusEnum = pgEnum("warranty_status", ["active", "expired", "voided"]);
export const inspectionTypeEnum = pgEnum("inspection_type", ["pre_trip", "post_trip", "random"]);
export const inspectionStatusEnum = pgEnum("inspection_status", ["in_progress", "completed", "failed"]);
export const vehicleImportStatusEnum = pgEnum("vehicle_import_status", ["processing", "completed", "failed"]);

export const users = pgTable("users", {
  id: uuid("id").primaryKey(),
  email: text("email").notNull().unique(),
  passwordHash: text("password_hash").notNull(),
  displayName: text("display_name"),
  profilePhotoMediaId: uuid("profile_photo_media_id"),
  contactPhone: text("contact_phone"),
  address: text("address"),
  role: roleEnum("role").notNull().default("owner"),
  plan: planEnum("plan").notNull().default("free"),
  status: accountStatusEnum("status").notNull().default("active"),
  emailVerified: boolean("email_verified").notNull().default(false),
  activeVehicleId: uuid("active_vehicle_id"),
  familyId: uuid("family_id"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const vehicles = pgTable("vehicles", {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id),
  name: text("name").notNull(),
  nickname: text("nickname"),
  make: text("make").notNull(),
  model: text("model").notNull(),
  year: integer("year").notNull(),
  licensePlate: text("license_plate").notNull(),
  vin: text("vin"),
  color: text("color"),
  fuelType: vehicleFuelEnum("fuel_type").notNull(),
  mileage: numeric("mileage", { precision: 12, scale: 1 }).notNull(),
  mileageUnit: mileageUnitEnum("mileage_unit").notNull().default("mi"),
  purchaseDate: date("purchase_date"),
  purchasePrice: numeric("purchase_price", { precision: 12, scale: 2 }),
  photoMediaId: uuid("photo_media_id"),
  archived: boolean("archived").notNull().default(false),
  archivedAt: timestamp("archived_at", { withTimezone: true }),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const refreshTokens = pgTable("refresh_tokens", {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id),
  familyId: uuid("family_id").notNull(),
  tokenHash: text("token_hash").notNull(),
  audience: text("audience").notNull().default("dco-owner"),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  revokedAt: timestamp("revoked_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const emailTokens = pgTable("email_tokens", {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id),
  purpose: text("purpose").notNull(),
  tokenHash: text("token_hash").notNull(),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  usedAt: timestamp("used_at", { withTimezone: true }),
});

export const deviceTokens = pgTable("device_tokens", {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id),
  token: text("token").notNull(),
  platform: text("platform").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const mediaObjects = pgTable("media_objects", {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id),
  blobKey: text("blob_key").notNull(),
  contentType: text("content_type").notNull(),
  byteSize: integer("byte_size").notNull(),
  sha256: text("sha256"),
  purpose: text("purpose"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const planItems = pgTable("plan_items", {
  id: uuid("id").primaryKey(),
  vehicleId: uuid("vehicle_id")
    .notNull()
    .references(() => vehicles.id),
  name: text("name").notNull(),
  intervalDays: integer("interval_days"),
  intervalDistance: numeric("interval_distance", { precision: 12, scale: 1 }),
  nextDueMileage: numeric("next_due_mileage", { precision: 12, scale: 1 }),
  nextDueOn: date("next_due_on"),
  enabled: boolean("enabled").notNull().default(true),
  notes: text("notes"),
  catalogKey: text("catalog_key"),
});

export const serviceRecords = pgTable("service_records", {
  id: uuid("id").primaryKey(),
  vehicleId: uuid("vehicle_id")
    .notNull()
    .references(() => vehicles.id),
  servicedOn: date("serviced_on").notNull(),
  odometer: numeric("odometer", { precision: 12, scale: 1 }).notNull(),
  totalCost: numeric("total_cost", { precision: 12, scale: 2 }).notNull(),
  workshopName: text("workshop_name"),
  notes: text("notes"),
  receiptMediaId: uuid("receipt_media_id"),
});

export const serviceRecordItems = pgTable("service_record_items", {
  id: uuid("id").primaryKey(),
  serviceRecordId: uuid("service_record_id")
    .notNull()
    .references(() => serviceRecords.id),
  planItemId: uuid("plan_item_id"),
  name: text("name").notNull(),
  lineCost: numeric("line_cost", { precision: 12, scale: 2 }),
});

export const parts = pgTable("parts", {
  id: uuid("id").primaryKey(),
  vehicleId: uuid("vehicle_id")
    .notNull()
    .references(() => vehicles.id),
  name: text("name").notNull(),
  brand: text("brand"),
  partNumber: text("part_number"),
  notes: text("notes"),
});

export const serviceRecordParts = pgTable("service_record_parts", {
  id: uuid("id").primaryKey(),
  serviceRecordId: uuid("service_record_id")
    .notNull()
    .references(() => serviceRecords.id),
  partId: uuid("part_id")
    .notNull()
    .references(() => parts.id),
  name: text("name").notNull(),
});

export const fuelTypes = pgTable("fuel_types", {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id),
  name: text("name").notNull(),
  kind: fuelKindEnum("kind").notNull(),
  unit: text("unit").notNull(),
});

export const fuelLogs = pgTable("fuel_logs", {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id),
  vehicleId: uuid("vehicle_id")
    .notNull()
    .references(() => vehicles.id),
  kind: fuelLogKindEnum("kind").notNull(),
  fuelTypeId: uuid("fuel_type_id"),
  fuelTypeName: text("fuel_type_name").notNull(),
  unit: text("unit").notNull(),
  loggedOn: date("logged_on").notNull(),
  amount: numeric("amount", { precision: 12, scale: 3 }).notNull(),
  cost: numeric("cost", { precision: 12, scale: 2 }).notNull(),
});

export const documents = pgTable("documents", {
  id: uuid("id").primaryKey(),
  vehicleId: uuid("vehicle_id")
    .notNull()
    .references(() => vehicles.id),
  name: text("name").notNull(),
  category: documentCategoryEnum("category").notNull(),
  notes: text("notes"),
  mediaId: uuid("media_id"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const expenses = pgTable("expenses", {
  id: uuid("id").primaryKey(),
  vehicleId: uuid("vehicle_id")
    .notNull()
    .references(() => vehicles.id),
  category: expenseCategoryEnum("category").notNull(),
  amount: numeric("amount", { precision: 12, scale: 2 }).notNull(),
  incurredOn: date("incurred_on").notNull(),
  notes: text("notes"),
  receiptMediaId: uuid("receipt_media_id"),
});

export const expenseParts = pgTable("expense_parts", {
  id: uuid("id").primaryKey(),
  expenseId: uuid("expense_id")
    .notNull()
    .references(() => expenses.id),
  partId: uuid("part_id")
    .notNull()
    .references(() => parts.id),
  name: text("name").notNull(),
});

export const notificationFeed = pgTable("notification_feed", {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id),
  vehicleId: uuid("vehicle_id").references(() => vehicles.id),
  planItemId: uuid("plan_item_id"),
  title: text("title").notNull(),
  body: text("body").notNull(),
  status: notificationStatusEnum("status").notNull().default("unread"),
  dueReason: dueReasonEnum("due_reason"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const changeLog = pgTable("change_log", {
  seq: bigint("seq", { mode: "number" }).primaryKey().generatedAlwaysAsIdentity(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id),
  entityType: text("entity_type").notNull(),
  entityId: uuid("entity_id").notNull(),
  op: changeOpEnum("op").notNull(),
  payload: jsonb("payload").notNull(),
  serverTs: timestamp("server_ts", { withTimezone: true }).notNull().defaultNow(),
});

export const partners = pgTable("partners", {
  id: uuid("id").primaryKey(),
  name: text("name").notNull(),
  type: partnerTypeEnum("type").notNull(),
  status: partnerStatusEnum("status").notNull().default("draft"),
  contactEmail: text("contact_email"),
  contactPhone: text("contact_phone"),
  notes: text("notes"),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const auditEvents = pgTable("audit_events", {
  id: bigint("id", { mode: "number" }).primaryKey().generatedAlwaysAsIdentity(),
  adminUserId: uuid("admin_user_id")
    .notNull()
    .references(() => users.id),
  action: text("action").notNull(),
  detail: jsonb("detail").notNull(),
  at: timestamp("at", { withTimezone: true }).notNull().defaultNow(),
});

export const families = pgTable("families", {
  id: uuid("id").primaryKey(),
  name: text("name").notNull(),
  shareCode: text("share_code").notNull().unique(),
  qrCodeData: jsonb("qr_code_data"),
  createdBy: uuid("created_by")
    .notNull()
    .references(() => users.id),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  status: familyStatusEnum("status").notNull().default("active"),
  archivedAt: timestamp("archived_at", { withTimezone: true }),
});

export const familyMemberships = pgTable("family_memberships", {
  id: uuid("id").primaryKey(),
  familyId: uuid("family_id")
    .notNull()
    .references(() => families.id, { onDelete: "cascade" }),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  role: familyRoleEnum("role").notNull(),
  joinedAt: timestamp("joined_at", { withTimezone: true }).notNull().defaultNow(),
  invitedBy: uuid("invited_by").references(() => users.id),
}, (table) => ({
  uniqueFamilyUser: unique().on(table.familyId, table.userId),
  uniqueUser: unique().on(table.userId),
}));

export const vehicleGrants = pgTable("vehicle_grants", {
  id: uuid("id").primaryKey(),
  vehicleId: uuid("vehicle_id")
    .notNull()
    .references(() => vehicles.id, { onDelete: "cascade" }),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  grantedBy: uuid("granted_by")
    .notNull()
    .references(() => users.id),
  permission: grantPermissionEnum("permission").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  uniqueVehicleUser: unique().on(table.vehicleId, table.userId),
}));

export const familyVehicles = pgTable("family_vehicles", {
  id: uuid("id").primaryKey(),
  familyId: uuid("family_id")
    .notNull()
    .references(() => families.id, { onDelete: "cascade" }),
  vehicleId: uuid("vehicle_id")
    .notNull()
    .references(() => vehicles.id, { onDelete: "cascade" }),
  addedBy: uuid("added_by")
    .notNull()
    .references(() => users.id),
  addedAt: timestamp("added_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  uniqueFamilyVehicle: unique().on(table.familyId, table.vehicleId),
}));

export const drivingLicenses = pgTable("driving_licenses", {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .unique()
    .references(() => users.id, { onDelete: "cascade" }),
  licenseNumber: text("license_number"),
  issuingCountry: text("issuing_country"),
  expiryDate: date("expiry_date").notNull(),
  categories: text("categories"),
  frontMediaId: uuid("front_media_id").references(() => mediaObjects.id),
  backMediaId: uuid("back_media_id").references(() => mediaObjects.id),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const organizations = pgTable("organizations", {
  id: uuid("id").primaryKey(),
  name: text("name").notNull(),
  type: organizationTypeEnum("type").notNull(),
  plan: organizationPlanEnum("plan").notNull().default("enterprise"),
  status: organizationStatusEnum("status").notNull().default("pending"),
  adminUserId: uuid("admin_user_id").notNull().references(() => users.id),
  createdBy: uuid("created_by").notNull().references(() => users.id),
  activatedBy: uuid("activated_by").references(() => users.id),
  activatedAt: timestamp("activated_at", { withTimezone: true }),
  contactEmail: text("contact_email"),
  contactPhone: text("contact_phone"),
  settings: jsonb("settings").notNull().default(sql`'{}'::jsonb`),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  activeAdminUnique: uniqueIndex("organizations_admin_active_unique")
    .on(table.adminUserId)
    .where(sql`${table.status} <> 'archived'`),
  statusIndex: index("organizations_status_idx").on(table.status),
}));

export const organizationMembers = pgTable("organization_members", {
  id: uuid("id").primaryKey(),
  orgId: uuid("org_id").notNull().references(() => organizations.id, { onDelete: "cascade" }),
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  role: organizationRoleEnum("role").notNull(),
  joinedAt: timestamp("joined_at", { withTimezone: true }).notNull().defaultNow(),
  invitedBy: uuid("invited_by").references(() => users.id),
}, (table) => ({
  oneOrganizationPerUser: unique().on(table.userId),
  organizationMemberUnique: unique().on(table.orgId, table.userId),
  orgIndex: index("organization_members_org_idx").on(table.orgId),
}));

export const organizationVehicles = pgTable("organization_vehicles", {
  id: uuid("id").primaryKey(),
  orgId: uuid("org_id").notNull().references(() => organizations.id, { onDelete: "cascade" }),
  vehicleId: uuid("vehicle_id").notNull().references(() => vehicles.id),
  lifecycleTemplate: lifecycleTemplateEnum("lifecycle_template").notNull(),
  status: text("status").notNull(),
  revenueLabel: text("revenue_label"),
  addedBy: uuid("added_by").notNull().references(() => users.id),
  addedAt: timestamp("added_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  vehicleUnique: unique().on(table.vehicleId),
  organizationIndex: index("organization_vehicles_org_idx").on(table.orgId),
}));

export const driverAssignments = pgTable("driver_assignments", {
  id: uuid("id").primaryKey(),
  orgId: uuid("org_id").notNull().references(() => organizations.id, { onDelete: "cascade" }),
  vehicleId: uuid("vehicle_id").notNull().references(() => vehicles.id),
  driverId: uuid("driver_id").notNull().references(() => users.id),
  assignedBy: uuid("assigned_by").notNull().references(() => users.id),
  assignedAt: timestamp("assigned_at", { withTimezone: true }).notNull().defaultNow(),
  unassignedAt: timestamp("unassigned_at", { withTimezone: true }),
  status: assignmentStatusEnum("status").notNull().default("active"),
}, (table) => ({
  orgIndex: index("driver_assignments_org_idx").on(table.orgId),
  activeDriverUnique: uniqueIndex("driver_assignments_active_driver_unique")
    .on(table.driverId)
    .where(sql`${table.status} = 'active'`),
  activeVehicleUnique: uniqueIndex("driver_assignments_active_vehicle_unique")
    .on(table.vehicleId)
    .where(sql`${table.status} = 'active'`),
}));

export const workOrders = pgTable("work_orders", {
  id: uuid("id").primaryKey(),
  orgId: uuid("org_id").notNull().references(() => organizations.id, { onDelete: "cascade" }),
  vehicleId: uuid("vehicle_id").notNull().references(() => vehicles.id),
  reportedBy: uuid("reported_by").notNull().references(() => users.id),
  reportedAt: timestamp("reported_at", { withTimezone: true }).notNull().defaultNow(),
  odometerKm: integer("odometer_km").notNull(),
  issueType: workOrderIssueTypeEnum("issue_type").notNull(),
  description: text("description").notNull(),
  urgency: workOrderUrgencyEnum("urgency").notNull(),
  photos: jsonb("photos").notNull().default(sql`'[]'::jsonb`),
  status: workOrderStatusEnum("status").notNull().default("reported"),
  assignedTo: uuid("assigned_to").references(() => users.id),
  resolvedBy: uuid("resolved_by").references(() => users.id),
  resolvedAt: timestamp("resolved_at", { withTimezone: true }),
  resolutionNotes: text("resolution_notes"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  orgIndex: index("work_orders_org_idx").on(table.orgId),
  vehicleIndex: index("work_orders_vehicle_idx").on(table.vehicleId),
}));

export const maintenanceCatalog = pgTable("maintenance_catalog", {
  id: uuid("id").primaryKey(),
  catalogKey: text("catalog_key").notNull().unique(),
  name: text("name").notNull(),
  intervalDays: integer("interval_days"),
  intervalDistance: numeric("interval_distance", { precision: 12, scale: 1 }),
  fuelTypes: text("fuel_types").array().notNull(),
  sortOrder: integer("sort_order").notNull().default(0),
  enabled: boolean("enabled").notNull().default(true),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const warrantyTemplates = pgTable("warranty_templates", {
  id: uuid("id").primaryKey(),
  orgId: uuid("org_id").notNull().references(() => organizations.id, { onDelete: "cascade" }),
  name: text("name").notNull(),
  durationYears: integer("duration_years").notNull(),
  mileageLimitKm: integer("mileage_limit_km").notNull(),
  coverageCategories: jsonb("coverage_categories").notNull().default(sql`'[]'::jsonb`),
  exclusions: text("exclusions"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const warrantyTemplateWorkshops = pgTable("warranty_template_workshops", {
  id: uuid("id").primaryKey(),
  templateId: uuid("template_id").notNull().references(() => warrantyTemplates.id, { onDelete: "cascade" }),
  partnerId: uuid("partner_id").notNull().references(() => partners.id),
}, (table) => ({
  uniqueTemplatePartner: unique().on(table.templateId, table.partnerId),
}));

export const vehicleWarranties = pgTable("vehicle_warranties", {
  id: uuid("id").primaryKey(),
  vehicleId: uuid("vehicle_id").notNull().unique().references(() => vehicles.id),
  templateId: uuid("template_id").notNull().references(() => warrantyTemplates.id),
  saleDate: date("sale_date").notNull(),
  saleMileageKm: integer("sale_mileage_km").notNull(),
  warrantyEndDate: date("warranty_end_date").notNull(),
  warrantyEndMileage: integer("warranty_end_mileage").notNull(),
  status: warrantyStatusEnum("status").notNull().default("active"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const transferredVehicles = pgTable("transferred_vehicles", {
  id: uuid("id").primaryKey(),
  vehicleId: uuid("vehicle_id").notNull().references(() => vehicles.id),
  orgId: uuid("org_id").notNull().references(() => organizations.id),
  buyerUserId: uuid("buyer_user_id").notNull().references(() => users.id),
  transferredBy: uuid("transferred_by").notNull().references(() => users.id),
  transferredAt: timestamp("transferred_at", { withTimezone: true }).notNull().defaultNow(),
  warrantyInstanceId: uuid("warranty_instance_id").references(() => vehicleWarranties.id),
}, (table) => ({
  orgIndex: index("transferred_vehicles_org_idx").on(table.orgId),
}));

export const inspectionTemplates = pgTable("inspection_templates", {
  id: uuid("id").primaryKey(),
  orgId: uuid("org_id").notNull().references(() => organizations.id, { onDelete: "cascade" }),
  name: text("name").notNull(),
  items: jsonb("items").notNull().default(sql`'[]'::jsonb`),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const inspections = pgTable("inspections", {
  id: uuid("id").primaryKey(),
  orgId: uuid("org_id").notNull().references(() => organizations.id, { onDelete: "cascade" }),
  vehicleId: uuid("vehicle_id").notNull().references(() => vehicles.id),
  driverId: uuid("driver_id").notNull().references(() => users.id),
  templateId: uuid("template_id").notNull().references(() => inspectionTemplates.id),
  inspectionType: inspectionTypeEnum("inspection_type").notNull(),
  startedAt: timestamp("started_at", { withTimezone: true }).notNull().defaultNow(),
  completedAt: timestamp("completed_at", { withTimezone: true }),
  status: inspectionStatusEnum("status").notNull().default("in_progress"),
  items: jsonb("items").notNull().default(sql`'[]'::jsonb`),
  notes: text("notes"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  orgIndex: index("inspections_org_idx").on(table.orgId),
  vehicleIndex: index("inspections_vehicle_idx").on(table.vehicleId),
}));

export const shiftMileage = pgTable("shift_mileage", {
  id: uuid("id").primaryKey(),
  orgId: uuid("org_id").notNull().references(() => organizations.id, { onDelete: "cascade" }),
  vehicleId: uuid("vehicle_id").notNull().references(() => vehicles.id),
  driverId: uuid("driver_id").notNull().references(() => users.id),
  startOdometerKm: integer("start_odometer_km").notNull(),
  endOdometerKm: integer("end_odometer_km"),
  startAt: timestamp("start_at", { withTimezone: true }).notNull().defaultNow(),
  endAt: timestamp("end_at", { withTimezone: true }),
  kmDriven: integer("km_driven"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  orgIndex: index("shift_mileage_org_idx").on(table.orgId),
  activeDriverUnique: uniqueIndex("shift_mileage_active_driver_unique")
    .on(table.driverId)
    .where(sql`${table.endAt} IS NULL`),
  activeVehicleUnique: uniqueIndex("shift_mileage_active_vehicle_unique")
    .on(table.vehicleId)
    .where(sql`${table.endAt} IS NULL`),
}));

export const vehicleImportJobs = pgTable("vehicle_import_jobs", {
  id: uuid("id").primaryKey(),
  orgId: uuid("org_id").notNull().references(() => organizations.id, { onDelete: "cascade" }),
  createdBy: uuid("created_by").notNull().references(() => users.id),
  fileName: text("file_name").notNull(),
  totalRows: integer("total_rows").notNull(),
  status: vehicleImportStatusEnum("status").notNull().default("processing"),
  results: jsonb("results").notNull().default(sql`'[]'::jsonb`),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  completedAt: timestamp("completed_at", { withTimezone: true }),
}, (table) => ({
  orgIndex: index("vehicle_import_jobs_org_idx").on(table.orgId),
}));

export const organizationWorkshops = pgTable("organization_workshops", {
  id: uuid("id").primaryKey(),
  orgId: uuid("org_id").notNull().references(() => organizations.id, { onDelete: "cascade" }),
  partnerId: uuid("partner_id").notNull().references(() => partners.id, { onDelete: "cascade" }),
  addedBy: uuid("added_by").notNull().references(() => users.id),
  addedAt: timestamp("added_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  uniqueOrganizationPartner: unique().on(table.orgId, table.partnerId),
  orgIndex: index("organization_workshops_org_idx").on(table.orgId),
}));

export const workshopMembers = pgTable("workshop_members", {
  id: uuid("id").primaryKey(),
  partnerId: uuid("partner_id").notNull().references(() => partners.id, { onDelete: "cascade" }),
  userId: uuid("user_id").notNull().unique().references(() => users.id, { onDelete: "cascade" }),
  invitedBy: uuid("invited_by").references(() => users.id),
  joinedAt: timestamp("joined_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  uniquePartnerMember: unique().on(table.partnerId, table.userId),
  partnerIndex: index("workshop_members_partner_idx").on(table.partnerId),
}));
