DROP TRIGGER IF EXISTS currency_scope_lock ON users;
DROP TRIGGER IF EXISTS currency_scope_lock ON organizations;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_currency_check;
ALTER TABLE users ADD CONSTRAINT users_currency_check CHECK (currency ~ '^[A-Z]{3}$');
ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_currency_check;
ALTER TABLE organizations ADD CONSTRAINT organizations_currency_check CHECK (currency ~ '^[A-Z]{3}$');
ALTER TABLE vehicles DROP CONSTRAINT IF EXISTS vehicles_purchase_currency_check;
ALTER TABLE vehicles ADD CONSTRAINT vehicles_purchase_currency_check CHECK (purchase_currency ~ '^[A-Z]{3}$');
DROP TRIGGER IF EXISTS currency_immutable ON vehicles;
ALTER TABLE service_records DROP CONSTRAINT IF EXISTS service_records_currency_check;
ALTER TABLE service_records ADD CONSTRAINT service_records_currency_check CHECK (currency ~ '^[A-Z]{3}$');
DROP TRIGGER IF EXISTS currency_immutable ON service_records;
ALTER TABLE fuel_logs DROP CONSTRAINT IF EXISTS fuel_logs_currency_check;
ALTER TABLE fuel_logs ADD CONSTRAINT fuel_logs_currency_check CHECK (currency ~ '^[A-Z]{3}$');
DROP TRIGGER IF EXISTS currency_immutable ON fuel_logs;
ALTER TABLE expenses DROP CONSTRAINT IF EXISTS expenses_currency_check;
ALTER TABLE expenses ADD CONSTRAINT expenses_currency_check CHECK (currency ~ '^[A-Z]{3}$');
DROP TRIGGER IF EXISTS currency_immutable ON expenses;
ALTER TABLE work_orders DROP CONSTRAINT IF EXISTS work_orders_currency_check;
ALTER TABLE work_orders ADD CONSTRAINT work_orders_currency_check CHECK (currency ~ '^[A-Z]{3}$');
DROP TRIGGER IF EXISTS currency_immutable ON work_orders;
CREATE OR REPLACE FUNCTION inherit_expense_currency() RETURNS trigger AS $$
DECLARE source_currency text;
BEGIN
  IF NEW.source_kind = 'service_record' THEN
    SELECT currency INTO source_currency FROM service_records WHERE id = NEW.source_id;
  ELSIF NEW.source_kind = 'fuel_log' THEN
    SELECT currency INTO source_currency FROM fuel_logs WHERE id = NEW.source_id;
  END IF;
  IF source_currency IS NOT NULL THEN
    NEW.currency := source_currency;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS base_currency text;
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS allow_member_currency boolean NOT NULL DEFAULT false;

-- A preference is never locked by a monetary write. Record validation is
-- performed on the request, before NUMERIC columns round the supplied value.
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
    IF NOT active AND expected IS NULL THEN
      UPDATE organizations SET currency=code WHERE id=organization_id;
    END IF;
    IF active AND expected IS NULL THEN RAISE EXCEPTION 'currency_required: Fleet Admin must confirm a currency first'; END IF;
    IF active AND NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id=vehicle AND v.allow_member_currency) AND code IS DISTINCT FROM COALESCE((SELECT v.base_currency FROM vehicles v WHERE v.id=vehicle), expected) THEN RAISE EXCEPTION 'currency_mismatch: review the amount in the current currency' USING DETAIL=json_build_object('current_currency',expected)::text; END IF;
  ELSE
    SELECT currency INTO expected FROM users WHERE id=owner_id FOR UPDATE;
    IF active AND NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id=vehicle AND v.allow_member_currency) AND code IS DISTINCT FROM COALESCE((SELECT v.base_currency FROM vehicles v WHERE v.id=vehicle), expected) THEN RAISE EXCEPTION 'currency_mismatch: review the amount in the current currency' USING DETAIL=json_build_object('current_currency',expected)::text; END IF;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
ALTER TABLE organization_members ADD COLUMN IF NOT EXISTS display_currency text;
