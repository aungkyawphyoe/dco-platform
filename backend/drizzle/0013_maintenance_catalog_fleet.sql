-- Migration 0013: Fleet maintenance templates
-- Adds vehicle_class to vehicles and maintenance_catalog, optional lifecycle
-- narrowing, org-scoped template copies (org_id), and the template assignment
-- FK on organization_vehicles. Seeds motorcycle/truck/van defaults and applies
-- the researched rounded intervals to the existing 11 car rows (one-time).
-- Every statement is idempotent: this file runs on every boot via
-- applyInitSql(), so a second run must be a no-op.

-- 1. One-time car interval/sort refresh — guarded by the absence of the
--    vehicle_class column so admin edits after this migration are never
--    overwritten on later boots.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'maintenance_catalog' AND column_name = 'vehicle_class'
  ) THEN
    UPDATE maintenance_catalog SET interval_days = 365,  interval_distance = 15000,  sort_order = 1  WHERE catalog_key = 'oil_change';
    UPDATE maintenance_catalog SET interval_days = 365,  interval_distance = 24000,  sort_order = 2  WHERE catalog_key = 'air_filter_cabin';
    UPDATE maintenance_catalog SET interval_days = 1825, interval_distance = 80000,  sort_order = 3  WHERE catalog_key = 'new_tires';
    UPDATE maintenance_catalog SET interval_days = NULL, interval_distance = 100000, sort_order = 4  WHERE catalog_key = 'brake_change';
    UPDATE maintenance_catalog SET interval_days = 730,  interval_distance = 50000,  sort_order = 5  WHERE catalog_key = 'brake_fluid';
    UPDATE maintenance_catalog SET interval_days = 365,  interval_distance = 10000,  sort_order = 6  WHERE catalog_key = 'rotate_tires';
    UPDATE maintenance_catalog SET interval_days = NULL, interval_distance = 40000,  sort_order = 7  WHERE catalog_key = 'fuel_filter';
    UPDATE maintenance_catalog SET interval_days = 14,   interval_distance = NULL,    sort_order = 8  WHERE catalog_key = 'wash';
    UPDATE maintenance_catalog SET interval_days = 1095, interval_distance = 60000,  sort_order = 9  WHERE catalog_key = 'battery';
    UPDATE maintenance_catalog SET interval_days = 365,  interval_distance = NULL,    sort_order = 10 WHERE catalog_key = 'air_conditioning';
    UPDATE maintenance_catalog SET interval_days = 1825, interval_distance = 120000, sort_order = 11 WHERE catalog_key = 'belts';
  END IF;
END $$;

-- 2. Columns (idempotent)
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS vehicle_class text NOT NULL DEFAULT 'car';
ALTER TABLE maintenance_catalog ADD COLUMN IF NOT EXISTS vehicle_class text NOT NULL DEFAULT 'car';
ALTER TABLE maintenance_catalog ADD COLUMN IF NOT EXISTS lifecycle_template text;
ALTER TABLE maintenance_catalog ADD COLUMN IF NOT EXISTS org_id uuid REFERENCES organizations(id) ON DELETE cascade;
CREATE INDEX IF NOT EXISTS maintenance_catalog_class_idx ON maintenance_catalog(vehicle_class);
CREATE INDEX IF NOT EXISTS maintenance_catalog_org_idx ON maintenance_catalog(org_id);
ALTER TABLE organization_vehicles ADD COLUMN IF NOT EXISTS maintenance_template_id uuid REFERENCES maintenance_catalog(id) ON DELETE set null;

