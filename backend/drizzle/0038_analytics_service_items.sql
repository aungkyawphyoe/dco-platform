-- Cost by service type needs the line items behind a service record, not just
-- its total. Keep them in the frozen analytics snapshot so transferred vehicles
-- and later item edits cannot rewrite another organization's report.

-- The service record row is captured before its items exist, and a later
-- correction replaces the payload. Both paths attach the current item list.
CREATE OR REPLACE FUNCTION analytics_capture_record() RETURNS trigger AS $$
DECLARE r record; organization uuid; k text;
BEGIN
  IF TG_OP = 'DELETE' THEN r := OLD; ELSE r := NEW; END IF;
  SELECT org_id INTO organization FROM organization_vehicles WHERE vehicle_id = r.vehicle_id;
  IF organization IS NULL THEN RETURN NULL; END IF;
  k := CASE TG_TABLE_NAME WHEN 'expenses' THEN 'expense' WHEN 'fuel_logs' THEN 'fuel_log' ELSE 'service_record' END;
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
      ON CONFLICT(org_id,kind,id) DO UPDATE SET payload = EXCLUDED.payload;
  END IF;
  RETURN NULL;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS analytics_service ON service_records;
CREATE TRIGGER analytics_service AFTER INSERT OR UPDATE OR DELETE ON service_records
  FOR EACH ROW EXECUTE FUNCTION analytics_capture_record();

-- Items are written after their parent service record, so refresh the snapshot
-- whenever an item is added, corrected, or removed.
CREATE OR REPLACE FUNCTION analytics_capture_service_items() RETURNS trigger AS $$
DECLARE r record; organization uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN r := OLD; ELSE r := NEW; END IF;
  SELECT org_id INTO organization FROM organization_vehicles
    WHERE vehicle_id = (SELECT vehicle_id FROM service_records WHERE id = r.service_record_id);
  IF organization IS NULL THEN RETURN NULL; END IF;
  UPDATE analytics_records a
    SET payload = a.payload || jsonb_build_object('items', COALESCE(
      (SELECT jsonb_agg(jsonb_build_object('name', i.name, 'line_cost', i.line_cost) ORDER BY i.id)
       FROM service_record_items i WHERE i.service_record_id = r.service_record_id), '[]'::jsonb))
    WHERE a.org_id = organization AND a.kind = 'service_record' AND a.id = r.service_record_id;
  RETURN NULL;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS analytics_service_items ON service_record_items;
CREATE TRIGGER analytics_service_items AFTER INSERT OR UPDATE OR DELETE ON service_record_items
  FOR EACH ROW EXECUTE FUNCTION analytics_capture_service_items();

-- Existing snapshots predate item capture; fill them once. Later edits are
-- maintained by the trigger above.
UPDATE analytics_records a
SET payload = a.payload || jsonb_build_object('items', COALESCE(
  (SELECT jsonb_agg(jsonb_build_object('name', i.name, 'line_cost', i.line_cost) ORDER BY i.id)
   FROM service_record_items i WHERE i.service_record_id = a.id), '[]'::jsonb))
WHERE a.kind = 'service_record';
