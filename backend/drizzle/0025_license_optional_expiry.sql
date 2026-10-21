-- A license can be recorded without an expiry date. Existing dates are retained.
ALTER TABLE driving_licenses ALTER COLUMN expiry_date DROP NOT NULL;
