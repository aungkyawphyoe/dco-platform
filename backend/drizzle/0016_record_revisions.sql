-- Revision is advanced by every writer, including legacy fleet endpoints.
CREATE OR REPLACE FUNCTION advance_vehicle_record_revision() RETURNS trigger AS $$
BEGIN
  NEW.revision := OLD.revision + 1;
  IF current_setting('autox.record_admin', true) <> '' THEN
    NEW.admin_corrected_by := current_setting('autox.record_admin', true)::uuid;
  ELSE
    NEW.admin_corrected_by := OLD.admin_corrected_by;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
ALTER TABLE service_records ADD COLUMN IF NOT EXISTS revision integer NOT NULL DEFAULT 1;
ALTER TABLE service_records ADD COLUMN IF NOT EXISTS admin_corrected_by uuid REFERENCES users(id);
DROP TRIGGER IF EXISTS record_revision ON service_records;
CREATE TRIGGER record_revision BEFORE UPDATE ON service_records
FOR EACH ROW EXECUTE FUNCTION advance_vehicle_record_revision();
ALTER TABLE fuel_logs ADD COLUMN IF NOT EXISTS revision integer NOT NULL DEFAULT 1;
ALTER TABLE fuel_logs ADD COLUMN IF NOT EXISTS admin_corrected_by uuid REFERENCES users(id);
DROP TRIGGER IF EXISTS record_revision ON fuel_logs;
CREATE TRIGGER record_revision BEFORE UPDATE ON fuel_logs
FOR EACH ROW EXECUTE FUNCTION advance_vehicle_record_revision();
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS revision integer NOT NULL DEFAULT 1;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS admin_corrected_by uuid REFERENCES users(id);
DROP TRIGGER IF EXISTS record_revision ON expenses;
CREATE TRIGGER record_revision BEFORE UPDATE ON expenses
FOR EACH ROW EXECUTE FUNCTION advance_vehicle_record_revision();
ALTER TABLE documents ADD COLUMN IF NOT EXISTS revision integer NOT NULL DEFAULT 1;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS admin_corrected_by uuid REFERENCES users(id);
DROP TRIGGER IF EXISTS record_revision ON documents;
CREATE TRIGGER record_revision BEFORE UPDATE ON documents
FOR EACH ROW EXECUTE FUNCTION advance_vehicle_record_revision();
ALTER TABLE parts ADD COLUMN IF NOT EXISTS revision integer NOT NULL DEFAULT 1;
ALTER TABLE parts ADD COLUMN IF NOT EXISTS admin_corrected_by uuid REFERENCES users(id);
DROP TRIGGER IF EXISTS record_revision ON parts;
CREATE TRIGGER record_revision BEFORE UPDATE ON parts
FOR EACH ROW EXECUTE FUNCTION advance_vehicle_record_revision();
