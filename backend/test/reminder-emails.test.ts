import { eq } from "drizzle-orm";
import { describe, expect, it } from "vitest";
import { users } from "../src/db/schema.js";
import type { MaintenanceReminderEmail, Mailer } from "../src/lib/mail.js";
import { scanReminderEmails } from "../src/lib/reminder-email.js";
import { createTestApp, uuid } from "./helpers.js";

function daysFromToday(days: number): string {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

async function ownerSession(app: { inject: Function }) {
  const email = `reminder-${uuid()}@test.local`;
  const res = await app.inject({
    method: "POST",
    url: "/v1/auth/signup",
    payload: { email, password: "password1" },
  });
  return { token: res.json().access_token as string, userId: res.json().user.id as string, email };
}

function vehiclePayload(id: string) {
  return {
    id,
    name: "Daily",
    nickname: "Blue",
    make: "Toyota",
    model: "Camry",
    year: 2020,
    license_plate: `REM${id.slice(0, 4)}`,
    fuel_type: "petrol",
    mileage: 10_000,
    mileage_unit: "km",
  };
}

function fakeMailer(calls: { to: string; reminder: MaintenanceReminderEmail }[]): Mailer {
  return {
    sendMaintenanceReminder: async (to, reminder) => {
      calls.push({ to, reminder });
    },
  } as unknown as Mailer;
}

describe("reminder email settings", () => {
  it("is opt-in and requires a verified email", async () => {
    const { app, db } = await createTestApp();
    const { token, userId } = await ownerSession(app);
    const auth = { authorization: `Bearer ${token}` };

    const initial = await app.inject({ method: "GET", url: "/v1/me/reminder-emails", headers: auth });
    expect(initial.statusCode).toBe(200);
    expect(initial.json()).toEqual({ enabled: false, lead_days: 30, available: false });

    const blocked = await app.inject({
      method: "PUT",
      url: "/v1/me/reminder-emails",
      headers: auth,
      payload: { enabled: true, lead_days: 30 },
    });
    expect(blocked.statusCode).toBe(409);
    expect(blocked.json().error.code).toBe("email_verification_required");

    await db.update(users).set({ emailVerified: true }).where(eq(users.id, userId));
    const enabled = await app.inject({
      method: "PUT",
      url: "/v1/me/reminder-emails",
      headers: auth,
      payload: { enabled: true, lead_days: 14 },
    });
    expect(enabled.statusCode).toBe(200);
    expect(enabled.json()).toEqual({ enabled: true, lead_days: 14, available: true });

    const invalid = await app.inject({
      method: "PUT",
      url: "/v1/me/reminder-emails",
      headers: auth,
      payload: { enabled: true, lead_days: 61 },
    });
    expect(invalid.statusCode).toBe(422);
    await app.close();
  });
});

describe("reminder email scan", () => {
  it("sends upcoming and due emails once per cycle and does not duplicate", async () => {
    const { app, db } = await createTestApp();
    const { token, userId, email } = await ownerSession(app);
    const auth = { authorization: `Bearer ${token}` };
    await db
      .update(users)
      .set({ emailVerified: true, emailRemindersEnabled: true, emailReminderLeadDays: 30 })
      .where(eq(users.id, userId));

    const vehicleId = uuid();
    expect((await app.inject({
      method: "POST",
      url: "/v1/vehicles",
      headers: auth,
      payload: vehiclePayload(vehicleId),
    })).statusCode).toBe(201);

    const planItemId = uuid();
    expect((await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/plan-items`,
      headers: auth,
      payload: { id: planItemId, name: "Oil change", next_due_on: daysFromToday(10) },
    })).statusCode).toBe(201);

    const calls: { to: string; reminder: MaintenanceReminderEmail }[] = [];
    const first = await scanReminderEmails({ db, mailer: fakeMailer(calls) });
    expect(first.sent).toBe(1);
    expect(calls).toHaveLength(1);
    expect(calls[0].to).toBe(email);
    expect(calls[0].reminder).toMatchObject({
      phase: "upcoming",
      vehicleName: "Blue",
      itemName: "Oil change",
      mileageUnit: "km",
    });

    const repeat = await scanReminderEmails({ db, mailer: fakeMailer(calls) });
    expect(repeat.sent).toBe(0);
    expect(repeat.skipped).toBe(1);
    expect(calls).toHaveLength(1);

    expect((await app.inject({
      method: "PATCH",
      url: `/v1/plan-items/${planItemId}`,
      headers: auth,
      payload: { next_due_on: daysFromToday(0) },
    })).statusCode).toBe(200);

    const due = await scanReminderEmails({ db, mailer: fakeMailer(calls) });
    expect(due.sent).toBe(1);
    expect(calls).toHaveLength(2);
    expect(calls[1].reminder.phase).toBe("due");

    const dueRepeat = await scanReminderEmails({ db, mailer: fakeMailer(calls) });
    expect(dueRepeat.sent).toBe(0);
    expect(calls).toHaveLength(2);
    await app.close();
  });

  it("retries a failed send after the backoff window", async () => {
    const { app, db } = await createTestApp();
    const { token, userId } = await ownerSession(app);
    const auth = { authorization: `Bearer ${token}` };
    await db
      .update(users)
      .set({ emailVerified: true, emailRemindersEnabled: true })
      .where(eq(users.id, userId));

    const vehicleId = uuid();
    await app.inject({
      method: "POST",
      url: "/v1/vehicles",
      headers: auth,
      payload: vehiclePayload(vehicleId),
    });
    await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/plan-items`,
      headers: auth,
      payload: { id: uuid(), name: "Oil change", next_due_on: daysFromToday(10) },
    });

    const start = new Date();
    const failing = {
      sendMaintenanceReminder: async () => {
        throw new Error("provider down");
      },
    } as unknown as Mailer;
    const failed = await scanReminderEmails({ db, mailer: failing, now: start });
    expect(failed.failed).toBe(1);

    const tooSoon = await scanReminderEmails({
      db,
      mailer: fakeMailer([]),
      now: new Date(start.getTime() + 30 * 60 * 1000),
    });
    expect(tooSoon.sent).toBe(0);
    expect(tooSoon.skipped).toBe(1);

    const calls: { to: string; reminder: MaintenanceReminderEmail }[] = [];
    const retried = await scanReminderEmails({
      db,
      mailer: fakeMailer(calls),
      now: new Date(start.getTime() + 61 * 60 * 1000),
    });
    expect(retried.sent).toBe(1);
    expect(calls).toHaveLength(1);
    await app.close();
  });

  it("sends a due email for a mileage target and skips archived or disabled items", async () => {
    const { app, db } = await createTestApp();
    const { token, userId } = await ownerSession(app);
    const auth = { authorization: `Bearer ${token}` };
    await db
      .update(users)
      .set({ emailVerified: true, emailRemindersEnabled: true })
      .where(eq(users.id, userId));

    const vehicleId = uuid();
    await app.inject({
      method: "POST",
      url: "/v1/vehicles",
      headers: auth,
      payload: vehiclePayload(vehicleId),
    });
    const dueItem = uuid();
    await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/plan-items`,
      headers: auth,
      payload: { id: dueItem, name: "Tires", next_due_mileage: 9_500 },
    });
    const disabledItem = uuid();
    await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/plan-items`,
      headers: auth,
      payload: { id: disabledItem, name: "Wipers", next_due_mileage: 9_000, enabled: false },
    });

    const calls: { to: string; reminder: MaintenanceReminderEmail }[] = [];
    const result = await scanReminderEmails({ db, mailer: fakeMailer(calls) });
    expect(result.sent).toBe(1);
    expect(calls[0].reminder.itemName).toBe("Tires");
    expect(calls[0].reminder.phase).toBe("due");

    await app.inject({
      method: "POST",
      url: `/v1/vehicles/${vehicleId}/archive`,
      headers: auth,
    });
    await db.update(users).set({ emailRemindersEnabled: true }).where(eq(users.id, userId));
    const afterArchive = await scanReminderEmails({ db, mailer: fakeMailer(calls) });
    expect(afterArchive.sent).toBe(0);
    await app.close();
  });
});
