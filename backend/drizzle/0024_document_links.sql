CREATE TABLE IF NOT EXISTS document_links (
  id uuid PRIMARY KEY,
  document_id uuid NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  service_record_id uuid REFERENCES service_records(id) ON DELETE CASCADE,
  fuel_log_id uuid REFERENCES fuel_logs(id) ON DELETE CASCADE,
  CHECK ((service_record_id IS NOT NULL)::integer + (fuel_log_id IS NOT NULL)::integer = 1)
);
CREATE UNIQUE INDEX IF NOT EXISTS document_links_service_unique ON document_links(document_id, service_record_id) WHERE service_record_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS document_links_fuel_unique ON document_links(document_id, fuel_log_id) WHERE fuel_log_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS document_links_service_idx ON document_links(service_record_id);
CREATE INDEX IF NOT EXISTS document_links_fuel_idx ON document_links(fuel_log_id);

CREATE TABLE IF NOT EXISTS document_storage_migrations (name text PRIMARY KEY);
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM document_storage_migrations WHERE name = 'legacy_service_links') THEN
-- Keep legacy service receipts discoverable without duplicating their stored bytes.
INSERT INTO documents(id, vehicle_id, name, category, media_id, created_by)
SELECT DISTINCT ON (s.vehicle_id, s.receipt_media_id) gen_random_uuid(), s.vehicle_id, 'Service invoice', 'invoice', s.receipt_media_id, s.created_by
FROM service_records s JOIN media_objects m ON m.id = s.receipt_media_id
WHERE NOT EXISTS (SELECT 1 FROM documents d WHERE d.vehicle_id = s.vehicle_id AND d.media_id = s.receipt_media_id);
INSERT INTO document_links(id, document_id, service_record_id)
SELECT gen_random_uuid(), (SELECT d.id FROM documents d WHERE d.vehicle_id = s.vehicle_id AND d.media_id = s.receipt_media_id ORDER BY d.id LIMIT 1), s.id
FROM service_records s WHERE s.receipt_media_id IS NOT NULL
AND EXISTS (SELECT 1 FROM documents d WHERE d.vehicle_id = s.vehicle_id AND d.media_id = s.receipt_media_id)
ON CONFLICT DO NOTHING;

INSERT INTO document_storage_migrations VALUES ('legacy_service_links');
END IF;
END $$;

CREATE OR REPLACE FUNCTION track_document_link() RETURNS trigger AS $$
DECLARE doc uuid; vehicle uuid; organization uuid;
BEGIN
 doc := CASE WHEN TG_OP = 'DELETE' THEN OLD.document_id ELSE NEW.document_id END;
 SELECT vehicle_id INTO vehicle FROM documents WHERE id = doc;
 SELECT org_id INTO organization FROM organization_vehicles WHERE vehicle_id = vehicle;
 IF organization IS NOT NULL THEN
  INSERT INTO organization_changes(org_id, vehicle_id, entity_type, entity_id, op)
  VALUES(organization, vehicle, 'document', doc, 'upsert');
 END IF;
 RETURN NULL;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS document_link_change ON document_links;
CREATE TRIGGER document_link_change AFTER INSERT OR DELETE ON document_links
FOR EACH ROW EXECUTE FUNCTION track_document_link();
