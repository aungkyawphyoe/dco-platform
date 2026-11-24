-- Attribute projection writes to the source ownership period, including historical corrections.
CREATE INDEX IF NOT EXISTS analytics_records_legacy_source
  ON analytics_records(kind, id) WHERE payload->>'ownership_period_id' IS NULL;

CREATE OR REPLACE FUNCTION analytics_capture_record() RETURNS trigger AS $$
DECLARE r record; organization uuid; k text;
BEGIN
  IF TG_OP = 'DELETE' THEN r := OLD; ELSE r := NEW; END IF;
  k := CASE TG_TABLE_NAME WHEN 'expenses' THEN 'expense' WHEN 'fuel_logs' THEN 'fuel_log' ELSE 'service_record' END;
  IF TG_OP = 'DELETE' AND r.ownership_period_id IS NOT NULL THEN
    -- Retain the proof used to filter mismatched legacy copies after the source disappears.
    UPDATE analytics_records SET payload = payload || jsonb_build_object('ownership_period_id', r.ownership_period_id)
    WHERE kind = k AND id = r.id AND vehicle_id = r.vehicle_id AND payload->>'ownership_period_id' IS NULL;
  END IF;
  SELECT org_id INTO organization FROM vehicle_ownership_periods WHERE id = r.ownership_period_id AND vehicle_id = r.vehicle_id;
  IF organization IS NULL THEN RETURN NULL; END IF;
  IF TG_OP = 'DELETE' THEN
    DELETE FROM analytics_records WHERE org_id = organization AND kind = k AND id = r.id;
  ELSE
    INSERT INTO analytics_records(org_id,vehicle_id,kind,id,payload)
      VALUES(organization,r.vehicle_id,k,r.id,
        to_jsonb(r) || jsonb_build_object('odometer_unit',(SELECT mileage_unit FROM vehicles WHERE id=r.vehicle_id))
        || CASE WHEN k = 'service_record' THEN jsonb_build_object('items', COALESCE(
             (SELECT jsonb_agg(jsonb_build_object('name', i.name, 'line_cost', i.line_cost) ORDER BY i.id)
              FROM service_record_items i WHERE i.service_record_id = r.id), '[]'::jsonb))
           ELSE '{}'::jsonb END)
      ON CONFLICT(org_id,kind,id) DO UPDATE SET payload = EXCLUDED.payload || jsonb_build_object(
        'odometer_unit', COALESCE(analytics_records.payload->>'odometer_unit', EXCLUDED.payload->>'odometer_unit'));
  END IF;
  RETURN NULL;
END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION analytics_capture_service_items() RETURNS trigger AS $$
DECLARE r record; organization uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN r := OLD; ELSE r := NEW; END IF;
  SELECT p.org_id INTO organization
    FROM service_records s JOIN vehicle_ownership_periods p
      ON p.id = s.ownership_period_id AND p.vehicle_id = s.vehicle_id
    WHERE s.id = r.service_record_id;
  IF organization IS NULL THEN RETURN NULL; END IF;
  UPDATE analytics_records a
    SET payload = a.payload || jsonb_build_object('items', COALESCE(
      (SELECT jsonb_agg(jsonb_build_object('name', i.name, 'line_cost', i.line_cost) ORDER BY i.id)
       FROM service_record_items i WHERE i.service_record_id = r.service_record_id), '[]'::jsonb))
    WHERE a.org_id = organization AND a.kind = 'service_record' AND a.id = r.service_record_id;
  RETURN NULL;
END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION analytics_capture_expense_deletion() RETURNS trigger AS $$
BEGIN
  INSERT INTO analytics_records (org_id, vehicle_id, kind, id, payload)
  SELECT p.org_id, OLD.vehicle_id, 'expense_deleted', OLD.id,
    jsonb_build_object(
      'incurred_on', OLD.incurred_on,
      'category', OLD.category,
      'currency', OLD.currency,
      'source_kind', OLD.source_kind,
      'source_id', OLD.source_id,
      'ownership_period_id', OLD.ownership_period_id,
      'revision', OLD.revision::bigint + 1,
      'deleted_at', transaction_timestamp()
    )
  FROM vehicle_ownership_periods p
  WHERE p.id = OLD.ownership_period_id AND p.vehicle_id = OLD.vehicle_id AND p.org_id IS NOT NULL
  ON CONFLICT (org_id, kind, id) DO UPDATE SET payload = EXCLUDED.payload;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maintain_organization_expense() RETURNS trigger AS $$
DECLARE
  source_row record;
  source_type text;
  cost numeric;
  cost_date date;
  author uuid;
  category_name expense_category;
BEGIN
  IF TG_OP = 'DELETE' THEN source_row := OLD; ELSE source_row := NEW; END IF;
  IF NOT EXISTS (SELECT 1 FROM vehicle_ownership_periods
    WHERE id = source_row.ownership_period_id AND vehicle_id = source_row.vehicle_id AND org_id IS NOT NULL) THEN
    RETURN NULL;
  END IF;
  IF TG_TABLE_NAME = 'service_records' THEN
    source_type := 'service_record'; cost := source_row.total_cost;
    cost_date := source_row.serviced_on; author := source_row.created_by;
    category_name := 'maintenance';
  ELSE
    source_type := 'fuel_log'; cost := source_row.cost;
    cost_date := source_row.logged_on; author := source_row.user_id;
    category_name := 'fuel';
  END IF;
  IF TG_OP <> 'INSERT' AND NOT EXISTS
      (SELECT 1 FROM expenses WHERE source_kind = source_type AND source_id = source_row.id)
      AND EXISTS (SELECT 1 FROM expenses e WHERE e.vehicle_id = source_row.vehicle_id
        AND e.category = category_name AND e.source_id IS NULL
        AND e.incurred_on = CASE WHEN TG_TABLE_NAME = 'service_records' THEN (to_jsonb(OLD)->>'serviced_on')::date ELSE (to_jsonb(OLD)->>'logged_on')::date END
        AND e.amount = CASE WHEN TG_TABLE_NAME = 'service_records' THEN (to_jsonb(OLD)->>'total_cost')::numeric ELSE (to_jsonb(OLD)->>'cost')::numeric END) THEN
    RAISE EXCEPTION 'legacy_cost_review_required: reconcile the existing expense before correcting this log';
  END IF;
  IF TG_OP = 'DELETE' THEN
    DELETE FROM expense_parts WHERE expense_id IN
      (SELECT id FROM expenses WHERE source_kind = source_type AND source_id = source_row.id);
    DELETE FROM expenses WHERE source_kind = source_type AND source_id = source_row.id;
  ELSE
    UPDATE expenses SET amount = cost, incurred_on = cost_date
      WHERE source_kind = source_type AND source_id = source_row.id;
    IF FOUND THEN RETURN NULL; END IF;
    INSERT INTO expenses(id, vehicle_id, category, amount, incurred_on, created_by, source_kind, source_id)
      VALUES(source_row.id, source_row.vehicle_id, category_name, cost, cost_date, author, source_type, source_row.id)
      ON CONFLICT(id) DO UPDATE SET amount = EXCLUDED.amount, incurred_on = EXCLUDED.incurred_on
      WHERE expenses.source_kind = source_type AND expenses.source_id = source_row.id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Organization accounting ID conflict'; END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

INSERT INTO analytics_migrations(name) VALUES ('attributed_records') ON CONFLICT DO NOTHING;