-- 3. Motorcycle defaults (org_id NULL, lifecycle_template NULL)
INSERT INTO maintenance_catalog (id, catalog_key, name, interval_days, interval_distance, fuel_types, vehicle_class, sort_order, enabled) VALUES
  ('b1000000-0000-0000-0000-000000000001', 'motorcycle_engine_oil_change',   'Engine Oil Change',       180,  5000,  ARRAY['petrol'],                                'motorcycle', 1,  true),
  ('b1000000-0000-0000-0000-000000000002', 'motorcycle_chain_clean_lube',    'Chain Clean & Lube',      30,   1000,  ARRAY['petrol','electric'],                     'motorcycle', 2,  true),
  ('b1000000-0000-0000-0000-000000000003', 'motorcycle_air_filter',          'Air Filter',              365,  10000, ARRAY['petrol'],                                'motorcycle', 3,  true),
  ('b1000000-0000-0000-0000-000000000004', 'motorcycle_tyre_replacement',    'Tyre Replacement',        1095, 20000, ARRAY['petrol','electric','hybrid_plugin'],     'motorcycle', 4,  true),
  ('b1000000-0000-0000-0000-000000000005', 'motorcycle_brake_pads',          'Brake Pads',              NULL, 20000, ARRAY['petrol','electric','hybrid_plugin'],     'motorcycle', 5,  true),
  ('b1000000-0000-0000-0000-000000000006', 'motorcycle_brake_fluid',         'Brake Fluid',             730,  NULL,  ARRAY['petrol','electric','hybrid_plugin'],     'motorcycle', 6,  true),
  ('b1000000-0000-0000-0000-000000000007', 'motorcycle_coolant',             'Coolant',                 730,  20000, ARRAY['petrol','hybrid_plugin'],                'motorcycle', 7,  true),
  ('b1000000-0000-0000-0000-000000000008', 'motorcycle_valve_clearance',     'Valve Clearance Check',   NULL, 8000,  ARRAY['petrol'],                                'motorcycle', 8,  true),
  ('b1000000-0000-0000-0000-000000000009', 'motorcycle_battery',             'Battery',                 1095, 30000, ARRAY['petrol','electric','hybrid_plugin'],     'motorcycle', 9,  true),
  ('b1000000-0000-0000-0000-000000000010', 'motorcycle_wash',                'Wash',                    14,   NULL,  ARRAY['petrol','electric','hybrid_plugin'],     'motorcycle', 10, true)
ON CONFLICT (catalog_key) DO NOTHING;

-- 4. Truck defaults (fuel: petrol, hybrid_plugin — no diesel in the enum yet)
INSERT INTO maintenance_catalog (id, catalog_key, name, interval_days, interval_distance, fuel_types, vehicle_class, sort_order, enabled) VALUES
  ('c1000000-0000-0000-0000-000000000001', 'truck_engine_oil_filter',        'Engine Oil + Oil Filter',  180,  10000, ARRAY['petrol','hybrid_plugin'], 'truck', 1,  true),
  ('c1000000-0000-0000-0000-000000000002', 'truck_fuel_filter',              'Fuel Filter',              NULL, 20000, ARRAY['petrol','hybrid_plugin'], 'truck', 2,  true),
  ('c1000000-0000-0000-0000-000000000003', 'truck_air_filter',               'Air Filter',               365,  30000, ARRAY['petrol','hybrid_plugin'], 'truck', 3,  true),
  ('c1000000-0000-0000-0000-000000000004', 'truck_brake_adjustment',         'Brake Adjustment (drums)', NULL, 30000, ARRAY['petrol','hybrid_plugin'], 'truck', 4,  true),
  ('c1000000-0000-0000-0000-000000000005', 'truck_brake_fluid',              'Brake Fluid',              1095, NULL,  ARRAY['petrol','hybrid_plugin'], 'truck', 5,  true),
  ('c1000000-0000-0000-0000-000000000006', 'truck_transmission_oil',         'Transmission Oil',         730,  40000, ARRAY['petrol','hybrid_plugin'], 'truck', 6,  true),
  ('c1000000-0000-0000-0000-000000000007', 'truck_differential_oil',         'Differential Oil',         730,  40000, ARRAY['petrol','hybrid_plugin'], 'truck', 7,  true),
  ('c1000000-0000-0000-0000-000000000008', 'truck_clutch_service',           'Clutch Service',           NULL, 80000, ARRAY['petrol','hybrid_plugin'], 'truck', 8,  true),
  ('c1000000-0000-0000-0000-000000000009', 'truck_tyre_replacement',         'Tyre Replacement',         1825, 80000, ARRAY['petrol','hybrid_plugin'], 'truck', 9,  true),
  ('c1000000-0000-0000-0000-000000000010', 'truck_rotate_tyres',             'Rotate Tyres',             NULL, 10000, ARRAY['petrol','hybrid_plugin'], 'truck', 10, true),
  ('c1000000-0000-0000-0000-000000000011', 'truck_belts',                    'Belts',                    1825, 60000, ARRAY['petrol','hybrid_plugin'], 'truck', 11, true),
  ('c1000000-0000-0000-0000-000000000012', 'truck_suspension_shocks',        'Suspension / Shocks',      NULL, 60000, ARRAY['petrol','hybrid_plugin'], 'truck', 12, true),
  ('c1000000-0000-0000-0000-000000000013', 'truck_battery',                  'Battery',                  1095, NULL,  ARRAY['petrol','hybrid_plugin'], 'truck', 13, true),
  ('c1000000-0000-0000-0000-000000000014', 'truck_wash',                     'Wash',                     14,   NULL,  ARRAY['petrol','hybrid_plugin'], 'truck', 14, true)
