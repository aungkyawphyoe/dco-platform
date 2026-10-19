-- Organization service/fuel costs have exactly one accounting entry.
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS source_kind text;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS source_id uuid;
CREATE UNIQUE INDEX IF NOT EXISTS expenses_source_unique ON expenses(source_kind, source_id) WHERE source_id IS NOT NULL;
