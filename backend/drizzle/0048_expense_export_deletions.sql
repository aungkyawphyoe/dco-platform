DO $legacy_analytics$ BEGIN
IF NOT EXISTS (SELECT 1 FROM analytics_migrations WHERE name = 'attributed_records') THEN
CREATE OR REPLACE FUNCTION analytics_capture_expense_deletion() RETURNS trigger AS $$
BEGIN
  INSERT INTO analytics_records (org_id, vehicle_id, kind, id, payload)
  SELECT r.org_id, r.vehicle_id, 'expense_deleted', r.id,
    jsonb_build_object(
      'incurred_on', r.payload->'incurred_on',
      'category', r.payload->'category',
      'currency', r.payload->'currency',
      'source_kind', r.payload->'source_kind',
      'source_id', r.payload->'source_id',
      'revision', OLD.revision::bigint + 1,
      'deleted_at', transaction_timestamp()
    )
  FROM analytics_records r
  JOIN organization_vehicles v ON v.vehicle_id = r.vehicle_id AND v.org_id = r.org_id
  WHERE r.kind = 'expense' AND r.id = OLD.id AND r.vehicle_id = OLD.vehicle_id
  ON CONFLICT (org_id, kind, id) DO UPDATE SET payload = EXCLUDED.payload;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS analytics_expense_export_deletion ON expenses;
CREATE TRIGGER analytics_expense_export_deletion BEFORE DELETE ON expenses
  FOR EACH ROW EXECUTE FUNCTION analytics_capture_expense_deletion();
END IF;
END $legacy_analytics$;
