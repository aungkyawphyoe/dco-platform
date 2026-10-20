-- Preserve the admin-defined starting schedule when the last linked service is removed.
CREATE TABLE IF NOT EXISTS plan_schedule_baselines (
  plan_item_id uuid PRIMARY KEY REFERENCES plan_items(id) ON DELETE CASCADE,
  next_due_on date,
  next_due_mileage numeric
);
