CREATE TABLE IF NOT EXISTS maintenance_catalog (
  id uuid PRIMARY KEY,
  catalog_key text NOT NULL UNIQUE,
  name text NOT NULL,
  interval_days integer,
  interval_distance numeric(12, 1),
  fuel_types text[] NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Seed the 11 default maintenance catalog items (interval_distance in km)
INSERT INTO maintenance_catalog (id, catalog_key, name, interval_days, interval_distance, fuel_types, sort_order, enabled) VALUES
  ('a1000000-0000-0000-0000-000000000001', 'oil_change',          'Oil Change',          365,    24140,  ARRAY['petrol','hybrid_plugin'], 1,  true),
  ('a1000000-0000-0000-0000-000000000002', 'air_filter_cabin',    'Air Filter (Cabin)',  365,    24140,  ARRAY['petrol','electric','hybrid_plugin'], 2,  true),
  ('a1000000-0000-0000-0000-000000000003', 'new_tires',           'New Tires',           1825,   80467,  ARRAY['petrol','electric','hybrid_plugin'], 3,  true),
  ('a1000000-0000-0000-0000-000000000004', 'brake_change',        'Brake Change',        NULL,   48280,  ARRAY['petrol','electric','hybrid_plugin'], 4,  true),
  ('a1000000-0000-0000-0000-000000000005', 'brake_fluid',         'Brake Fluid',         1095,   48280,  ARRAY['petrol','electric','hybrid_plugin'], 5,  true),
  ('a1000000-0000-0000-0000-000000000006', 'belts',               'Belts',               1825,   128747, ARRAY['petrol','hybrid_plugin'], 6,  true),
  ('a1000000-0000-0000-0000-000000000007', 'fuel_filter',         'Fuel Filter',         NULL,   48280,  ARRAY['petrol','hybrid_plugin'], 7,  true),
  ('a1000000-0000-0000-0000-000000000008', 'wash',                'Wash',                14,     NULL,   ARRAY['petrol','electric','hybrid_plugin'], 8,  true),
  ('a1000000-0000-0000-0000-000000000009', 'battery',             'Battery',             1095,   57936,  ARRAY['petrol','electric','hybrid_plugin'], 9,  true),
  ('a1000000-0000-0000-0000-000000000010', 'air_conditioning',    'Air Conditioning',    365,    NULL,   ARRAY['petrol','electric','hybrid_plugin'], 10, true),
  ('a1000000-0000-0000-0000-000000000011', 'rotate_tires',        'Rotate Tires',        365,    9656,   ARRAY['petrol','electric','hybrid_plugin'], 11, true)
ON CONFLICT (catalog_key) DO NOTHING;
