DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='driving_licenses' AND column_name='front_media_id') THEN
    UPDATE media_objects SET purpose='retired_license'
      WHERE id IN (SELECT front_media_id FROM driving_licenses UNION SELECT back_media_id FROM driving_licenses);
    ALTER TABLE driving_licenses DROP COLUMN front_media_id, DROP COLUMN back_media_id,
      DROP COLUMN issuing_country, DROP COLUMN categories;
    ALTER TABLE driving_licenses RENAME COLUMN expiry_date TO license_expiry_date;
    UPDATE change_log SET payload=(payload - ARRAY['front_media_id','back_media_id','issuing_country','categories','expiry_date']) ||
        jsonb_build_object('license_expiry_date',payload->'expiry_date')
      WHERE entity_type='driving_license' AND op='upsert';
  END IF;
  UPDATE media_objects SET purpose='retired_license' WHERE purpose IN ('license_front','license_back','driving_license');
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='media_objects'::regclass AND conname='no_license_image_uploads') THEN
    ALTER TABLE media_objects ADD CONSTRAINT no_license_image_uploads CHECK (purpose NOT IN ('driving_license','license_front','license_back'));
  END IF;
  INSERT INTO media_cleanup(media_id) SELECT id FROM media_objects WHERE purpose='retired_license' ON CONFLICT DO NOTHING;
END $$;
