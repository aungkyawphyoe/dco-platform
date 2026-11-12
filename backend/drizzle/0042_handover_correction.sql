-- Platform-admin handover correction support
ALTER TABLE transferred_vehicles
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS reverted_at timestamptz,
  ADD COLUMN IF NOT EXISTS reverted_by uuid REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS revert_reason text;

-- Status can be 'active', 'reverted', or 'reassigned'
CREATE INDEX IF NOT EXISTS transferred_vehicles_status_idx ON transferred_vehicles(status);
