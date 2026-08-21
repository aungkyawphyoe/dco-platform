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
} from "drizzle-orm/pg-core";

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

export const users = pgTable("users", {
  id: uuid("id").primaryKey(),
  email: text("email").notNull().unique(),
  passwordHash: text("password_hash").notNull(),
  displayName: text("display_name"),
  role: roleEnum("role").notNull().default("owner"),
  plan: planEnum("plan").notNull().default("free"),
  status: accountStatusEnum("status").notNull().default("active"),
  emailVerified: boolean("email_verified").notNull().default(false),
  activeVehicleId: uuid("active_vehicle_id"),
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
