ALTER TABLE organization_members ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'deactivated'));
-- Never reconstruct old transfers from live buyer data. Historical snapshots
-- remain empty unless an independently verified historical source is available.
ALTER TABLE transferred_vehicles ADD COLUMN IF NOT EXISTS service_snapshot jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE transferred_vehicles ADD COLUMN IF NOT EXISTS vehicle_snapshot jsonb;
