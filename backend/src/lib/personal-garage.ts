import { and, eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { driverAssignments, organizationMembers } from "../db/schema.js";
import { AppError } from "./errors.js";

/**
 * Server-enforced personal-garage ban (Confirmed Access Decision 22). A driver
 * identity never has personal data: while a user holds the `org_driver` role OR
 * an active driver assignment, every personal-garage route (vehicles,
 * vehicle-shares, owner service/expense/document/fuel-log routes) returns
 * 403 personal_garage_forbidden. The Garage tab itself still works read-only on
 * the client through the org/driver endpoints; only the personal surface is
 * denied here.
 */
export async function assertPersonalGarageAllowed(db: Db, userId: string) {
  const [driverMembership] = await db
    .select({ id: organizationMembers.id })
    .from(organizationMembers)
    .where(and(eq(organizationMembers.userId, userId), eq(organizationMembers.role, "org_driver")))
    .limit(1);
  if (driverMembership) {
    throw new AppError(403, "personal_garage_forbidden", "Driver accounts do not have a personal garage");
  }
  const [assignment] = await db
    .select({ id: driverAssignments.id })
    .from(driverAssignments)
    .where(and(eq(driverAssignments.driverId, userId), eq(driverAssignments.status, "active")))
    .limit(1);
  if (assignment) {
    throw new AppError(403, "personal_garage_forbidden", "Driver accounts do not have a personal garage");
  }
}
