import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

function readSql(filename: string): string {
  return readFileSync(join(here, `../../drizzle/${filename}`), "utf8");
}

export function initSql(): string {
  return readSql("0000_init.sql");
}

export function maintenanceCatalogSql(): string {
  return readSql("0001_maintenance_catalog.sql");
}

export function maintenanceCatalogKmSql(): string {
  return readSql("0002_maintenance_catalog_km.sql");
}

export function fleetFoundationSql(): string {
  return readSql("0003_fleet_foundation.sql");
}

export function fuelLogOdometerSql(): string {
  return readSql("0004_fuel_log_odometer.sql");
}

export function documentExpiresOnSql(): string {
  return readSql("0005_document_expires_on.sql");
}

export function familyVehicleGrantsSql(): string {
  return readSql("0006_family_vehicle_grants.sql");
}

export function usersUsernameSql(): string {
  return readSql("0007_users_username.sql");
}

export function vehicleSharingSql(): string {
  return readSql("0008_vehicle_sharing.sql");
}

export function auditTrailSql(): string {
  return readSql("0009_audit_trail.sql");
}

export function documentCreatedBySql(): string {
  return readSql("0010_document_created_by.sql");
}

export function planTiersSql(): string {
  return readSql("0011_plan_tiers.sql");
}

export function authOnboardingSql(): string {
  return readSql("0012_auth_onboarding.sql");
}

export function maintenanceCatalogFleetSql(): string {
  return readSql("0013_maintenance_catalog_fleet.sql");
}

export function driverSurfaceRealignmentSql(): string {
  return readSql("0014_driver_surface_realignment.sql");
}

export async function applyInitSql(exec: (sql: string) => Promise<unknown>): Promise<void> {
  await exec(initSql());
  await exec(maintenanceCatalogSql());
  await exec(maintenanceCatalogKmSql());
  await exec(fleetFoundationSql());
  await exec(fuelLogOdometerSql());
  await exec(documentExpiresOnSql());
  await exec(familyVehicleGrantsSql());
  await exec(usersUsernameSql());
  await exec(vehicleSharingSql());
  await exec(auditTrailSql());
  await exec(documentCreatedBySql());
  await exec(planTiersSql());
  await exec(authOnboardingSql());
  await exec(maintenanceCatalogFleetSql());
  await exec(driverSurfaceRealignmentSql());
  await exec(readSql("0015_driver_shared_assignments.sql"));
  await exec(readSql("0016_record_revisions.sql"));
  await exec(readSql("0017_organization_sync.sql"));
  await exec(readSql("0018_derived_expenses.sql"));
  await exec(readSql("0019_plan_schedule_baselines.sql"));
  await exec(readSql("0020_organization_accounting.sql"));
  await exec(readSql("0021_maintenance_template_class.sql"));
  await exec(readSql("0022_fleet_analytics.sql"));
  await exec(readSql("0023_document_storage.sql"));
  await exec(readSql("0024_document_links.sql"));
  await exec(readSql("0025_license_optional_expiry.sql"));
}
