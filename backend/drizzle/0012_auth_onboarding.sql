-- Older signup with EMAIL_VERIFICATION=off marked addresses verified without proof.
-- Run this backfill once, using the new column as the migration marker.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'auth_version') THEN
    UPDATE users SET email_verified = false
    WHERE role = 'owner' AND email IS NOT NULL AND email_verified = true
      AND NOT EXISTS (SELECT 1 FROM email_tokens WHERE email_tokens.user_id = users.id AND purpose = 'verify' AND used_at IS NOT NULL);
  END IF;
END $$;
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_version integer NOT NULL DEFAULT 0;
CREATE TABLE IF NOT EXISTS auth_challenges (
 id uuid PRIMARY KEY, user_id uuid REFERENCES users(id), email text NOT NULL,
 purpose text NOT NULL, digest text NOT NULL, attempts integer NOT NULL DEFAULT 0,
 expires_at timestamptz NOT NULL, consumed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS auth_challenges_account ON auth_challenges(user_id, purpose);
CREATE TABLE IF NOT EXISTS auth_limits (key text PRIMARY KEY, count integer NOT NULL DEFAULT 0, expires_at timestamptz NOT NULL);
CREATE TABLE IF NOT EXISTS auth_identities (
 id uuid PRIMARY KEY, user_id uuid NOT NULL REFERENCES users(id), provider text NOT NULL,
 subject text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(provider,subject)
);
CREATE TABLE IF NOT EXISTS auth_flows (
 id uuid PRIMARY KEY, provider text NOT NULL, secret_hash text NOT NULL, state text NOT NULL UNIQUE,
 nonce text NOT NULL, verifier text NOT NULL, claims jsonb, claimed_at timestamptz, consumed_at timestamptz,
 expires_at timestamptz NOT NULL
);
