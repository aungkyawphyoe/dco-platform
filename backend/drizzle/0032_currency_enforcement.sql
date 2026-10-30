-- Keep activation server-side and explicit until all clients understand currency.
CREATE TABLE IF NOT EXISTS operational_currency_control (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  enabled boolean NOT NULL DEFAULT false
);
INSERT INTO operational_currency_control(singleton) VALUES(true) ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS currency_migration_reviews (
  scope_type text NOT NULL CHECK(scope_type IN ('personal','organization')),
  scope_id uuid NOT NULL, reason text NOT NULL, resolved_at timestamptz,
  PRIMARY KEY(scope_type,scope_id)
);

-- Attribute only unambiguous legacy histories. A transfer's purchase/fuel/expense
-- history lacks complete creation provenance, so do not guess the buyer's lock.
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM currency_migrations WHERE name='lock_baseline') THEN
    INSERT INTO currency_migration_reviews(scope_type,scope_id,reason)
      SELECT DISTINCT 'personal', buyer_user_id, 'Transferred history requires creation-provenance reconciliation'
      FROM transferred_vehicles ON CONFLICT DO NOTHING;
    UPDATE users u SET currency_locked_at=now() WHERE currency_locked_at IS NULL AND EXISTS (
      SELECT 1 FROM vehicles v WHERE v.user_id=u.id
      AND NOT EXISTS(SELECT 1 FROM organization_vehicles o WHERE o.vehicle_id=v.id)
      AND NOT EXISTS(SELECT 1 FROM transferred_vehicles t WHERE t.vehicle_id=v.id)
      AND (v.purchase_price IS NOT NULL OR EXISTS(SELECT 1 FROM expenses e WHERE e.vehicle_id=v.id)
        OR EXISTS(SELECT 1 FROM service_records s WHERE s.vehicle_id=v.id)
        OR EXISTS(SELECT 1 FROM fuel_logs f WHERE f.vehicle_id=v.id))
    );
    UPDATE organizations o SET currency_locked_at=now() WHERE currency_locked_at IS NULL AND (
      EXISTS(SELECT 1 FROM analytics_records a WHERE a.org_id=o.id)
      OR EXISTS(SELECT 1 FROM organization_changes c WHERE c.org_id=o.id AND c.entity_type IN ('expense','service_record','fuel_log'))
      OR EXISTS(SELECT 1 FROM work_orders w WHERE w.org_id=o.id AND w.completion_cost IS NOT NULL)
      OR EXISTS(SELECT 1 FROM transferred_vehicles t WHERE t.org_id=o.id AND jsonb_array_length(t.service_snapshot)>0)
      OR EXISTS(SELECT 1 FROM organization_vehicles ov JOIN vehicles v ON v.id=ov.vehicle_id WHERE ov.org_id=o.id
        AND (v.purchase_price IS NOT NULL OR EXISTS(SELECT 1 FROM expenses e WHERE e.vehicle_id=v.id)
          OR EXISTS(SELECT 1 FROM service_records s WHERE s.vehicle_id=v.id)
          OR EXISTS(SELECT 1 FROM fuel_logs f WHERE f.vehicle_id=v.id)))
    );
    -- Personal change logs fan out to collaborators, so a deleted record alone
    -- is insufficient evidence to lock its recipient's personal garage.
    INSERT INTO currency_migration_reviews(scope_type,scope_id,reason)
      SELECT DISTINCT 'personal', c.user_id, 'Deleted monetary history requires owner attribution'
      FROM change_log c JOIN users u ON u.id=c.user_id
      WHERE c.op='delete' AND c.entity_type IN ('expense','service_record','fuel_log')
        AND u.currency_locked_at IS NULL
      ON CONFLICT DO NOTHING;
    INSERT INTO currency_migrations(name) VALUES('lock_baseline');
  END IF;
END $$;

CREATE OR REPLACE FUNCTION protect_currency_activation() RETURNS trigger AS $$
BEGIN
  IF NEW.enabled AND EXISTS(SELECT 1 FROM currency_migration_reviews WHERE resolved_at IS NULL) THEN
    RAISE EXCEPTION 'currency_migration_review_required: resolve legacy attribution before activation';
  END IF;
  IF OLD.enabled AND NOT NEW.enabled THEN
    RAISE EXCEPTION 'currency_activation_locked: disabling enforcement would permit unsafe legacy writes';
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS currency_activation ON operational_currency_control;
CREATE TRIGGER currency_activation BEFORE UPDATE ON operational_currency_control
  FOR EACH ROW EXECUTE FUNCTION protect_currency_activation();

