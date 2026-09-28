import { existsSync, readFileSync } from "node:fs";
import { and, eq, ne } from "drizzle-orm";
import { loadEnv } from "../config/env.js";
import { createPgDb } from "../db/client.js";
import { organizationMembers, organizations, users } from "../db/schema.js";
import { hashPassword, newId } from "../lib/crypto.js";

/**
 * Seed a local test account with full Fleet access — an active Enterprise
 * organization plus a member user, without relying on invitation emails
 * (MAIL_PROVIDER=stdout only prints them to the server log).
 *
 *   npm run seed:org
 *   npm run seed:org -- --email driver@example.com --role org_driver --name "Acme Motors"
 *   npm run seed:org -- --reset            # reset the password on an existing account
 */

function loadLocalEnv() {
  if (!existsSync(".env")) return;
  for (const line of readFileSync(".env", "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const idx = trimmed.indexOf("=");
    if (idx < 0) continue;
    const key = trimmed.slice(0, idx);
    const value = trimmed.slice(idx + 1);
    if (process.env[key] === undefined) process.env[key] = value;
  }
}

function parseArgs(argv: string[]): Record<string, string> {
  const args: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
    const next = argv[i + 1];
    if (next !== undefined && !next.startsWith("--")) {
      args[key] = next;
      i++;
    } else {
      args[key] = "true";
    }
  }
  return args;
}

const ORG_TYPES = ["showroom", "dealership", "taxi_fleet", "rental", "commercial", "logistics"] as const;
const ORG_ROLES = ["org_admin", "org_manager", "org_mechanic", "org_driver"] as const;

async function main() {
  loadLocalEnv();
  const env = loadEnv();
  const args = parseArgs(process.argv.slice(2));

  const email = (args.email ?? "orgadmin@example.com").toLowerCase();
  const password = args.password ?? "OrgAdmin123!";
  const orgName = args.name ?? "Acme Motors";
  const orgType = (args.type ?? "showroom") as (typeof ORG_TYPES)[number];
  const role = (args.role ?? "org_admin") as (typeof ORG_ROLES)[number];
  const reset = args.reset === "true";

  if (!ORG_TYPES.includes(orgType)) {
    console.error(`Invalid --type "${orgType}". Use one of: ${ORG_TYPES.join(", ")}`);
    process.exit(1);
  }
  if (!ORG_ROLES.includes(role)) {
    console.error(`Invalid --role "${role}". Use one of: ${ORG_ROLES.join(", ")}`);
    process.exit(1);
  }

  const { db, pool } = await createPgDb(env.DATABASE_URL);
  try {
    // ── Account ──
    const [bootstrapAdmin] = await db
      .select()
      .from(users)
      .where(eq(users.email, (env.BOOTSTRAP_ADMIN_EMAIL ?? "").toLowerCase()))
      .limit(1);

    let [account] = await db.select().from(users).where(eq(users.email, email)).limit(1);
    if (account) {
      if (reset) {
        [account] = await db
          .update(users)
          .set({
            passwordHash: await hashPassword(password),
            status: "active",
            emailVerified: true,
          })
          .where(eq(users.id, account.id))
          .returning();
        console.log(`[seed-org] password reset for existing account ${email}`);
      } else if (account.status !== "active" || !account.emailVerified) {
        [account] = await db
          .update(users)
          .set({ status: "active", emailVerified: true })
          .where(eq(users.id, account.id))
          .returning();
        console.log(`[seed-org] account ${email} reactivated and marked verified`);
      } else {
        console.log(`[seed-org] account ${email} already exists (use --reset to reset the password)`);
      }
      if (account.role !== "owner") {
        console.error(`[seed-org] ${email} has role "${account.role}" — needs an owner account.`);
        process.exit(1);
      }
    } else {
      [account] = await db
        .insert(users)
        .values({
          id: newId(),
          email,
          passwordHash: await hashPassword(password),
          displayName: args.display_name ?? "Test Org Admin",
          role: "owner",
          plan: "free",
          status: "active",
          emailVerified: true,
        })
        .returning();
      console.log(`[seed-org] created owner account ${email}`);
    }

    // ── Membership (one organization per user is enforced by the schema) ──
    const [existingMembership] = await db
      .select({ membership: organizationMembers, organization: organizations })
      .from(organizationMembers)
      .innerJoin(organizations, eq(organizationMembers.orgId, organizations.id))
      .where(eq(organizationMembers.userId, account.id))
      .limit(1);

    let organization = existingMembership?.organization ?? null;
    let membership = existingMembership?.membership ?? null;

    if (organization && organization.status === "archived") {
      console.error(
        `[seed-org] ${email} belongs to archived organization ${organization.id}; archived memberships cannot be reused.`,
      );
      process.exit(1);
    }

    if (!organization) {
      // Join the named organization when it already exists (multi-account seed), else create it.
      const [named] = await db
        .select()
        .from(organizations)
        .where(and(eq(organizations.name, orgName), ne(organizations.status, "archived")))
        .limit(1);
      organization = named ?? null;
    }

    if (!organization) {
      const [created] = await db
        .insert(organizations)
        .values({
          id: newId(),
          name: orgName,
          type: orgType,
          plan: "enterprise",
          status: "active",
          adminUserId: account.id,
          createdBy: bootstrapAdmin?.id ?? account.id,
          activatedBy: bootstrapAdmin?.id ?? null,
          activatedAt: new Date(),
          contactEmail: email,
        })
        .returning();
      organization = created;
      console.log(`[seed-org] created active Enterprise organization "${organization.name}" (${organization.id})`);
    } else {
      if (organization.status !== "active") {
        [organization] = await db
          .update(organizations)
          .set({ status: "active", activatedAt: new Date(), activatedBy: bootstrapAdmin?.id ?? null })
          .where(eq(organizations.id, organization.id))
          .returning();
        console.log(`[seed-org] organization "${organization.name}" reactivated (${organization.id})`);
      } else {
        console.log(`[seed-org] reusing active organization "${organization.name}" (${organization.id})`);
      }
    }

    if (!membership) {
      [membership] = await db
        .insert(organizationMembers)
        .values({
          id: newId(),
          orgId: organization.id,
          userId: account.id,
          role,
          invitedBy: bootstrapAdmin?.id ?? null,
        })
        .returning();
      console.log(`[seed-org] added ${email} as ${role}`);
    } else if (membership.role !== role) {
      if (args.force_role === "true") {
        const previousRole = membership.role;
        [membership] = await db
          .update(organizationMembers)
          .set({ role })
          .where(eq(organizationMembers.id, membership.id))
          .returning();
        console.log(`[seed-org] changed ${email} role ${previousRole} → ${role}`);
      } else {
        console.log(
          `[seed-org] ${email} is already ${membership.role} in this organization (use --force-role to change it)`,
        );
      }
    }

    const activeOrgs = await db
      .select()
      .from(organizations)
      .where(and(eq(organizations.adminUserId, account.id), ne(organizations.status, "archived")));

    console.log(`
[seed-org] done
  Account:   ${email}
  Password:  ${password}
  Plan:      ${account.plan} (owner)
  Org:       ${organization.name} (${organization.id})
  Type:      ${organization.type} · plan ${organization.plan} · status ${organization.status}
  Role:      ${membership?.role}
  Org admin organizations: ${activeOrgs.length}

  Sign in on mobile (or web) with these credentials — Fleet entry is
  entitled immediately; no invitation email is needed.
  (MAIL_PROVIDER=stdout: invitation emails print to the API server log only.)`);
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  console.error("[seed-org] failed:", error);
  process.exit(1);
});
