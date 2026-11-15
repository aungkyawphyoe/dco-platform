ALTER TABLE fuel_logs ADD COLUMN IF NOT EXISTS battery_level_before integer
  CHECK (battery_level_before BETWEEN 0 AND 100);
