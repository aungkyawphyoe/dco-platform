-- Convert maintenance_catalog interval_distance from miles to km
UPDATE maintenance_catalog SET interval_distance = 24140  WHERE catalog_key = 'oil_change';
UPDATE maintenance_catalog SET interval_distance = 24140  WHERE catalog_key = 'air_filter_cabin';
UPDATE maintenance_catalog SET interval_distance = 80467  WHERE catalog_key = 'new_tires';
UPDATE maintenance_catalog SET interval_distance = 48280  WHERE catalog_key = 'brake_change';
UPDATE maintenance_catalog SET interval_distance = 48280  WHERE catalog_key = 'brake_fluid';
UPDATE maintenance_catalog SET interval_distance = 128747 WHERE catalog_key = 'belts';
UPDATE maintenance_catalog SET interval_distance = 48280  WHERE catalog_key = 'fuel_filter';
UPDATE maintenance_catalog SET interval_distance = 57936  WHERE catalog_key = 'battery';
UPDATE maintenance_catalog SET interval_distance = 9656   WHERE catalog_key = 'rotate_tires';
