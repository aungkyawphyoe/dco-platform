-- Existing organizations are reviewed individually; new organizations are enforced.
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS billing_migrated boolean;
UPDATE organizations SET billing_migrated = false WHERE billing_migrated IS NULL;
ALTER TABLE organizations ALTER COLUMN billing_migrated SET DEFAULT true;
ALTER TABLE organizations ALTER COLUMN billing_migrated SET NOT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS billing_managed boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS free_vehicle_id uuid;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS price_monthly_usd numeric(12,2);
ALTER TABLE plans ADD COLUMN IF NOT EXISTS price_annual_usd numeric(12,2);
ALTER TABLE plans ADD COLUMN IF NOT EXISTS price_version integer NOT NULL DEFAULT 1;
UPDATE plans SET price_monthly_usd = CASE id WHEN 'lite' THEN 1 WHEN 'standard' THEN 2.99 WHEN 'fleet' THEN 14.99 ELSE 0 END,
 price_annual_usd = CASE id WHEN 'lite' THEN 10 WHEN 'standard' THEN 29.99 WHEN 'fleet' THEN 149.99 ELSE 0 END WHERE price_monthly_usd IS NULL;
CREATE TABLE IF NOT EXISTS subscription_terms (
 id uuid PRIMARY KEY, user_id uuid REFERENCES users(id), organization_id uuid REFERENCES organizations(id),
 plan user_plan NOT NULL, source text NOT NULL CHECK (source IN ('direct','complimentary')),
 starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL, revoked_at timestamptz,
 payment jsonb, reason text, created_by uuid NOT NULL REFERENCES users(id),
 request_fingerprint text, request_id uuid NOT NULL UNIQUE, version integer NOT NULL DEFAULT 1,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK ((user_id IS NULL) <> (organization_id IS NULL)), CHECK (ends_at > starts_at),
 CHECK ((organization_id IS NOT NULL AND plan = 'fleet') OR (user_id IS NOT NULL AND plan IN ('lite','standard'))),
 CHECK ((source = 'direct' AND payment IS NOT NULL) OR (source = 'complimentary' AND reason IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS subscription_terms_user ON subscription_terms(user_id);
CREATE INDEX IF NOT EXISTS subscription_terms_org ON subscription_terms(organization_id);
CREATE TABLE IF NOT EXISTS subscription_notices (
 id text PRIMARY KEY, term_id uuid NOT NULL REFERENCES subscription_terms(id), milestone text NOT NULL,
 sent_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
