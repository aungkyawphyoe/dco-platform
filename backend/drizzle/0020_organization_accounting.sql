-- All organization entry points (including work-order completion and legacy
-- clients) use the same accounting path. Personal behavior is unchanged.
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
  IF NOT EXISTS (SELECT 1 FROM organization_vehicles WHERE vehicle_id = source_row.vehicle_id) THEN
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
DROP TRIGGER IF EXISTS organization_service_expense ON service_records;
CREATE TRIGGER organization_service_expense AFTER INSERT OR UPDATE OR DELETE ON service_records
  FOR EACH ROW EXECUTE FUNCTION maintain_organization_expense();
DROP TRIGGER IF EXISTS organization_fuel_expense ON fuel_logs;
CREATE TRIGGER organization_fuel_expense AFTER INSERT OR UPDATE OR DELETE ON fuel_logs
  FOR EACH ROW EXECUTE FUNCTION maintain_organization_expense();

-- Backfill only unambiguous legacy costs: never add a second expense when an
-- older unlinked entry might already account for the same log. Review those
-- candidates before rollout rather than guessing authorship or financial links.
INSERT INTO expenses(id, vehicle_id, category, amount, incurred_on, created_by, source_kind, source_id)
SELECT s.id, s.vehicle_id, 'maintenance', s.total_cost, s.serviced_on, s.created_by, 'service_record', s.id
FROM service_records s JOIN organization_vehicles v ON v.vehicle_id = s.vehicle_id
WHERE NOT EXISTS (SELECT 1 FROM expenses e WHERE e.vehicle_id = s.vehicle_id AND e.category = 'maintenance'
  AND e.incurred_on = s.serviced_on AND e.amount = s.total_cost AND e.source_id IS NULL)
ON CONFLICT DO NOTHING;
INSERT INTO expenses(id, vehicle_id, category, amount, incurred_on, created_by, source_kind, source_id)
SELECT f.id, f.vehicle_id, 'fuel', f.cost, f.logged_on, f.user_id, 'fuel_log', f.id
FROM fuel_logs f JOIN organization_vehicles v ON v.vehicle_id = f.vehicle_id
WHERE NOT EXISTS (SELECT 1 FROM expenses e WHERE e.vehicle_id = f.vehicle_id AND e.category = 'fuel'
  AND e.incurred_on = f.logged_on AND e.amount = f.cost AND e.source_id IS NULL)
ON CONFLICT DO NOTHING;
