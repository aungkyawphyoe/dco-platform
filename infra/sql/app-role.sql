-- Runtime application role for the API.
--
-- The API only performs DML. Schema changes are applied out of band by the
-- migration runner using the administrator credential, so this role must not
-- hold DDL rights: no CREATE, no ALTER, no TRUNCATE, no TRIGGER, no REFERENCES.
--
-- Usage (run as the administrator, with the password supplied out of band):
--   psql "$ADMIN_DATABASE_URL" -v app_password="$DCO_APP_PASSWORD" -f infra/sql/app-role.sql
--
-- Re-running is safe: the role is created once, the password is reset, and
-- grants are additive. Default privileges keep future tables reachable because
-- migrations always run as dcoadmin.

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dco_app') THEN
    CREATE ROLE dco_app;
  END IF;
END $$;

ALTER ROLE dco_app WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS
  PASSWORD :'app_password';

DO $$
BEGIN
  EXECUTE format('GRANT CONNECT ON DATABASE %I TO dco_app', current_database());
END $$;

REVOKE ALL ON SCHEMA public FROM dco_app;
GRANT USAGE ON SCHEMA public TO dco_app;

-- DML only. Triggers run as the invoking user, so this also covers the tables
-- written indirectly: analytics_records, analytics_tenures, change_log,
-- audit_events, vehicle_ownership_periods, ownership_migration_reviews.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO dco_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO dco_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO dco_app;

-- Tables created later by the migration runner (as dcoadmin) must stay usable.
ALTER DEFAULT PRIVILEGES FOR ROLE dcoadmin IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dco_app;
ALTER DEFAULT PRIVILEGES FOR ROLE dcoadmin IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO dco_app;
ALTER DEFAULT PRIVILEGES FOR ROLE dcoadmin IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO dco_app;
