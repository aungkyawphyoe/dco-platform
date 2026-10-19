-- Migration 0021: class-based maintenance template assignment
-- Replaces the anchor-row FK (organization_vehicles.maintenance_template_id)
-- with a class-level assignment (maintenance_template_class). The template set
-- is derived live from the assigned class + the vehicle's lifecycle and fuel,
-- so individual template rows are no longer point-referenced. Existing
-- assignments are backfilled from the referenced catalog row's vehicle_class,
-- then the old FK is dropped.
-- Every statement is idempotent: this file runs on every boot via applyInitSql().

ALTER TABLE organization_vehicles ADD COLUMN IF NOT EXISTS maintenance_template_class text;

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'organization_vehicles' AND column_name = 'maintenance_template_id'
  ) THEN
    UPDATE organization_vehicles ov
      SET maintenance_template_class = mc.vehicle_class
      FROM maintenance_catalog mc
      WHERE ov.maintenance_template_id = mc.id
        AND ov.maintenance_template_class IS NULL;
    ALTER TABLE organization_vehicles DROP COLUMN maintenance_template_id;
  END IF;
END $$;
