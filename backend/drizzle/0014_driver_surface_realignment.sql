-- Migration 0014: Driver surface realignment (second grilling, Oct 2026)
-- Work-order plan linkage + completion cost, free-text service-record parts,
-- and the shift-mileage retirement. Mileage is log-driven only from here on
-- (service records + fuel logs bump vehicles.mileage), mirroring personal mode.
-- Every statement is idempotent: this file runs on every boot via
-- applyInitSql(), so a second run must be a no-op.

-- 1. Work orders: optional plan linkage + completion cost (required on the
--    completed transition, enforced in the service layer).
ALTER TABLE work_orders ADD COLUMN IF NOT EXISTS plan_item_id uuid REFERENCES plan_items(id) ON DELETE set null;
ALTER TABLE work_orders ADD COLUMN IF NOT EXISTS completion_cost numeric(12, 2);
CREATE INDEX IF NOT EXISTS work_orders_plan_item_idx ON work_orders(plan_item_id);

-- 2. Service-record parts: part_id becomes nullable so WO-completion parts can
--    be free-text names (a driver/manager may reference a part not yet in the
--    catalog). Existing rows keep their part_id FK.
ALTER TABLE service_record_parts ALTER COLUMN part_id DROP NOT NULL;

-- 3. Shift mileage retired: the table, its indexes, and any in-progress rows
--    are removed. vehicles.mileage remains the single source of truth and is
--    advanced by service records and fuel logs only.
DROP TABLE IF EXISTS shift_mileage;
