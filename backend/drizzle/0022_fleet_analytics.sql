ALTER TABLE fuel_logs ADD COLUMN IF NOT EXISTS fill_status text NOT NULL DEFAULT 'unknown'
  CHECK (fill_status IN ('full', 'partial', 'unknown'));

-- Freeze the organization's view when a vehicle leaves. Later owners' writes,
-- including backdated writes, cannot alter the previous organization's report.
CREATE TABLE IF NOT EXISTS analytics_tenures (
  id uuid PRIMARY KEY, org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE, started_at timestamptz NOT NULL,
  ended_at timestamptz, vehicle jsonb NOT NULL
);
CREATE INDEX IF NOT EXISTS analytics_tenures_org ON analytics_tenures(org_id, vehicle_id);
CREATE TABLE IF NOT EXISTS analytics_records (
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE, vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  kind text NOT NULL, id uuid NOT NULL, payload jsonb NOT NULL,
  PRIMARY KEY(org_id, kind, id)
);
CREATE INDEX IF NOT EXISTS analytics_records_scope ON analytics_records(org_id, vehicle_id);
CREATE INDEX IF NOT EXISTS analytics_records_date ON analytics_records(org_id, (COALESCE(payload->>'incurred_on',payload->>'serviced_on',payload->>'logged_on')));
INSERT INTO analytics_tenures(id, org_id, vehicle_id, started_at, vehicle)
SELECT o.id, o.org_id, o.vehicle_id, o.added_at, to_jsonb(v) FROM organization_vehicles o
JOIN vehicles v ON v.id = o.vehicle_id ON CONFLICT DO NOTHING;

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
      VALUES(organization,r.vehicle_id,k,r.id,to_jsonb(r) || jsonb_build_object('odometer_unit',(SELECT mileage_unit FROM vehicles WHERE id=r.vehicle_id)))
      ON CONFLICT(org_id,kind,id) DO UPDATE SET payload = EXCLUDED.payload;
  END IF;
  RETURN NULL;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS analytics_expense ON expenses;
CREATE TRIGGER analytics_expense AFTER INSERT OR UPDATE OR DELETE ON expenses FOR EACH ROW EXECUTE FUNCTION analytics_capture_record();
DROP TRIGGER IF EXISTS analytics_fuel ON fuel_logs;
CREATE TRIGGER analytics_fuel AFTER INSERT OR UPDATE OR DELETE ON fuel_logs FOR EACH ROW EXECUTE FUNCTION analytics_capture_record();
DROP TRIGGER IF EXISTS analytics_service ON service_records;
CREATE TRIGGER analytics_service AFTER INSERT OR UPDATE OR DELETE ON service_records FOR EACH ROW EXECUTE FUNCTION analytics_capture_record();

-- Current-org baseline only. Historical transfers with no saved attribution
-- are surfaced as unavailable; never copy records from the new owner's garage.
CREATE TABLE IF NOT EXISTS analytics_migrations (name text PRIMARY KEY);
DO $$ BEGIN
IF NOT EXISTS(SELECT 1 FROM analytics_migrations WHERE name='baseline') THEN
  INSERT INTO analytics_records SELECT o.org_id,e.vehicle_id,'expense',e.id,to_jsonb(e) || jsonb_build_object('odometer_unit',(SELECT mileage_unit FROM vehicles WHERE id=e.vehicle_id))
    FROM expenses e JOIN organization_vehicles o ON o.vehicle_id=e.vehicle_id
    WHERE e.incurred_on >= o.added_at::date ON CONFLICT DO NOTHING;
  INSERT INTO analytics_records SELECT o.org_id,e.vehicle_id,'fuel_log',e.id,to_jsonb(e) || jsonb_build_object('odometer_unit',(SELECT mileage_unit FROM vehicles WHERE id=e.vehicle_id))
    FROM fuel_logs e JOIN organization_vehicles o ON o.vehicle_id=e.vehicle_id
    WHERE e.logged_on >= o.added_at::date ON CONFLICT DO NOTHING;
  INSERT INTO analytics_records SELECT o.org_id,e.vehicle_id,'service_record',e.id,to_jsonb(e) || jsonb_build_object('odometer_unit',(SELECT mileage_unit FROM vehicles WHERE id=e.vehicle_id))
    FROM service_records e JOIN organization_vehicles o ON o.vehicle_id=e.vehicle_id
    WHERE e.serviced_on >= o.added_at::date ON CONFLICT DO NOTHING;
  INSERT INTO analytics_migrations VALUES('baseline');
END IF;
END $$;

CREATE OR REPLACE FUNCTION analytics_capture_tenure() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE analytics_tenures SET ended_at=now(), vehicle=(SELECT to_jsonb(v) FROM vehicles v WHERE v.id=OLD.vehicle_id)
      WHERE id=OLD.id;
  ELSE
    INSERT INTO analytics_tenures(id,org_id,vehicle_id,started_at,vehicle)
      SELECT NEW.id,NEW.org_id,NEW.vehicle_id,NEW.added_at,to_jsonb(v) FROM vehicles v WHERE v.id=NEW.vehicle_id
      ON CONFLICT DO NOTHING;
  END IF;
  RETURN NULL;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS analytics_tenure ON organization_vehicles;
CREATE TRIGGER analytics_tenure AFTER INSERT OR DELETE ON organization_vehicles FOR EACH ROW EXECUTE FUNCTION analytics_capture_tenure();
