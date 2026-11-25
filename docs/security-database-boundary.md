# Database boundary remediation

Status: **stage 1 of 3 complete.** Stages 2 and 3 are deliberately deferred; they are platform migrations, not configuration changes.

## Findings

| Finding | Severity | Status |
|---|---|---|
| API connected with the PostgreSQL administrator credential | High | **Fixed** |
| API credential could issue DDL, `TRUNCATE`, and bypass RLS | High | **Fixed** |
| `AllowAzureServices` (`0.0.0.0/0`) firewall rule | Medium | Deferred (stage 3) |
| PostgreSQL publicly reachable | Medium | Deferred (stage 3) |
| TLS uses `sslmode=require` (encrypts, does not verify the server certificate) | Low | Deferred |

## Stage 1 — what changed (25 November 2026)

1. **Runtime role `dco_app`.** `LOGIN`, no `SUPERUSER`, `CREATEDB`, `CREATEROLE`, `REPLICATION` or `BYPASSRLS`. Grants: `SELECT, INSERT, UPDATE, DELETE` on all 77 tables, `USAGE/SELECT` on sequences, `EXECUTE` on functions, `USAGE` on schema `public`. No `CREATE`, no `TRUNCATE`, no `TRIGGER`, no `REFERENCES`. Definition: [`infra/sql/app-role.sql`](../infra/sql/app-role.sql).
2. **Migrations moved out of the boot path.** `DB_MIGRATE_ON_START=off` in production. The API now calls `connectPgDb` instead of `createPgDb`, so it never issues DDL. Migrations run out of band with the administrator credential (`npm run db:migrate:compiled`).
3. **Secret swap.** `DATABASE_URL` points at `database-url-app` (`dco_app`). `database-url` (`dcoadmin`) is retained for migrations only.
4. **Default privileges.** `ALTER DEFAULT PRIVILEGES FOR ROLE dcoadmin` keeps tables created by future migrations reachable by `dco_app`.

### Verified

- `dco_app`: DML works (`SELECT`/`INSERT`), `ALTER TABLE` fails with `must be owner of table users`, `TRUNCATE` fails with `permission denied`.
- All 77 tables carry full DML for `dco_app`, including tables written indirectly by triggers (`analytics_records`, `analytics_tenures`, `change_log`, `audit_events`, `vehicle_ownership_periods`, `ownership_migration_reviews`).
- No table uses row-level security, so `NOBYPASSRLS` changes no behaviour.
- API connects as `dco_app`; `/v1/ready`, `/v1/health`, `/v1/pricing`, admin and Fleet Portal logins all return success.

### Residual risk after stage 1

- A compromised API credential can read and write **all** application data. It cannot alter schema, truncate tables, create roles, or bypass RLS. Blast radius is data, not the server.
- The administrator credential still exists in the Container App secrets (`database-url`) and is still usable by anyone with `Microsoft.App/containerApps/secrets/read` on the resource group.
- `AllowAzureServices` still lets any Azure-hosted source attempt a connection. Credentials are the only control.
- A Bicep redeploy resets `DATABASE_URL` to `database-url` (admin) and re-creates the `AllowAzureServices` rule. `DB_MIGRATE_ON_START=off` prevents a crash, but the role boundary would silently revert. Re-apply the stage-1 secret swap after any infrastructure deployment until stage 3 lands.

## Stage 2 — private connectivity (deferred)

**Why deferred:** `dco-env-24739` is a Consumption-only Container Apps environment with no `vnetConfiguration` and no static egress IP. VNet injection is fixed at environment creation, so private reachability requires a **new Workload Profiles environment**, recreating all four apps (api, admin-web, fleet-portal, site) and re-binding four custom domains plus managed certificates. That is a scheduled migration with a real outage window, not a firewall edit.

**Work:**

1. Create a VNet with two subnets: Container Apps infrastructure and a delegated PostgreSQL subnet.
2. Create a Workload Profiles environment with VNet injection; move the four apps across.
3. Add a private DNS zone (`privatelink.postgres.database.azure.com`) and a private endpoint for `dco-pg-24739`.
4. Recreate Container Apps jobs (if any), custom domains, and certificates on the new environment.
5. Verify the API resolves the server to a private IP while public access is still enabled.

**Rollback:** keep the old environment running until the new one serves traffic; DNS/custom-domain switch is the cutover point.

## Stage 3 — close public access (deferred, depends on stage 2)

**Work:**

1. Set `network.publicNetworkAccess = "Disabled"` on the PostgreSQL server.
2. Delete the `AllowAzureServices` firewall rule and the stale developer IP rule.
3. Remove the `postgresFirewall` resource from `infra/app.bicep`.
4. Provide an in-VNet path for migrations and `psql` (Container Apps job or Azure Bastion jumpbox), since local access disappears.

**Risk:** point of no return for direct local database access. Re-enabling public access and re-adding a rule is manual and takes minutes. Do it in a window with a written rollback.

## Other deferred items

| Item | Why | Notes |
|---|---|---|
| TLS `verify-full` | `require` encrypts but accepts any certificate | One-line connection-string change; validate with the current CA chain first |
| Separate migration role | `dcoadmin` owns every table, so it keeps implicit full rights | Would need ownership transfer or a dedicated owner role; higher risk than stage 1 |
| Automated migration job | Today migrations are a documented manual step | Container Apps job using `database-url`; removes the "forgot to migrate" failure mode |
| Alert on admin connections | Detection, not prevention | Log Analytics alert when `pg_stat_activity.usename = 'dcoadmin'` outside the migration job |
| Secret rotation runbook | `database-url-app` has no rotation process | Rotate by re-running `app-role.sql` with a new password, then updating the secret and revision |
| Bicep alignment | IaC still provisions the admin URL and the Azure-wide rule | Fold into stage 2 so a redeploy cannot revert the boundary |
