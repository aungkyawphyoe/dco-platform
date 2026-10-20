ALTER TABLE users ADD COLUMN IF NOT EXISTS email_reminders_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_reminder_lead_days integer NOT NULL DEFAULT 30;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_email_reminder_lead_days_check'
  ) THEN
    ALTER TABLE users ADD CONSTRAINT users_email_reminder_lead_days_check
      CHECK (email_reminder_lead_days BETWEEN 7 AND 60);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS reminder_email_deliveries (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  plan_item_id uuid NOT NULL REFERENCES plan_items(id) ON DELETE CASCADE,
  cycle_key text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('upcoming', 'due')),
  recipient text NOT NULL,
  attempts integer NOT NULL DEFAULT 0,
  last_attempt_at timestamptz,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS reminder_email_deliveries_cycle_unique
  ON reminder_email_deliveries(plan_item_id, cycle_key, kind);
CREATE INDEX IF NOT EXISTS reminder_email_deliveries_user_idx
  ON reminder_email_deliveries(user_id);
