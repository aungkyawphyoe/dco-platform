-- Preserve assignment history while allowing shared and pooled vehicles.
DROP INDEX IF EXISTS driver_assignments_active_driver_unique;
DROP INDEX IF EXISTS driver_assignments_active_vehicle_unique;
CREATE UNIQUE INDEX IF NOT EXISTS driver_assignments_active_pair_unique
  ON driver_assignments (org_id, driver_id, vehicle_id) WHERE status = 'active';