CREATE OR REPLACE FUNCTION preserve_scope_currency_lock() RETURNS trigger AS $$
BEGIN
  IF OLD.currency_locked_at IS NOT NULL AND
    (NEW.currency IS DISTINCT FROM OLD.currency OR NEW.currency_locked_at IS DISTINCT FROM OLD.currency_locked_at) THEN
    RAISE EXCEPTION 'currency_locked: currency cannot change after the first monetary record';
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS currency_scope_lock ON users;
CREATE TRIGGER currency_scope_lock BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION preserve_scope_currency_lock();
DROP TRIGGER IF EXISTS currency_scope_lock ON organizations;
CREATE TRIGGER currency_scope_lock BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION preserve_scope_currency_lock();

CREATE OR REPLACE FUNCTION enforce_operational_currency() RETURNS trigger AS $$
DECLARE
  event jsonb := to_jsonb(NEW); previous jsonb;
  amount_key text; code text; old_amount numeric; amount numeric;
  vehicle uuid; owner_id uuid; organization_id uuid; expected text; active boolean;
BEGIN
  SELECT enabled INTO active FROM operational_currency_control WHERE singleton FOR SHARE;
  amount_key := CASE TG_TABLE_NAME WHEN 'vehicles' THEN 'purchase_price' WHEN 'service_records' THEN 'total_cost'
    WHEN 'fuel_logs' THEN 'cost' WHEN 'work_orders' THEN 'completion_cost' ELSE 'amount' END;
  amount := (event->>amount_key)::numeric;
  IF amount IS NULL THEN RETURN NEW; END IF;
  code := event->>CASE WHEN TG_TABLE_NAME='vehicles' THEN 'purchase_currency' ELSE 'currency' END;
  IF TG_OP='UPDATE' THEN previous := to_jsonb(OLD); old_amount := (previous->>amount_key)::numeric; END IF;
  -- Accounting mirrors an already validated event; it is not a new payment.
  IF TG_TABLE_NAME='expenses' AND event->>'source_id' IS NOT NULL THEN RETURN NEW; END IF;
  -- Unchanged legacy fractions remain valid, including metadata-only edits.
  IF active AND (TG_OP='INSERT' OR old_amount IS DISTINCT FROM amount) AND
    (amount < 0 OR (code='MMK' AND amount<>trunc(amount))) THEN
    RAISE EXCEPTION 'invalid_money_precision: use whole MMK amounts and nonnegative costs';
  END IF;
  -- Existing events never lock a recipient after transfer.
  IF TG_OP='UPDATE' AND old_amount IS NOT NULL THEN RETURN NEW; END IF;
  IF TG_TABLE_NAME='vehicles' THEN
    vehicle := NEW.id; owner_id := NEW.user_id;
  ELSE
    vehicle := (event->>'vehicle_id')::uuid;
    SELECT user_id INTO owner_id FROM vehicles WHERE id=vehicle FOR UPDATE;
  END IF;
  IF TG_TABLE_NAME='work_orders' THEN organization_id := (event->>'org_id')::uuid;
  ELSE SELECT org_id INTO organization_id FROM organization_vehicles WHERE vehicle_id=vehicle; END IF;
  IF organization_id IS NOT NULL THEN
    SELECT currency INTO expected FROM organizations WHERE id=organization_id FOR UPDATE;
    IF active AND expected IS NULL THEN RAISE EXCEPTION 'currency_required: Fleet Admin must confirm a currency first'; END IF;
    IF active AND code IS DISTINCT FROM expected THEN RAISE EXCEPTION 'currency_mismatch: review the amount in the current currency' USING DETAIL=json_build_object('current_currency',expected)::text; END IF;
    UPDATE organizations SET currency=COALESCE(currency,code), currency_locked_at=COALESCE(currency_locked_at,now()) WHERE id=organization_id;
  ELSE
    SELECT currency INTO expected FROM users WHERE id=owner_id FOR UPDATE;
    IF active AND code IS DISTINCT FROM expected THEN RAISE EXCEPTION 'currency_mismatch: review the amount in the current currency' USING DETAIL=json_build_object('current_currency',expected)::text; END IF;
    UPDATE users SET currency_locked_at=COALESCE(currency_locked_at,now()) WHERE id=owner_id;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
DO $$ DECLARE name text; BEGIN
  FOREACH name IN ARRAY ARRAY['vehicles','work_orders','expenses','fuel_logs','service_records'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS zz_currency_write ON %I', name);
    EXECUTE format('CREATE TRIGGER zz_currency_write BEFORE INSERT OR UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION enforce_operational_currency()',name);
  END LOOP;
END $$;
