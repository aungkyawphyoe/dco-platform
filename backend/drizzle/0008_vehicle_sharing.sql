-- Vehicle Sharing Migration: Replace Family Sharing with Per-Vehicle Sharing
-- Creates new enums/tables, migrates existing grants and family rows, drops the
-- old family tables. Every statement is idempotent: this file runs on every
-- boot via applyInitSql(), so a second run must be a no-op.

-- 1. Create new enums
DO $$ BEGIN
  CREATE TYPE share_status AS ENUM ('pending', 'active', 'revoked');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE share_access AS ENUM ('view', 'add_edit_own');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. Create vehicle_shares table (replaces vehicle_grants)
CREATE TABLE IF NOT EXISTS vehicle_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  granted_by uuid NOT NULL REFERENCES users(id),
  access_level share_access NOT NULL,
  status share_status NOT NULL DEFAULT 'active',
  invited_email text,
  share_code text UNIQUE,
  qr_code_data jsonb,
  accepted_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT unique_vehicle_user UNIQUE (vehicle_id, user_id)
);

-- 3. Create vehicle_share_invitations table
CREATE TABLE IF NOT EXISTS vehicle_share_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  invited_email text,
  invited_by uuid NOT NULL REFERENCES users(id),
  access_level share_access NOT NULL DEFAULT 'view',
  token text NOT NULL UNIQUE,
  share_code text UNIQUE,
  expires_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  accepted_at timestamp with time zone,
  accepted_by uuid REFERENCES users(id)
);

-- 4. Migrate existing vehicle_grants to vehicle_shares
-- Map: 'full' -> 'add_edit_own', anything else -> 'view'
DO $$ BEGIN
  IF to_regclass('vehicle_grants') IS NOT NULL THEN
    INSERT INTO vehicle_shares (id, vehicle_id, user_id, granted_by, access_level, status, accepted_at, created_at)
    SELECT
      id,
      vehicle_id,
      user_id,
      granted_by,
      CASE permission WHEN 'full' THEN 'add_edit_own'::share_access ELSE 'view'::share_access END,
      'active'::share_status,
      created_at,
      created_at
    FROM vehicle_grants
    ON CONFLICT (vehicle_id, user_id) DO NOTHING;
  END IF;
END $$;

-- 5. Migrate family shares: for each family_vehicle, create shares for all
--    non-owner family members. Members get 'add_edit_own', drivers get 'view';
--    the vehicle owner keeps ownership and gets no share row.
--    accepted_at preserves the member's joined_at.
DO $$ BEGIN
  IF to_regclass('family_vehicles') IS NOT NULL
     AND to_regclass('family_memberships') IS NOT NULL THEN
    INSERT INTO vehicle_shares (vehicle_id, user_id, granted_by, access_level, status, accepted_at, created_at)
    SELECT
      fv.vehicle_id,
      fm.user_id,
      fv.added_by,
      CASE fm.role WHEN 'driver' THEN 'view'::share_access ELSE 'add_edit_own'::share_access END,
      'active'::share_status,
      fm.joined_at,
      fm.joined_at
    FROM family_vehicles fv
    JOIN family_memberships fm ON fm.family_id = fv.family_id
    JOIN vehicles v ON v.id = fv.vehicle_id
    WHERE fm.user_id <> v.user_id
    ON CONFLICT (vehicle_id, user_id) DO NOTHING;
  END IF;
END $$;

-- 6. Drop old family tables (after migration)
DROP TABLE IF EXISTS vehicle_grants;
DROP TABLE IF EXISTS family_vehicles;
DROP TABLE IF EXISTS family_memberships;
DROP TABLE IF EXISTS families;

-- 7. Remove family_id from users table
ALTER TABLE users DROP COLUMN IF EXISTS family_id;

-- 8. Make family_id nullable in refresh_tokens (existing sessions survive)
ALTER TABLE refresh_tokens ALTER COLUMN family_id DROP NOT NULL;

-- 9. Drop old enums (after tables using them are dropped)
DROP TYPE IF EXISTS family_role;
DROP TYPE IF EXISTS grant_permission;
DROP TYPE IF EXISTS family_status;
