DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('owner', 'admin');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE user_plan AS ENUM ('free', 'premium');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE account_status AS ENUM ('active', 'deactivated');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE vehicle_fuel_type AS ENUM ('petrol', 'electric', 'hybrid_plugin');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE mileage_unit AS ENUM ('mi', 'km');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE document_category AS ENUM ('insurance', 'registration', 'invoice', 'warranty', 'receipt', 'other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE expense_category AS ENUM ('fuel', 'maintenance', 'insurance', 'parking', 'tolls', 'parts', 'other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE partner_type AS ENUM ('workshop', 'insurer');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE partner_status AS ENUM ('draft', 'pending_verification', 'verified', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE fuel_kind AS ENUM ('liquid', 'electric');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE fuel_log_kind AS ENUM ('refuel', 'charge');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE change_op AS ENUM ('upsert', 'archive', 'delete');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE notification_status AS ENUM ('unread', 'read', 'done', 'dismissed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE due_reason AS ENUM ('date', 'mileage', 'both');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY,
  email text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  display_name text,
  role user_role NOT NULL DEFAULT 'owner',
  plan user_plan NOT NULL DEFAULT 'free',
  status account_status NOT NULL DEFAULT 'active',
  email_verified boolean NOT NULL DEFAULT false,
  active_vehicle_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vehicles (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  name text NOT NULL,
  nickname text,
  make text NOT NULL,
  model text NOT NULL,
  year integer NOT NULL,
  license_plate text NOT NULL,
  vin text,
  color text,
  fuel_type vehicle_fuel_type NOT NULL,
  mileage numeric(12,1) NOT NULL,
  mileage_unit mileage_unit NOT NULL DEFAULT 'mi',
  purchase_date date,
  purchase_price numeric(12,2),
  photo_media_id uuid,
  archived boolean NOT NULL DEFAULT false,
  archived_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS vehicles_user_plate_active
  ON vehicles (user_id, lower(license_plate)) WHERE archived = false;
CREATE UNIQUE INDEX IF NOT EXISTS vehicles_vin_active
  ON vehicles (vin) WHERE archived = false AND vin IS NOT NULL;

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  family_id uuid NOT NULL,
  token_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS email_tokens (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  purpose text NOT NULL,
  token_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  used_at timestamptz
);

CREATE TABLE IF NOT EXISTS device_tokens (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  token text NOT NULL,
  platform text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);

CREATE TABLE IF NOT EXISTS media_objects (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  blob_key text NOT NULL,
  content_type text NOT NULL,
  byte_size integer NOT NULL,
  sha256 text,
  purpose text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS plan_items (
  id uuid PRIMARY KEY,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  name text NOT NULL,
  interval_days integer,
  interval_distance numeric(12,1),
  next_due_mileage numeric(12,1),
  next_due_on date,
  enabled boolean NOT NULL DEFAULT true,
  notes text,
  catalog_key text
);

CREATE TABLE IF NOT EXISTS service_records (
  id uuid PRIMARY KEY,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  serviced_on date NOT NULL,
  odometer numeric(12,1) NOT NULL,
  total_cost numeric(12,2) NOT NULL,
  workshop_name text,
  notes text,
  receipt_media_id uuid
);

CREATE TABLE IF NOT EXISTS service_record_items (
  id uuid PRIMARY KEY,
  service_record_id uuid NOT NULL REFERENCES service_records(id) ON DELETE CASCADE,
  plan_item_id uuid,
  name text NOT NULL,
  line_cost numeric(12,2)
);

CREATE TABLE IF NOT EXISTS parts (
  id uuid PRIMARY KEY,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  name text NOT NULL,
  brand text,
  part_number text,
  notes text
);

CREATE TABLE IF NOT EXISTS service_record_parts (
  id uuid PRIMARY KEY,
  service_record_id uuid NOT NULL REFERENCES service_records(id) ON DELETE CASCADE,
  part_id uuid NOT NULL REFERENCES parts(id),
  name text NOT NULL
);

CREATE TABLE IF NOT EXISTS fuel_types (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  name text NOT NULL,
  kind fuel_kind NOT NULL,
  unit text NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS fuel_types_user_name ON fuel_types (user_id, lower(name));

CREATE TABLE IF NOT EXISTS fuel_logs (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  kind fuel_log_kind NOT NULL,
  fuel_type_id uuid,
  fuel_type_name text NOT NULL,
  unit text NOT NULL,
  logged_on date NOT NULL,
  amount numeric(12,3) NOT NULL,
  cost numeric(12,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS documents (
  id uuid PRIMARY KEY,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  name text NOT NULL,
  category document_category NOT NULL,
  notes text,
  media_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS expenses (
  id uuid PRIMARY KEY,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  category expense_category NOT NULL,
  amount numeric(12,2) NOT NULL,
  incurred_on date NOT NULL,
  notes text,
  receipt_media_id uuid
);

CREATE TABLE IF NOT EXISTS expense_parts (
  id uuid PRIMARY KEY,
  expense_id uuid NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  part_id uuid NOT NULL REFERENCES parts(id),
  name text NOT NULL
);

CREATE TABLE IF NOT EXISTS notification_feed (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  vehicle_id uuid REFERENCES vehicles(id),
  plan_item_id uuid,
  title text NOT NULL,
  body text NOT NULL,
  status notification_status NOT NULL DEFAULT 'unread',
  due_reason due_reason,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS change_log (
  seq bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  op change_op NOT NULL,
  payload jsonb NOT NULL,
  server_ts timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partners (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  type partner_type NOT NULL,
  status partner_status NOT NULL DEFAULT 'draft',
  contact_email text,
  contact_phone text,
  notes text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  admin_user_id uuid NOT NULL REFERENCES users(id),
  action text NOT NULL,
  detail jsonb NOT NULL,
  at timestamptz NOT NULL DEFAULT now()
);
