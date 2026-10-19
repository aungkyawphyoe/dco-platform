CREATE TABLE IF NOT EXISTS organization_changes (
 seq bigserial PRIMARY KEY, org_id uuid NOT NULL REFERENCES organizations(id),
 vehicle_id uuid NOT NULL, entity_type text NOT NULL, entity_id uuid NOT NULL, op text NOT NULL
);
CREATE INDEX IF NOT EXISTS organization_changes_scope ON organization_changes(org_id, seq);
CREATE TABLE IF NOT EXISTS organization_operations (
 id uuid PRIMARY KEY, org_id uuid NOT NULL REFERENCES organizations(id), user_id uuid NOT NULL REFERENCES users(id),
 fingerprint text NOT NULL, status_code integer, result jsonb
);
CREATE TABLE IF NOT EXISTS organization_reviews (
 id uuid PRIMARY KEY, org_id uuid NOT NULL REFERENCES organizations(id), user_id uuid NOT NULL REFERENCES users(id),
 vehicle_id uuid NOT NULL, operation jsonb NOT NULL, reason text NOT NULL,
 status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
 reviewed_by uuid REFERENCES users(id), reviewer_note text, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE OR REPLACE FUNCTION track_organization_record() RETURNS trigger AS $$
DECLARE item jsonb; vehicle uuid; record_id uuid; organization uuid; kind text;
BEGIN
 item := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
 kind := TG_ARGV[0];
 record_id := (item->>'id')::uuid;
 IF TG_TABLE_NAME = 'vehicles' THEN vehicle := record_id;
 ELSIF TG_TABLE_NAME IN ('service_record_items', 'service_record_parts') THEN
   record_id := (item->>'service_record_id')::uuid;
   SELECT vehicle_id INTO vehicle FROM service_records WHERE id = record_id;
 ELSIF TG_TABLE_NAME = 'expense_parts' THEN
   record_id := (item->>'expense_id')::uuid;
   SELECT vehicle_id INTO vehicle FROM expenses WHERE id = record_id;
 ELSE vehicle := (item->>'vehicle_id')::uuid;
 END IF;
 SELECT org_id INTO organization FROM organization_vehicles WHERE vehicle_id = vehicle;
 IF organization IS NOT NULL THEN
   INSERT INTO organization_changes(org_id, vehicle_id, entity_type, entity_id, op)
   VALUES (organization, vehicle, kind, record_id,
     CASE WHEN TG_OP = 'DELETE' AND TG_TABLE_NAME NOT IN ('service_record_items', 'service_record_parts', 'expense_parts') THEN 'delete' ELSE 'upsert' END);
 END IF;
 RETURN NULL;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS organization_change ON vehicles;
CREATE TRIGGER organization_change AFTER INSERT OR UPDATE OR DELETE ON vehicles
FOR EACH ROW EXECUTE FUNCTION track_organization_record('vehicle');
DROP TRIGGER IF EXISTS organization_change ON plan_items;
CREATE TRIGGER organization_change AFTER INSERT OR UPDATE OR DELETE ON plan_items
FOR EACH ROW EXECUTE FUNCTION track_organization_record('plan_item');
DROP TRIGGER IF EXISTS organization_change ON service_records;
CREATE TRIGGER organization_change AFTER INSERT OR UPDATE OR DELETE ON service_records
FOR EACH ROW EXECUTE FUNCTION track_organization_record('service_record');
DROP TRIGGER IF EXISTS organization_change ON service_record_items;
CREATE TRIGGER organization_change AFTER INSERT OR UPDATE OR DELETE ON service_record_items
FOR EACH ROW EXECUTE FUNCTION track_organization_record('service_record');
DROP TRIGGER IF EXISTS organization_change ON service_record_parts;
CREATE TRIGGER organization_change AFTER INSERT OR UPDATE OR DELETE ON service_record_parts
FOR EACH ROW EXECUTE FUNCTION track_organization_record('service_record');
DROP TRIGGER IF EXISTS organization_change ON expenses;
CREATE TRIGGER organization_change AFTER INSERT OR UPDATE OR DELETE ON expenses
FOR EACH ROW EXECUTE FUNCTION track_organization_record('expense');
DROP TRIGGER IF EXISTS organization_change ON expense_parts;
CREATE TRIGGER organization_change AFTER INSERT OR UPDATE OR DELETE ON expense_parts
FOR EACH ROW EXECUTE FUNCTION track_organization_record('expense');
DROP TRIGGER IF EXISTS organization_change ON fuel_logs;
CREATE TRIGGER organization_change AFTER INSERT OR UPDATE OR DELETE ON fuel_logs
FOR EACH ROW EXECUTE FUNCTION track_organization_record('fuel_log');
DROP TRIGGER IF EXISTS organization_change ON documents;
CREATE TRIGGER organization_change AFTER INSERT OR UPDATE OR DELETE ON documents
FOR EACH ROW EXECUTE FUNCTION track_organization_record('document');
DROP TRIGGER IF EXISTS organization_change ON parts;
CREATE TRIGGER organization_change AFTER INSERT OR UPDATE OR DELETE ON parts
FOR EACH ROW EXECUTE FUNCTION track_organization_record('part');
