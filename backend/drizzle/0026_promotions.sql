CREATE TABLE IF NOT EXISTS promotions (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('single_use', 'shared')),
  plan user_plan NOT NULL CHECK (plan IN ('lite', 'standard')),
  duration_days integer NOT NULL CHECK (duration_days BETWEEN 1 AND 3650),
  redeem_by timestamptz NOT NULL,
  capacity integer NOT NULL CHECK (capacity BETWEEN 1 AND 1000000),
  enabled boolean NOT NULL DEFAULT true,
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS promotion_codes (
  id uuid PRIMARY KEY,
  promotion_id uuid NOT NULL REFERENCES promotions(id),
  code_hash text NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS gift_grants (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  promotion_id uuid NOT NULL REFERENCES promotions(id),
  code_id uuid NOT NULL REFERENCES promotion_codes(id),
  request_id uuid NOT NULL,
  single_use_code_id uuid UNIQUE REFERENCES promotion_codes(id),
  plan user_plan NOT NULL CHECK (plan IN ('lite', 'standard')),
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL CHECK (ends_at > starts_at),
  UNIQUE (user_id, promotion_id),
  UNIQUE (user_id, request_id)
);
CREATE INDEX IF NOT EXISTS gift_grants_user_expiry_idx ON gift_grants(user_id, ends_at);
CREATE INDEX IF NOT EXISTS gift_grants_code_idx ON gift_grants(code_id);
