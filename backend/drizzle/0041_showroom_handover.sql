-- Reviewed showroom-to-personal handover. Drafts are explicit, one pending per
-- vehicle, and completion is a single audited ownership change.

ALTER TABLE organization_members
  ADD COLUMN IF NOT EXISTS can_complete_handover boolean NOT NULL DEFAULT false;

ALTER TABLE plan_items
  ADD COLUMN IF NOT EXISTS initial_service_required boolean NOT NULL DEFAULT false;

ALTER TYPE work_order_status ADD VALUE IF NOT EXISTS 'cancelled';
ALTER TABLE work_orders ADD COLUMN IF NOT EXISTS cancellation_reason text;
ALTER TABLE work_orders ADD COLUMN IF NOT EXISTS cancelled_by uuid REFERENCES users(id);
ALTER TABLE work_orders ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;

-- Frozen warranty terms survive later template edits.
ALTER TABLE vehicle_warranties
  ADD COLUMN IF NOT EXISTS terms_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS vehicle_handovers (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  buyer_user_id uuid NOT NULL REFERENCES users(id),
  created_by uuid NOT NULL REFERENCES users(id),
  completed_by uuid REFERENCES users(id),
  cancelled_by uuid REFERENCES users(id),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','completed','cancelled')),
  revision integer NOT NULL DEFAULT 1 CHECK (revision > 0),
  reviewed_revision integer CHECK (reviewed_revision IS NULL OR reviewed_revision > 0),
  reviewed_by uuid REFERENCES users(id),
  reviewed_at timestamptz,
  sale_date date,
  current_mileage_km integer CHECK (current_mileage_km IS NULL OR current_mileage_km >= 0),
  plan_snapshot jsonb NOT NULL DEFAULT '[]'::jsonb,
  warranty_choice text NOT NULL DEFAULT 'undecided' CHECK (warranty_choice IN ('undecided','none','template')),
  warranty_template_id uuid REFERENCES warranty_templates(id),
  warranty_snapshot jsonb,
  vehicle_snapshot jsonb,
  prior_warranty_snapshot jsonb,
  result_snapshot jsonb,
  cancellation_reason text,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (warranty_choice <> 'template' OR warranty_template_id IS NOT NULL),
  CHECK (status <> 'completed' OR (reviewed_revision IS NOT NULL AND completed_at IS NOT NULL))
);

CREATE UNIQUE INDEX IF NOT EXISTS vehicle_handovers_pending_unique
  ON vehicle_handovers(vehicle_id) WHERE status = 'draft';
CREATE INDEX IF NOT EXISTS vehicle_handovers_org_idx
  ON vehicle_handovers(org_id, created_at DESC);

ALTER TABLE transferred_vehicles
  ADD COLUMN IF NOT EXISTS handover_id uuid REFERENCES vehicle_handovers(id);
CREATE UNIQUE INDEX IF NOT EXISTS transferred_vehicles_handover_unique
  ON transferred_vehicles(handover_id) WHERE handover_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS vehicle_handover_events (
  id uuid PRIMARY KEY,
  handover_id uuid NOT NULL REFERENCES vehicle_handovers(id) ON DELETE CASCADE,
  buyer_user_id uuid NOT NULL REFERENCES users(id),
  event_type text NOT NULL CHECK (event_type IN ('vehicle','plan','warranty','receipt')),
  entity_id uuid,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','delivered','failed')),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  delivered_at timestamptz
);
CREATE INDEX IF NOT EXISTS vehicle_handover_events_handover_idx
  ON vehicle_handover_events(handover_id, status);
