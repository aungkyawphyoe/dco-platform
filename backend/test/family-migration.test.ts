import { PGlite } from "@electric-sql/pglite";
import { describe, expect, test } from "vitest";
import {
  documentExpiresOnSql,
  fleetFoundationSql,
  fuelLogOdometerSql,
  initSql,
  maintenanceCatalogKmSql,
  maintenanceCatalogSql,
  familyVehicleGrantsSql,
  usersUsernameSql,
  vehicleSharingSql,
} from "../src/db/migrate.js";

const BEFORE_SHARING = [
  initSql(),
  maintenanceCatalogSql(),
  maintenanceCatalogKmSql(),
  fleetFoundationSql(),
  fuelLogOdometerSql(),
  documentExpiresOnSql(),
  familyVehicleGrantsSql(),
  usersUsernameSql(),
];

async function legacyDb(): Promise<PGlite> {
  const client = new PGlite();
  for (const sql of BEFORE_SHARING) await client.exec(sql);
  return client;
}

function uuid(): string {
  return crypto.randomUUID();
}

describe("family → vehicle share conversion", () => {
  test("family members and drivers become active shares with preserved access", async () => {
    const client = await legacyDb();

    const ownerId = uuid();
    const memberId = uuid();
    const driverId = uuid();
    const familyId = uuid();
    const familyVehicleId = uuid();
    const grantVehicleId = uuid();
    const otherMemberId = uuid();

    await client.query(
      `INSERT INTO users (id, email, username, password_hash, role, plan)
       VALUES ($1, 'owner@test.local', 'owner', 'x', 'owner', 'premium'),
              ($2, 'member@test.local', 'member', 'x', 'owner', 'free'),
              ($3, 'driver@test.local', 'driver', 'x', 'owner', 'free'),
              ($4, 'other@test.local', 'other', 'x', 'owner', 'free')`,
      [ownerId, memberId, driverId, otherMemberId],
    );

    await client.query(
      `INSERT INTO vehicles (id, user_id, name, make, model, year, license_plate, fuel_type, mileage)
       VALUES ($1, $2, 'Hilux', 'Toyota', 'Hilux', 2021, 'ABC-123', 'petrol', 1000),
              ($3, $2, 'Corolla', 'Toyota', 'Corolla', 2019, 'XYZ-789', 'petrol', 5000)`,
      [familyVehicleId, ownerId, grantVehicleId],
    );

    await client.query(
      `INSERT INTO families (id, name, share_code, created_by) VALUES ($1, 'The U Family', 'FAMCODE1', $2)`,
      [familyId, ownerId],
    );
    await client.query(
      `INSERT INTO family_memberships (id, family_id, user_id, role, joined_at)
       VALUES ($1, $2, $3, 'primary_owner', now() - interval '90 days'),
              ($4, $2, $5, 'member', now() - interval '60 days'),
              ($6, $2, $7, 'driver', now() - interval '30 days')`,
      [uuid(), familyId, ownerId, uuid(), memberId, uuid(), driverId],
    );
    await client.query(
      `INSERT INTO family_vehicles (id, family_id, vehicle_id, added_by, added_at)
       VALUES ($1, $2, $3, $4, now() - interval '80 days')`,
      [uuid(), familyId, familyVehicleId, ownerId],
    );
    await client.query(
      `INSERT INTO vehicle_grants (id, vehicle_id, user_id, granted_by, permission)
       VALUES ($1, $2, $3, $4, 'full')`,
      [uuid(), grantVehicleId, otherMemberId, ownerId],
    );

    await client.exec(vehicleSharingSql());

    const shares = await client.query<{
      vehicle_id: string;
      user_id: string;
      access_level: string;
      status: string;
      accepted_at: Date | null;
    }>(
      `SELECT vehicle_id, user_id, access_level, status, accepted_at FROM vehicle_shares ORDER BY user_id`,
    );

    const byUser = new Map(shares.rows.map((row) => [row.user_id, row]));
    expect(byUser.size).toBe(3);

    const member = byUser.get(memberId)!;
    expect(member.vehicle_id).toBe(familyVehicleId);
    expect(member.access_level).toBe("add_edit_own");
    expect(member.status).toBe("active");
    expect(member.accepted_at).not.toBeNull();

    const driver = byUser.get(driverId)!;
    expect(driver.access_level).toBe("view");
    expect(driver.status).toBe("active");

    const grant = byUser.get(otherMemberId)!;
    expect(grant.vehicle_id).toBe(grantVehicleId);
    expect(grant.access_level).toBe("add_edit_own");

    // The primary owner is the vehicle owner — they get no share row.
    expect(byUser.has(ownerId)).toBe(false);

    const leftovers = await client.query<{ table_name: string }>(
      `SELECT table_name FROM information_schema.tables
       WHERE table_name IN ('families', 'family_memberships', 'family_vehicles', 'vehicle_grants')`,
    );
    expect(leftovers.rows).toHaveLength(0);

    const familyColumn = await client.query<{ column_name: string }>(
      `SELECT column_name FROM information_schema.columns
       WHERE table_name = 'users' AND column_name = 'family_id'`,
    );
    expect(familyColumn.rows).toHaveLength(0);

    const refreshFamily = await client.query<{ is_nullable: string }>(
      `SELECT is_nullable FROM information_schema.columns
       WHERE table_name = 'refresh_tokens' AND column_name = 'family_id'`,
    );
    expect(refreshFamily.rows[0].is_nullable).toBe("YES");

    await client.close();
  });
});
