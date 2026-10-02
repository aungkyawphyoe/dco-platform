import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import { sql } from "drizzle-orm";
import bcrypt from "bcryptjs";

const pool = new Pool({
  connectionString: "postgres://dcoadmin:yTa5xvFwbmouzvF5HKgpp0xBr2rL8G@dco-pg-24739.postgres.database.azure.com:5432/dco?sslmode=require",
  ssl: { rejectUnauthorized: false },
});

const db = drizzle(pool);

async function main() {
  console.log("Connecting to database...");
  
  // Delete all user-related data in correct order (respecting FK constraints)
  console.log("Deleting user-related data...");
  
  // Tables that reference users but don't have cascade delete
  await db.execute(sql`DELETE FROM fleet_assignments`);
  await db.execute(sql`DELETE FROM work_orders`);
  await db.execute(sql`DELETE FROM inspections`);
  await db.execute(sql`DELETE FROM warranty_templates`);
  await db.execute(sql`DELETE FROM fuel_logs`);
  await db.execute(sql`DELETE FROM shift_mileage`);
  await db.execute(sql`DELETE FROM vehicle_assignments`);
  await db.execute(sql`DELETE FROM organization_members`);
  await db.execute(sql`DELETE FROM organizations`);
  await db.execute(sql`DELETE FROM family_vehicle_grants`);
  await db.execute(sql`DELETE FROM family_members`);
  await db.execute(sql`DELETE FROM families`);
  await db.execute(sql`DELETE FROM sync_changes`);
  await db.execute(sql`DELETE FROM notifications`);
  await db.execute(sql`DELETE FROM plan_items`);
  await db.execute(sql`DELETE FROM service_records`);
  await db.execute(sql`DELETE FROM documents`);
  await db.execute(sql`DELETE FROM expenses`);
  await db.execute(sql`DELETE FROM vehicles`);
  await db.execute(sql`DELETE FROM users`);

  console.log("All user data deleted. Creating new users...");

  // Create 2 customer users (role: owner)
  const passwordHash = await bcrypt.hash("password123", 10);
  
  // User 1
  await db.execute(sql`
    INSERT INTO users (id, email, username, password_hash, display_name, role, plan, status, email_verified)
    VALUES (gen_random_uuid(), 'customer1@example.com', 'customer1', ${passwordHash}, 'Customer One', 'owner', 'premium', 'active', true)
  `);
  
  // User 2
  await db.execute(sql`
    INSERT INTO users (id, email, username, password_hash, display_name, role, plan, status, email_verified)
    VALUES (gen_random_uuid(), 'customer2@example.com', 'customer2', ${passwordHash}, 'Customer Two', 'owner', 'free', 'active', true)
  `);

  // User 3 - fleet portal user (role: owner, but will be used for fleet)
  await db.execute(sql`
    INSERT INTO users (id, email, username, password_hash, display_name, role, plan, status, email_verified)
    VALUES (gen_random_uuid(), 'fleet@example.com', 'fleetuser', ${passwordHash}, 'Fleet User', 'owner', 'premium', 'active', true)
  `);

  console.log("Created 3 new users:");
  console.log("  1. customer1@example.com / password123 (premium)");
  console.log("  2. customer2@example.com / password123 (free)");
  console.log("  3. fleet@example.com / password123 (premium - for fleet portal)");

  await pool.end();
  console.log("Done!");
}

main().catch(console.error);
