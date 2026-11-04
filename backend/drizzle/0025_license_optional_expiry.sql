DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='driving_licenses' AND column_name='expiry_date') THEN
    ALTER TABLE driving_licenses ALTER COLUMN expiry_date DROP NOT NULL;
  END IF;
END $$;
