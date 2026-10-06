-- Migration 0009: Add created_by audit trail columns
-- Idempotent: uses IF NOT EXISTS and guards for re-runs

-- 1. Add created_by to service_records
ALTER TABLE service_records
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES users(id);

-- 2. Add created_by to expenses
ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES users(id);

-- 3. Add created_by to plan_items
ALTER TABLE plan_items
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES users(id);

-- 4. Add created_by to parts
ALTER TABLE parts
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES users(id);

-- 5. Backfill existing rows with vehicle owner (best effort)
--    Only fills rows where created_by IS NULL
UPDATE service_records sr
SET created_by = v.user_id
FROM vehicles v
WHERE sr.vehicle_id = v.id
  AND sr.created_by IS NULL;

UPDATE expenses e
SET created_by = v.user_id
FROM vehicles v
WHERE e.vehicle_id = v.id
  AND e.created_by IS NULL;

UPDATE plan_items pi
SET created_by = v.user_id
FROM vehicles v
WHERE pi.vehicle_id = v.id
  AND pi.created_by IS NULL;

UPDATE parts p
SET created_by = v.user_id
FROM vehicles v
WHERE p.vehicle_id = v.id
  AND p.created_by IS NULL;

-- 6. Indexes for query performance
CREATE INDEX IF NOT EXISTS idx_service_records_created_by ON service_records(created_by);
CREATE INDEX IF NOT EXISTS idx_expenses_created_by ON expenses(created_by);
CREATE INDEX IF NOT EXISTS idx_plan_items_created_by ON plan_items(created_by);
CREATE INDEX IF NOT EXISTS idx_parts_created_by ON parts(created_by);