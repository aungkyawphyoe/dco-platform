-- Oct 2026 Fleet alignment, phase 1: username as second login identifier.
-- users.username (globally unique), users.must_change_password, users.email becomes nullable.

ALTER TABLE users ADD COLUMN IF NOT EXISTS username text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS must_change_password boolean NOT NULL DEFAULT false;
ALTER TABLE users ALTER COLUMN email DROP NOT NULL;

-- Backfill: username derived from the email local part (lowercased, invalid chars -> _,
-- stripped edges, min 3 chars, max 30), collisions suffixed _2, _3, ... by creation order.
DO $$
DECLARE
  u record;
  base text;
  candidate text;
  counter int;
BEGIN
  FOR u IN SELECT id, email, created_at FROM users WHERE username IS NULL AND email IS NOT NULL ORDER BY created_at, id LOOP
    base := regexp_replace(lower(split_part(u.email, '@', 1)), '[^a-z0-9._]', '_', 'g');
    base := regexp_replace(base, '^[._]+|[._]+$', '', 'g');
    IF length(base) < 3 THEN
      base := 'user';
    END IF;
    IF length(base) > 30 THEN
      base := left(base, 30);
    END IF;
    candidate := base;
    counter := 2;
    WHILE EXISTS (SELECT 1 FROM users WHERE username = candidate) LOOP
      candidate := left(base, 30 - length(counter::text) - 1) || '_' || counter;
      counter := counter + 1;
    END LOOP;
    UPDATE users SET username = candidate WHERE id = u.id;
  END LOOP;
END $$;

ALTER TABLE users ALTER COLUMN username SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = current_schema() AND indexname = 'users_username_unique_idx'
  ) THEN
    CREATE UNIQUE INDEX users_username_unique_idx ON users (username);
  END IF;
END $$;
