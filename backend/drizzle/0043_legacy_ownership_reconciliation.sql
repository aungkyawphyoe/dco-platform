-- Permit ownership attribution changes only inside the explicit admin reconciliation transaction.
CREATE OR REPLACE FUNCTION attribute_vehicle_record() RETURNS trigger AS $$
DECLARE period_id uuid; parent_period uuid;
BEGIN
  IF TG_OP='UPDATE' THEN
    IF NEW.vehicle_id IS DISTINCT FROM OLD.vehicle_id THEN
      RAISE EXCEPTION 'ownership_attribution_immutable';
    END IF;
    IF NEW.ownership_period_id IS DISTINCT FROM OLD.ownership_period_id THEN
      IF current_setting('app.allow_ownership_reconciliation', true) IS DISTINCT FROM 'on'
        OR OLD.ownership_period_id IS NOT NULL OR NEW.ownership_period_id IS NULL THEN
        RAISE EXCEPTION 'ownership_attribution_immutable';
      END IF;
      RETURN NEW;
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.vehicle_id IS NULL THEN RETURN NEW; END IF;
  PERFORM id FROM vehicles WHERE id=NEW.vehicle_id FOR UPDATE;
  SELECT id INTO period_id FROM vehicle_ownership_periods WHERE vehicle_id=NEW.vehicle_id AND ended_at IS NULL;
  IF period_id IS NULL THEN RAISE EXCEPTION 'ownership_period_missing'; END IF;
  IF TG_TABLE_NAME='expenses' THEN
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
