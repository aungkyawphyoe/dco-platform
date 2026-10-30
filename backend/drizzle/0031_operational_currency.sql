-- Additive currency foundation. Currency selection is not enabled by this
-- migration: clients and all writers must be upgraded before activation.
ALTER TABLE users ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'MMK'
  CHECK (currency IN ('MMK', 'USD', 'THB', 'CNY'));
ALTER TABLE users ADD COLUMN IF NOT EXISTS currency_locked_at timestamptz;
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS currency text
  CHECK (currency IN ('MMK', 'USD', 'THB', 'CNY'));
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS currency_locked_at timestamptz;
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS purchase_currency text NOT NULL DEFAULT 'MMK'
  CHECK (purchase_currency IN ('MMK', 'USD', 'THB', 'CNY'));
ALTER TABLE service_records ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'MMK'
  CHECK (currency IN ('MMK', 'USD', 'THB', 'CNY'));
ALTER TABLE fuel_logs ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'MMK'
  CHECK (currency IN ('MMK', 'USD', 'THB', 'CNY'));
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'MMK'
  CHECK (currency IN ('MMK', 'USD', 'THB', 'CNY'));
ALTER TABLE work_orders ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'MMK'
  CHECK (currency IN ('MMK', 'USD', 'THB', 'CNY'));

-- This runner replays migrations at every startup. A marker ensures that a
-- later boot never selects MMK for a newly provisioned, unselected fleet.
CREATE TABLE IF NOT EXISTS currency_migrations (name text PRIMARY KEY);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM currency_migrations WHERE name = 'mmk_baseline') THEN
    UPDATE organizations SET currency = 'MMK' WHERE currency IS NULL;
    UPDATE analytics_records SET payload = payload || jsonb_build_object('currency', 'MMK')
      WHERE NOT payload ? 'currency';
    UPDATE analytics_tenures SET vehicle = vehicle || jsonb_build_object('purchase_currency', 'MMK')
      WHERE NOT vehicle ? 'purchase_currency';
    UPDATE transferred_vehicles SET service_snapshot = (
      SELECT COALESCE(jsonb_agg(CASE WHEN item ? 'currency' THEN item
        ELSE item || jsonb_build_object('currency', 'MMK') END ORDER BY ordinal), '[]'::jsonb)
      FROM jsonb_array_elements(service_snapshot) WITH ORDINALITY AS entries(item, ordinal)
    );
    UPDATE transferred_vehicles SET vehicle_snapshot = vehicle_snapshot || jsonb_build_object('purchase_currency', 'MMK')
      WHERE vehicle_snapshot IS NOT NULL AND NOT vehicle_snapshot ? 'purchase_currency';
    INSERT INTO currency_migrations(name) VALUES ('mmk_baseline');
  END IF;
END $$;

-- Service and fuel accounting entries inherit the source event's currency.
-- This separate trigger survives the old accounting function being recreated
-- by migration 0020 on every boot. It also covers historical source corrections
-- after a transfer; the current owner's currency must never be consulted here.
CREATE OR REPLACE FUNCTION inherit_expense_currency() RETURNS trigger AS $$
DECLARE source_currency text;
BEGIN
  IF NEW.source_kind = 'service_record' THEN
    SELECT currency INTO source_currency FROM service_records WHERE id = NEW.source_id;
  ELSIF NEW.source_kind = 'fuel_log' THEN
    SELECT currency INTO source_currency FROM fuel_logs WHERE id = NEW.source_id;
  END IF;
  IF source_currency IS NOT NULL THEN
    IF TG_OP = 'UPDATE' AND source_currency IS DISTINCT FROM OLD.currency THEN
      RAISE EXCEPTION 'currency_immutable: a linked event cannot relabel historical costs';
    END IF;
    NEW.currency := source_currency;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS expense_currency_source ON expenses;
CREATE TRIGGER expense_currency_source BEFORE INSERT OR UPDATE ON expenses
  FOR EACH ROW EXECUTE FUNCTION inherit_expense_currency();

-- Even during staged rollout, no writer may relabel an existing monetary event.
CREATE OR REPLACE FUNCTION preserve_record_currency() RETURNS trigger AS $$
BEGIN
  IF TG_TABLE_NAME = 'vehicles' THEN
    IF OLD.purchase_price IS NOT NULL AND NEW.purchase_currency IS DISTINCT FROM OLD.purchase_currency THEN
      RAISE EXCEPTION 'currency_immutable: historical purchase currency cannot change';
    END IF;
  ELSIF TG_TABLE_NAME = 'work_orders' THEN
    IF OLD.completion_cost IS NOT NULL AND NEW.currency IS DISTINCT FROM OLD.currency THEN
      RAISE EXCEPTION 'currency_immutable: historical cost currency cannot change';
    END IF;
  ELSIF NEW.currency IS DISTINCT FROM OLD.currency THEN
    RAISE EXCEPTION 'currency_immutable: historical cost currency cannot change';
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
DO $$ DECLARE name text; BEGIN
  FOREACH name IN ARRAY ARRAY['vehicles','work_orders','expenses','fuel_logs','service_records'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS currency_immutable ON %I', name);
    EXECUTE format('CREATE TRIGGER currency_immutable BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION preserve_record_currency()', name);
  END LOOP;
END $$;
