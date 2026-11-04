-- Approved pre-launch maintenance reset. Keep vehicle/account/document/part data.
-- The runner replays SQL on startup, so commit the reset and marker atomically.
CREATE TABLE IF NOT EXISTS maintenance_migrations (name text PRIMARY KEY);
DO $$ BEGIN
  LOCK TABLE maintenance_migrations IN EXCLUSIVE MODE;
  IF NOT EXISTS (SELECT 1 FROM maintenance_migrations WHERE name = 'names_only_catalog') THEN
    UPDATE change_log SET op = 'delete', payload = jsonb_build_object('id', entity_id)
      WHERE entity_type IN ('plan_item', 'service_record')
         OR (entity_type = 'expense' AND entity_id IN (
           SELECT id FROM expenses WHERE source_kind = 'service_record'
         ));
    DELETE FROM expenses WHERE source_kind = 'service_record';
    DELETE FROM notification_feed WHERE plan_item_id IS NOT NULL;
    DELETE FROM service_record_parts;
    DELETE FROM service_record_items;
    DELETE FROM service_records;
    DELETE FROM plan_items;
    UPDATE organization_vehicles SET maintenance_template_class = NULL;
    DELETE FROM maintenance_catalog;

    INSERT INTO maintenance_catalog (id, catalog_key, name, fuel_types, sort_order) VALUES
      ('e1000000-0000-0000-0000-000000000001', 'air_conditioning', 'Air Conditioning', ARRAY['petrol','electric','hybrid_plugin'], 1),
      ('e1000000-0000-0000-0000-000000000002', 'air_filter', 'Air Filter', ARRAY['petrol','electric','hybrid_plugin'], 2),
      ('e1000000-0000-0000-0000-000000000003', 'battery', 'Battery', ARRAY['petrol','electric','hybrid_plugin'], 3),
      ('e1000000-0000-0000-0000-000000000004', 'belts', 'Belts', ARRAY['petrol','electric','hybrid_plugin'], 4),
      ('e1000000-0000-0000-0000-000000000005', 'brake_fluid', 'Brake Fluid', ARRAY['petrol','electric','hybrid_plugin'], 5),
      ('e1000000-0000-0000-0000-000000000006', 'brake_pads', 'Brake Pads', ARRAY['petrol','electric','hybrid_plugin'], 6),
      ('e1000000-0000-0000-0000-000000000007', 'car_wash', 'Car Wash', ARRAY['petrol','electric','hybrid_plugin'], 7),
      ('e1000000-0000-0000-0000-000000000008', 'fuel_filter', 'Fuel Filter', ARRAY['petrol','electric','hybrid_plugin'], 8),
      ('e1000000-0000-0000-0000-000000000009', 'lights', 'Lights', ARRAY['petrol','electric','hybrid_plugin'], 9),
      ('e1000000-0000-0000-0000-000000000010', 'mileage_update', 'Mileage Update', ARRAY['petrol','electric','hybrid_plugin'], 10),
      ('e1000000-0000-0000-0000-000000000011', 'new_tires', 'New Tires', ARRAY['petrol','electric','hybrid_plugin'], 11),
      ('e1000000-0000-0000-0000-000000000012', 'oil_change', 'Oil Change', ARRAY['petrol','electric','hybrid_plugin'], 12),
      ('e1000000-0000-0000-0000-000000000013', 'oil_filter', 'Oil Filter', ARRAY['petrol','electric','hybrid_plugin'], 13),
      ('e1000000-0000-0000-0000-000000000014', 'schedule_maintenance', 'Schedule Maintenance', ARRAY['petrol','electric','hybrid_plugin'], 14),
      ('e1000000-0000-0000-0000-000000000015', 'suspension_shock_absorbers', 'Suspension/Shock Absorbers', ARRAY['petrol','electric','hybrid_plugin'], 15),
      ('e1000000-0000-0000-0000-000000000016', 'tires_alignment_balancing', 'Tires - Alignment/Balancing', ARRAY['petrol','electric','hybrid_plugin'], 16),
      ('e1000000-0000-0000-0000-000000000017', 'tires_pressure', 'Tires - Pressure', ARRAY['petrol','electric','hybrid_plugin'], 17),
      ('e1000000-0000-0000-0000-000000000018', 'tire_rotation', 'Tire - Rotation', ARRAY['petrol','electric','hybrid_plugin'], 18);
    INSERT INTO maintenance_migrations (name) VALUES ('names_only_catalog');
  END IF;
END $$;
