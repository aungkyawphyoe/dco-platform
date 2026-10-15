-- Convert maintenance_catalog interval_distance from miles to km (one-time).
-- Guarded by the absence of vehicle_class (added in 0013): the column marker
-- makes this conversion run exactly once and stops later boots from
-- overwriting admin edits to these intervals.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'maintenance_catalog' AND column_name = 'vehicle_class'
  ) THEN
    UPDATE maintenance_catalog SET interval_distance = 24140  WHERE catalog_key = 'oil_change';
    UPDATE maintenance_catalog SET interval_distance = 24140  WHERE catalog_key = 'air_filter_cabin';
    UPDATE maintenance_catalog SET interval_distance = 80467  WHERE catalog_key = 'new_tires';
    UPDATE maintenance_catalog SET interval_distance = 48280  WHERE catalog_key = 'brake_change';
    UPDATE maintenance_catalog SET interval_distance = 48280  WHERE catalog_key = 'brake_fluid';
    UPDATE maintenance_catalog SET interval_distance = 128747 WHERE catalog_key = 'belts';
    UPDATE maintenance_catalog SET interval_distance = 48280  WHERE catalog_key = 'fuel_filter';
    UPDATE maintenance_catalog SET interval_distance = 57936  WHERE catalog_key = 'battery';
    UPDATE maintenance_catalog SET interval_distance = 9656   WHERE catalog_key = 'rotate_tires';
  END IF;
END $$;
