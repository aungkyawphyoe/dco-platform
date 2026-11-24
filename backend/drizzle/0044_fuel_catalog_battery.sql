ALTER TABLE fuel_logs ADD COLUMN IF NOT EXISTS battery_level integer CHECK (battery_level BETWEEN 0 AND 100);
CREATE TABLE IF NOT EXISTS fuel_catalog_migrations (name text PRIMARY KEY);

DO $$ BEGIN
  LOCK TABLE fuel_catalog_migrations IN EXCLUSIVE MODE;
  IF EXISTS (SELECT 1 FROM fuel_catalog_migrations WHERE name = 'catalog_v2') THEN
    RETURN;
  END IF;

  LOCK TABLE fuel_types IN SHARE ROW EXCLUSIVE MODE;

  -- Prefer an existing canonical row. If only legacy aliases exist, keep one
  -- deterministically so Electricity and Electric can converge on the same ID.
  CREATE TEMP TABLE fuel_catalog_v2_merge ON COMMIT DROP AS
  WITH names (alias, canonical) AS (
    VALUES ('petrol', '95 Octane gasoline (petrol)'),
      ('95 octane gasoline (petrol)', '95 Octane gasoline (petrol)'),
      ('electricity', 'Electric (Fast)'),
      ('electric', 'Electric (Fast)'),
      ('electric (fast)', 'Electric (Fast)')
  )
  SELECT t.id, t.user_id, n.canonical,
    first_value(t.id) OVER (
      PARTITION BY t.user_id, n.canonical
      ORDER BY (lower(t.name) = lower(n.canonical)) DESC, t.id
    ) AS keep_id
  FROM fuel_types t JOIN names n ON lower(t.name) = n.alias
  WHERE (n.canonical = 'Electric (Fast)' AND t.kind = 'electric' AND lower(t.unit) = 'kwh')
     OR (n.canonical = '95 Octane gasoline (petrol)' AND t.kind = 'liquid' AND lower(t.unit) = 'l')
     OR lower(t.name) = lower(n.canonical);

  -- Catalog changes should not regenerate expenses or attribute historical logs
  -- to the vehicle's current organization.
  ALTER TABLE fuel_logs DISABLE TRIGGER organization_fuel_expense;
  ALTER TABLE fuel_logs DISABLE TRIGGER analytics_fuel;
  UPDATE fuel_logs l SET fuel_type_id = m.keep_id, fuel_type_name = m.canonical
  FROM fuel_catalog_v2_merge m
  WHERE l.fuel_type_id = m.id
    AND (l.fuel_type_id IS DISTINCT FROM m.keep_id OR l.fuel_type_name IS DISTINCT FROM m.canonical);

  UPDATE fuel_logs SET fuel_type_name = CASE lower(fuel_type_name)
    WHEN 'petrol' THEN '95 Octane gasoline (petrol)' ELSE 'Electric (Fast)' END
  WHERE fuel_type_id IS NULL AND lower(fuel_type_name) IN ('petrol', 'electricity', 'electric');
  ALTER TABLE fuel_logs ENABLE TRIGGER analytics_fuel;
  ALTER TABLE fuel_logs ENABLE TRIGGER organization_fuel_expense;

  UPDATE change_log c SET payload = c.payload || jsonb_build_object(
    'fuel_type_id', m.keep_id, 'fuel_type_name', m.canonical)
  FROM fuel_catalog_v2_merge m
  WHERE c.entity_type = 'fuel_log' AND c.op = 'upsert' AND c.payload->>'fuel_type_id' = m.id::text;

  UPDATE change_log SET payload = jsonb_set(payload, '{fuel_type_name}', to_jsonb(
    CASE lower(payload->>'fuel_type_name') WHEN 'petrol' THEN '95 Octane gasoline (petrol)' ELSE 'Electric (Fast)' END))
  WHERE entity_type = 'fuel_log' AND op = 'upsert' AND payload->>'fuel_type_id' IS NULL
    AND lower(payload->>'fuel_type_name') IN ('petrol', 'electricity', 'electric');

  DELETE FROM fuel_types t USING fuel_catalog_v2_merge m WHERE t.id = m.id AND m.id <> m.keep_id;
  UPDATE fuel_types t SET name = m.canonical
  FROM fuel_catalog_v2_merge m WHERE t.id = m.id AND m.id = m.keep_id AND t.name <> m.canonical;

  UPDATE change_log c SET payload = jsonb_set(c.payload, '{name}', to_jsonb(m.canonical))
  FROM fuel_catalog_v2_merge m
  WHERE c.entity_type = 'fuel_type' AND c.op = 'upsert' AND c.entity_id = m.id AND m.id = m.keep_id
    AND c.user_id = m.user_id;
  INSERT INTO change_log (user_id, entity_type, entity_id, op, payload)
  SELECT user_id, 'fuel_type', id, 'delete', '{}'::jsonb
  FROM fuel_catalog_v2_merge WHERE id <> keep_id;

  INSERT INTO fuel_catalog_migrations VALUES ('catalog_v2');
END $$;
