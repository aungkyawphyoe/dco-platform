ALTER TABLE fuel_logs ADD COLUMN IF NOT EXISTS battery_level integer CHECK (battery_level BETWEEN 0 AND 100);
CREATE TABLE IF NOT EXISTS fuel_catalog_migrations (name text PRIMARY KEY);
DO $$ BEGIN
 LOCK TABLE fuel_catalog_migrations IN EXCLUSIVE MODE;
 IF NOT EXISTS (SELECT 1 FROM fuel_catalog_migrations WHERE name='catalog_v2') THEN
UPDATE fuel_types SET name = CASE name WHEN 'Petrol' THEN '95 Octane gasoline (petrol)' WHEN 'Electricity' THEN 'Electric (Fast)' WHEN 'Electric' THEN 'Electric (Fast)' ELSE name END
WHERE name IN ('Petrol', 'Electricity', 'Electric');
UPDATE fuel_logs SET fuel_type_name = CASE fuel_type_name WHEN 'Petrol' THEN '95 Octane gasoline (petrol)' WHEN 'Electricity' THEN 'Electric (Fast)' WHEN 'Electric' THEN 'Electric (Fast)' ELSE fuel_type_name END
WHERE fuel_type_name IN ('Petrol', 'Electricity', 'Electric');
UPDATE change_log SET payload = jsonb_set(payload, '{name}', to_jsonb(CASE payload->>'name' WHEN 'Petrol' THEN '95 Octane gasoline (petrol)' ELSE 'Electric (Fast)' END))
WHERE entity_type='fuel_type' AND payload->>'name' IN ('Petrol','Electricity','Electric');
UPDATE change_log SET payload = jsonb_set(payload, '{fuel_type_name}', to_jsonb(CASE payload->>'fuel_type_name' WHEN 'Petrol' THEN '95 Octane gasoline (petrol)' ELSE 'Electric (Fast)' END))
WHERE entity_type='fuel_log' AND payload->>'fuel_type_name' IN ('Petrol','Electricity','Electric');
 INSERT INTO fuel_catalog_migrations VALUES ('catalog_v2');
 END IF;
END $$;
