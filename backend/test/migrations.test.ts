import { PGlite } from "@electric-sql/pglite";
import { describe, expect, test } from "vitest";
import { applyInitSql } from "../src/db/migrate.js";

describe("migrations", () => {
  test("apply cleanly twice so every boot is a no-op", async () => {
    const client = new PGlite();
    const exec = async (sql: string) => {
      await client.exec(sql);
    };

    await expect(applyInitSql(exec)).resolves.toBeUndefined();
    await expect(applyInitSql(exec)).resolves.toBeUndefined();

    // The family tables must be gone, the share tables must remain.
    const gone = await client.query<{ regclass: string | null }>(
      "SELECT to_regclass('family_memberships') AS regclass",
    );
    expect(gone.rows[0].regclass).toBeNull();

    const present = await client.query<{ regclass: string | null }>(
      "SELECT to_regclass('vehicle_shares') AS regclass",
    );
    expect(present.rows[0].regclass).not.toBeNull();

    await client.close();
  });
});
