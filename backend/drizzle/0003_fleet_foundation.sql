DO $$ BEGIN
  CREATE TYPE organization_type AS ENUM ('showroom', 'dealership', 'taxi_fleet', 'rental', 'commercial', 'logistics');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE organization_plan AS ENUM ('enterprise');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE organization_status AS ENUM ('pending', 'active', 'suspended', 'archived');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE organization_role AS ENUM ('org_admin', 'org_manager', 'org_mechanic', 'org_driver');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE lifecycle_template AS ENUM ('showroom', 'taxi_fleet', 'rental', 'commercial');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE assignment_status AS ENUM ('active', 'completed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE work_order_issue_type AS ENUM ('breakdown', 'accident', 'wear_tear', 'scheduled_service', 'other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE work_order_urgency AS ENUM ('low', 'medium', 'high', 'critical');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE work_order_status AS ENUM ('reported', 'in_progress', 'completed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE warranty_status AS ENUM ('active', 'expired', 'voided');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE inspection_type AS ENUM ('pre_trip', 'post_trip', 'random');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE inspection_status AS ENUM ('in_progress', 'completed', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE vehicle_import_status AS ENUM ('processing', 'completed', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE refresh_tokens
  ADD COLUMN IF NOT EXISTS audience text NOT NULL DEFAULT 'dco-owner';
UPDATE refresh_tokens rt
SET audience = CASE WHEN u.role = 'admin' THEN 'dco-admin' ELSE 'dco-owner' END
FROM users u
WHERE rt.user_id = u.id AND rt.audience = 'dco-owner' AND u.role = 'admin';

CREATE TABLE IF NOT EXISTS organizations (
  id uuid PRIMARY KEY,
  name text NOT NULL CHECK (length(name) BETWEEN 1 AND 200),
  type organization_type NOT NULL,
  plan organization_plan NOT NULL DEFAULT 'enterprise',
  status organization_status NOT NULL DEFAULT 'pending',
  admin_user_id uuid NOT NULL REFERENCES users(id),
  created_by uuid NOT NULL REFERENCES users(id),
  activated_by uuid REFERENCES users(id),
  activated_at timestamptz,
  contact_email text,
  contact_phone text,
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS organizations_admin_active_unique
  ON organizations (admin_user_id) WHERE status <> 'archived';
CREATE INDEX IF NOT EXISTS organizations_status_idx ON organizations(status);

CREATE TABLE IF NOT EXISTS organization_members (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  role organization_role NOT NULL,
  joined_at timestamptz NOT NULL DEFAULT now(),
  invited_by uuid REFERENCES users(id),
  UNIQUE (org_id, user_id)
);
CREATE INDEX IF NOT EXISTS organization_members_org_idx ON organization_members(org_id);
CREATE UNIQUE INDEX IF NOT EXISTS organization_one_admin_idx
  ON organization_members(org_id) WHERE role = 'org_admin';

CREATE TABLE IF NOT EXISTS organization_vehicles (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  vehicle_id uuid NOT NULL UNIQUE REFERENCES vehicles(id),
  lifecycle_template lifecycle_template NOT NULL,
  status text NOT NULL,
  revenue_label text,
  added_by uuid NOT NULL REFERENCES users(id),
  added_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS organization_vehicles_org_idx ON organization_vehicles(org_id);

CREATE TABLE IF NOT EXISTS driver_assignments (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  driver_id uuid NOT NULL REFERENCES users(id),
  assigned_by uuid NOT NULL REFERENCES users(id),
  assigned_at timestamptz NOT NULL DEFAULT now(),
  unassigned_at timestamptz,
  status assignment_status NOT NULL DEFAULT 'active'
);
CREATE INDEX IF NOT EXISTS driver_assignments_org_idx ON driver_assignments(org_id);
CREATE UNIQUE INDEX IF NOT EXISTS driver_assignments_active_driver_unique
  ON driver_assignments(driver_id) WHERE status = 'active';
CREATE UNIQUE INDEX IF NOT EXISTS driver_assignments_active_vehicle_unique
  ON driver_assignments(vehicle_id) WHERE status = 'active';

CREATE TABLE IF NOT EXISTS work_orders (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  reported_by uuid NOT NULL REFERENCES users(id),
  reported_at timestamptz NOT NULL DEFAULT now(),
  odometer_km integer NOT NULL CHECK (odometer_km >= 0),
  issue_type work_order_issue_type NOT NULL,
  description text NOT NULL CHECK (length(description) BETWEEN 10 AND 2000),
  urgency work_order_urgency NOT NULL,
  photos jsonb NOT NULL DEFAULT '[]'::jsonb,
  status work_order_status NOT NULL DEFAULT 'reported',
  assigned_to uuid REFERENCES users(id),
  resolved_by uuid REFERENCES users(id),
  resolved_at timestamptz,
  resolution_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS work_orders_org_idx ON work_orders(org_id);
CREATE INDEX IF NOT EXISTS work_orders_vehicle_idx ON work_orders(vehicle_id);

CREATE TABLE IF NOT EXISTS warranty_templates (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name text NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
  duration_years integer NOT NULL CHECK (duration_years BETWEEN 1 AND 10),
  mileage_limit_km integer NOT NULL CHECK (mileage_limit_km BETWEEN 1000 AND 500000),
  coverage_categories jsonb NOT NULL DEFAULT '[]'::jsonb,
  exclusions text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS warranty_template_workshops (
  id uuid PRIMARY KEY,
  template_id uuid NOT NULL REFERENCES warranty_templates(id) ON DELETE CASCADE,
  partner_id uuid NOT NULL REFERENCES partners(id),
  UNIQUE(template_id, partner_id)
);

CREATE TABLE IF NOT EXISTS vehicle_warranties (
  id uuid PRIMARY KEY,
  vehicle_id uuid NOT NULL UNIQUE REFERENCES vehicles(id),
  template_id uuid NOT NULL REFERENCES warranty_templates(id),
  sale_date date NOT NULL,
  sale_mileage_km integer NOT NULL CHECK (sale_mileage_km >= 0),
  warranty_end_date date NOT NULL,
  warranty_end_mileage integer NOT NULL,
  status warranty_status NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS transferred_vehicles (
  id uuid PRIMARY KEY,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  org_id uuid NOT NULL REFERENCES organizations(id),
  buyer_user_id uuid NOT NULL REFERENCES users(id),
  transferred_by uuid NOT NULL REFERENCES users(id),
  transferred_at timestamptz NOT NULL DEFAULT now(),
  warranty_instance_id uuid REFERENCES vehicle_warranties(id)
);
CREATE INDEX IF NOT EXISTS transferred_vehicles_org_idx ON transferred_vehicles(org_id);

CREATE TABLE IF NOT EXISTS inspection_templates (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name text NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS inspections (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  driver_id uuid NOT NULL REFERENCES users(id),
  template_id uuid NOT NULL REFERENCES inspection_templates(id),
  inspection_type inspection_type NOT NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  status inspection_status NOT NULL DEFAULT 'in_progress',
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS inspections_org_idx ON inspections(org_id);
CREATE INDEX IF NOT EXISTS inspections_vehicle_idx ON inspections(vehicle_id);

CREATE TABLE IF NOT EXISTS shift_mileage (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  driver_id uuid NOT NULL REFERENCES users(id),
  start_odometer_km integer NOT NULL CHECK (start_odometer_km >= 0),
  end_odometer_km integer CHECK (end_odometer_km >= start_odometer_km),
  start_at timestamptz NOT NULL DEFAULT now(),
  end_at timestamptz,
  km_driven integer,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS shift_mileage_org_idx ON shift_mileage(org_id);
CREATE UNIQUE INDEX IF NOT EXISTS shift_mileage_active_driver_unique ON shift_mileage(driver_id) WHERE end_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS shift_mileage_active_vehicle_unique ON shift_mileage(vehicle_id) WHERE end_at IS NULL;

CREATE TABLE IF NOT EXISTS vehicle_import_jobs (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES users(id),
  file_name text NOT NULL,
  total_rows integer NOT NULL CHECK (total_rows BETWEEN 1 AND 100),
  status vehicle_import_status NOT NULL DEFAULT 'processing',
  results jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);
CREATE INDEX IF NOT EXISTS vehicle_import_jobs_org_idx ON vehicle_import_jobs(org_id);

CREATE TABLE IF NOT EXISTS organization_workshops (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  partner_id uuid NOT NULL REFERENCES partners(id) ON DELETE CASCADE,
  added_by uuid NOT NULL REFERENCES users(id),
  added_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, partner_id)
);
CREATE INDEX IF NOT EXISTS organization_workshops_org_idx ON organization_workshops(org_id);

CREATE TABLE IF NOT EXISTS workshop_members (
  id uuid PRIMARY KEY,
  partner_id uuid NOT NULL REFERENCES partners(id) ON DELETE CASCADE,
  user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  invited_by uuid REFERENCES users(id),
  joined_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (partner_id, user_id)
);
CREATE INDEX IF NOT EXISTS workshop_members_partner_idx ON workshop_members(partner_id);
