-- Attribution foundation only. Access-policy activation is a separate rollout.
CREATE TABLE IF NOT EXISTS vehicle_ownership_periods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id),
  org_id uuid REFERENCES organizations(id),
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  origin text NOT NULL CHECK (origin IN ('observed','legacy_baseline')),
  CHECK ((user_id IS NULL) <> (org_id IS NULL)),
  CHECK (ended_at IS NULL OR ended_at >= started_at)
);
CREATE UNIQUE INDEX IF NOT EXISTS vehicle_ownership_period_current
  ON vehicle_ownership_periods(vehicle_id) WHERE ended_at IS NULL;
CREATE INDEX IF NOT EXISTS vehicle_ownership_period_org ON vehicle_ownership_periods(org_id, vehicle_id);
CREATE TABLE IF NOT EXISTS ownership_migration_reviews (
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  reason text NOT NULL,
  resolved_at timestamptz,
  PRIMARY KEY(entity_type, entity_id)
);

-- The baseline date is the observation date, not an invented purchase date.
INSERT INTO vehicle_ownership_periods(vehicle_id,user_id,org_id,origin)
SELECT v.id, CASE WHEN o.id IS NULL THEN v.user_id END, o.org_id, 'legacy_baseline'
FROM vehicles v LEFT JOIN organization_vehicles o ON o.vehicle_id=v.id
WHERE NOT EXISTS(SELECT 1 FROM vehicle_ownership_periods p WHERE p.vehicle_id=v.id AND p.ended_at IS NULL);

CREATE OR REPLACE FUNCTION reconcile_vehicle_ownership(target uuid) RETURNS void AS $$
DECLARE owner_id uuid; organization_id uuid; current_period vehicle_ownership_periods%ROWTYPE;
BEGIN
  -- Same vehicle-first serialization order as fleet writes and handover.
  SELECT user_id INTO owner_id FROM vehicles WHERE id=target FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  SELECT org_id INTO organization_id FROM organization_vehicles WHERE vehicle_id=target;
  IF organization_id IS NOT NULL THEN owner_id := NULL; END IF;
  SELECT * INTO current_period FROM vehicle_ownership_periods WHERE vehicle_id=target AND ended_at IS NULL;
  IF FOUND AND current_period.user_id IS NOT DISTINCT FROM owner_id
    AND current_period.org_id IS NOT DISTINCT FROM organization_id THEN RETURN; END IF;
  UPDATE vehicle_ownership_periods SET ended_at=now() WHERE vehicle_id=target AND ended_at IS NULL;
  INSERT INTO vehicle_ownership_periods(vehicle_id,user_id,org_id,origin)
    VALUES(target,owner_id,organization_id,'observed');
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION observe_vehicle_ownership() RETURNS trigger AS $$
BEGIN
  IF TG_TABLE_NAME='vehicles' THEN
    PERFORM reconcile_vehicle_ownership(NEW.id);
  ELSIF TG_OP='DELETE' THEN
    PERFORM reconcile_vehicle_ownership(OLD.vehicle_id);
  ELSE
    IF TG_OP='UPDATE' AND OLD.vehicle_id IS DISTINCT FROM NEW.vehicle_id THEN
      PERFORM reconcile_vehicle_ownership(OLD.vehicle_id);
    END IF;
    PERFORM reconcile_vehicle_ownership(NEW.vehicle_id);
  END IF;
  RETURN NULL;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS observe_ownership ON vehicles;
CREATE TRIGGER observe_ownership AFTER INSERT OR UPDATE OF user_id ON vehicles
  FOR EACH ROW EXECUTE FUNCTION observe_vehicle_ownership();
DROP TRIGGER IF EXISTS observe_ownership ON organization_vehicles;
CREATE TRIGGER observe_ownership AFTER INSERT OR UPDATE OR DELETE ON organization_vehicles
  FOR EACH ROW EXECUTE FUNCTION observe_vehicle_ownership();

-- No date-based guesses for legacy records: caller/service dates are not ownership evidence.
DO $$ DECLARE table_name text; BEGIN
  FOREACH table_name IN ARRAY ARRAY['plan_items','service_records','parts','fuel_logs','documents','expenses','work_orders','inspections','media_objects'] LOOP
    EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS ownership_period_id uuid REFERENCES vehicle_ownership_periods(id)', table_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %I(ownership_period_id,vehicle_id)',table_name || '_ownership_period',table_name);
    EXECUTE format('INSERT INTO ownership_migration_reviews(entity_type,entity_id,vehicle_id,reason)
      SELECT %L,id,vehicle_id,%L FROM %I WHERE ownership_period_id IS NULL AND vehicle_id IS NOT NULL ON CONFLICT DO NOTHING',
      table_name,'Legacy record needs ownership evidence; current owner and service date are insufficient',table_name);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION attribute_vehicle_record() RETURNS trigger AS $$
DECLARE period_id uuid; parent_period uuid;
BEGIN
  IF TG_OP='UPDATE' THEN
    -- Historical edits cannot move records into a new owner's period.
    IF NEW.vehicle_id IS DISTINCT FROM OLD.vehicle_id
      OR NEW.ownership_period_id IS DISTINCT FROM OLD.ownership_period_id THEN
      RAISE EXCEPTION 'ownership_attribution_immutable';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.vehicle_id IS NULL THEN RETURN NEW; END IF;
  PERFORM id FROM vehicles WHERE id=NEW.vehicle_id FOR UPDATE;
  SELECT id INTO period_id FROM vehicle_ownership_periods WHERE vehicle_id=NEW.vehicle_id AND ended_at IS NULL;
  IF period_id IS NULL THEN RAISE EXCEPTION 'ownership_period_missing'; END IF;
  IF TG_TABLE_NAME='expenses' THEN
    -- Derived accounting belongs to its source, including historical corrections.
    IF NEW.source_kind='service_record' THEN
      SELECT ownership_period_id INTO parent_period FROM service_records WHERE id=NEW.source_id AND vehicle_id=NEW.vehicle_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'ownership_source_missing'; END IF;
      period_id := parent_period;
    ELSIF NEW.source_kind='fuel_log' THEN
      SELECT ownership_period_id INTO parent_period FROM fuel_logs WHERE id=NEW.source_id AND vehicle_id=NEW.vehicle_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'ownership_source_missing'; END IF;
      period_id := parent_period;
    END IF;
  END IF;
  IF NEW.ownership_period_id IS NOT NULL AND NEW.ownership_period_id IS DISTINCT FROM period_id THEN
    RAISE EXCEPTION 'ownership_period_mismatch';
  END IF;
  NEW.ownership_period_id := period_id;
  IF period_id IS NULL THEN
    INSERT INTO ownership_migration_reviews(entity_type,entity_id,vehicle_id,reason)
      VALUES(TG_TABLE_NAME,NEW.id,NEW.vehicle_id,'Derived record inherits unresolved source attribution') ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
DO $$ DECLARE table_name text; BEGIN
  FOREACH table_name IN ARRAY ARRAY['plan_items','service_records','parts','fuel_logs','documents','expenses','work_orders','inspections','media_objects'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS attribute_ownership ON %I',table_name);
    EXECUTE format('CREATE TRIGGER attribute_ownership BEFORE INSERT OR UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION attribute_vehicle_record()',table_name);
  END LOOP;
END $$;
