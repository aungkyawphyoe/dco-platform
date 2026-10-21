ALTER TABLE media_objects ADD COLUMN IF NOT EXISTS owner_org_id uuid REFERENCES organizations(id);
ALTER TABLE media_objects ADD COLUMN IF NOT EXISTS vehicle_id uuid REFERENCES vehicles(id);
CREATE INDEX IF NOT EXISTS media_objects_owner_org_idx ON media_objects(owner_org_id);
CREATE INDEX IF NOT EXISTS media_objects_user_idx ON media_objects(user_id);
-- Reconcile existing references without copying any file bytes.
UPDATE media_objects m SET vehicle_id = d.vehicle_id
FROM documents d WHERE d.media_id = m.id AND m.vehicle_id IS NULL;
UPDATE media_objects m SET vehicle_id = s.vehicle_id
FROM service_records s WHERE s.receipt_media_id = m.id AND m.vehicle_id IS NULL;
UPDATE media_objects m SET vehicle_id = e.vehicle_id
FROM expenses e WHERE e.receipt_media_id = m.id AND m.vehicle_id IS NULL;
UPDATE media_objects m SET owner_org_id = ov.org_id
FROM organization_vehicles ov WHERE ov.vehicle_id = m.vehicle_id AND m.owner_org_id IS NULL;
UPDATE media_objects m SET user_id = v.user_id
FROM vehicles v WHERE v.id = m.vehicle_id AND m.owner_org_id IS NULL AND m.user_id <> v.user_id;

CREATE TABLE IF NOT EXISTS media_cleanup (
  media_id uuid PRIMARY KEY REFERENCES media_objects(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
