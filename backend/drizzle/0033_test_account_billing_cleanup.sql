-- Pre-launch test-account cleanup. No synthetic payments or subscription terms:
-- existing terms, Play purchases and gifts continue to determine paid access.
-- This runner replays SQL on startup, so record completion atomically and once.
CREATE TABLE IF NOT EXISTS billing_migrations (name text PRIMARY KEY);
DO $$
BEGIN
  LOCK TABLE billing_migrations IN EXCLUSIVE MODE;
  IF NOT EXISTS (SELECT 1 FROM billing_migrations WHERE name = 'prelaunch_test_accounts') THEN
    UPDATE users SET billing_managed = true, plan = 'free'
      WHERE role = 'owner' AND billing_managed = false;
    UPDATE organizations SET billing_migrated = true WHERE billing_migrated = false;
    INSERT INTO billing_migrations (name) VALUES ('prelaunch_test_accounts');
  END IF;
END $$;
