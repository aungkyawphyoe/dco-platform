ALTER TABLE plan_items ADD COLUMN IF NOT EXISTS time_count integer;
ALTER TABLE plan_items ADD COLUMN IF NOT EXISTS time_unit text;
ALTER TABLE plan_items ADD COLUMN IF NOT EXISTS warning_days integer;
ALTER TABLE plan_items ADD COLUMN IF NOT EXISTS warning_distance numeric(12,1);
ALTER TABLE plan_items ADD COLUMN IF NOT EXISTS baseline_due_on date;
ALTER TABLE plan_items ADD COLUMN IF NOT EXISTS baseline_due_mileage numeric(12,1);
ALTER TABLE plan_items ADD COLUMN IF NOT EXISTS baseline_enabled boolean NOT NULL DEFAULT true;
ALTER TABLE plan_items ADD COLUMN IF NOT EXISTS manual_on date;
ALTER TABLE plan_items ADD COLUMN IF NOT EXISTS manual_service_id uuid;
UPDATE plan_items p SET baseline_due_on=b.next_due_on, baseline_due_mileage=b.next_due_mileage
FROM plan_schedule_baselines b WHERE b.plan_item_id=p.id AND p.baseline_due_on IS NULL AND p.baseline_due_mileage IS NULL;
ALTER TABLE service_records ALTER COLUMN odometer DROP NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS plan_items_active_catalog_unique
ON plan_items(vehicle_id,catalog_key) WHERE enabled AND catalog_key IS NOT NULL;
