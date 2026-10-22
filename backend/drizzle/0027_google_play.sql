CREATE TABLE IF NOT EXISTS play_subscriptions (
  purchase_token text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  product_id text NOT NULL,
  base_plan_id text NOT NULL,
  plan user_plan NOT NULL,
  state text NOT NULL,
  expires_at timestamptz NOT NULL,
  auto_renewing boolean NOT NULL DEFAULT false,
  acknowledged boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS play_subscriptions_user_idx ON play_subscriptions(user_id);