ON CONFLICT (catalog_key) DO NOTHING;

-- 5. Van defaults (car-derived, heavier duty)
INSERT INTO maintenance_catalog (id, catalog_key, name, interval_days, interval_distance, fuel_types, vehicle_class, sort_order, enabled) VALUES
  ('d1000000-0000-0000-0000-000000000001', 'van_engine_oil_change',          'Engine Oil Change',      365,  10000, ARRAY['petrol','hybrid_plugin'],            'van', 1,  true),
  ('d1000000-0000-0000-0000-000000000002', 'van_engine_air_filter',          'Engine Air Filter',      365,  20000, ARRAY['petrol','hybrid_plugin'],            'van', 2,  true),
  ('d1000000-0000-0000-0000-000000000003', 'van_cabin_air_filter',           'Cabin Air Filter',       365,  20000, ARRAY['petrol','electric','hybrid_plugin'], 'van', 3,  true),
  ('d1000000-0000-0000-0000-000000000004', 'van_tyre_replacement',           'Tyre Replacement',       1825, 60000, ARRAY['petrol','electric','hybrid_plugin'], 'van', 4,  true),
  ('d1000000-0000-0000-0000-000000000005', 'van_rotate_tyres',               'Rotate Tyres',           NULL, 10000, ARRAY['petrol','electric','hybrid_plugin'], 'van', 5,  true),
  ('d1000000-0000-0000-0000-000000000006', 'van_brake_change',               'Brake Change',           NULL, 50000, ARRAY['petrol','electric','hybrid_plugin'], 'van', 6,  true),
  ('d1000000-0000-0000-0000-000000000007', 'van_brake_fluid',                'Brake Fluid',            1095, NULL,  ARRAY['petrol','electric','hybrid_plugin'], 'van', 7,  true),
  ('d1000000-0000-0000-0000-000000000008', 'van_battery',                    'Battery',                1095, NULL,  ARRAY['petrol','electric','hybrid_plugin'], 'van', 8,  true),
  ('d1000000-0000-0000-0000-000000000009', 'van_transmission_fluid',         'Transmission Fluid',     730,  60000, ARRAY['petrol','electric','hybrid_plugin'], 'van', 9,  true),
  ('d1000000-0000-0000-0000-000000000010', 'van_coolant',                    'Coolant',                730,  NULL,  ARRAY['petrol','hybrid_plugin'],            'van', 10, true),
  ('d1000000-0000-0000-0000-000000000011', 'van_air_conditioning',           'Air Conditioning',       365,  NULL,  ARRAY['petrol','electric','hybrid_plugin'], 'van', 11, true),
  ('d1000000-0000-0000-0000-000000000012', 'van_wash',                       'Wash',                   14,   NULL,  ARRAY['petrol','electric','hybrid_plugin'], 'van', 12, true)
ON CONFLICT (catalog_key) DO NOTHING;
