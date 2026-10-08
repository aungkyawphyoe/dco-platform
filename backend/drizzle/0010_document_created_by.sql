-- Migration 0010: Add created_by to documents table

ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES users(id);

-- Backfill existing documents with the vehicle owner
UPDATE documents d
SET created_by = v.user_id
FROM vehicles v
WHERE d.vehicle_id = v.id
  AND d.created_by IS NULL;

-- Index for querying documents by creator
CREATE INDEX IF NOT EXISTS idx_documents_created_by ON documents(created_by);