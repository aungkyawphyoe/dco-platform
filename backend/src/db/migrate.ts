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

export async function applyInitSql(exec: (sql: string) => Promise<unknown>): Promise<void> {
  await exec(initSql());
  await exec(maintenanceCatalogSql());
  await exec(maintenanceCatalogKmSql());
  await exec(fleetFoundationSql());
  await exec(fuelLogOdometerSql());
  await exec(documentExpiresOnSql());
  await exec(familyVehicleGrantsSql());
}
