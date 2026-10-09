-- Migration 0011: Four-tier plans (free / lite / standard / fleet)
-- Replaces the legacy free/premium user_plan enum, maps premium -> standard,
-- and creates the plans reference table seeded from docs/pricing.md.
-- Every statement is idempotent: this file runs on every boot via
-- applyInitSql(), so a second run must be a no-op.

-- 1. Rebuild user_plan enum when it still carries the legacy 'premium'
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE t.typname = 'user_plan' AND e.enumlabel = 'premium'
  ) THEN
    ALTER TYPE user_plan RENAME TO user_plan_legacy;
    CREATE TYPE user_plan AS ENUM ('free', 'lite', 'standard', 'fleet');
    ALTER TABLE users ALTER COLUMN plan DROP DEFAULT;
    ALTER TABLE users ALTER COLUMN plan TYPE user_plan
      USING (
        CASE WHEN plan = 'premium' THEN 'standard'::user_plan
             ELSE plan::text::user_plan
        END
      );
    ALTER TABLE users ALTER COLUMN plan SET DEFAULT 'free';
    DROP TYPE user_plan_legacy;
  END IF;
END $$;

-- 2. Plans reference table (mirrors src/lib/plans.ts; limit NULLs = unlimited)
CREATE TABLE IF NOT EXISTS plans (
  id text PRIMARY KEY,
  name text NOT NULL,
  vehicle_limit int,
  sharing_limit int,
  storage_bytes bigint,
  ai_tier text NOT NULL,
  price_monthly_mmk int NOT NULL DEFAULT 0,
  price_annual_mmk int NOT NULL DEFAULT 0,
  stripe_price_id text,
  local_gateway_plan_id text
);

-- 3. Seed tiers from docs/pricing.md (keep values in sync with src/lib/plans.ts)
INSERT INTO plans (id, name, vehicle_limit, sharing_limit, storage_bytes, ai_tier, price_monthly_mmk, price_annual_mmk) VALUES
  ('free',     'Free',      1,     1,    52428800,  'base',     0,     0),
  ('lite',     'Lite',      3,     3,    157286400, 'higher',   3000,  30000),
  ('standard', 'Standard',  10,    NULL, 524288000, 'highest',  9000,  90000),
  ('fleet',    'Fleet/Pro', NULL,  NULL, 5368709120, 'unlimited', 70000, 700000)
ON CONFLICT (id) DO NOTHING;
