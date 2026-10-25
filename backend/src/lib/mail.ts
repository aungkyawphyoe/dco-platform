import type { Env } from "../config/env.js";

export type MaintenanceReminderEmail = {
  phase: "upcoming" | "due";
  vehicleName: string;
  itemName: string;
  dueOn: string | null;
  dueMileage: number | null;
  currentMileage: number;
  mileageUnit: "mi" | "km";
};

export type Mailer = {
  sendSubscriptionReminder?(to: string, body: string): Promise<void>;
  sendCode(to: string, code: string, purpose: "verify" | "reset", locale: "en" | "my"): Promise<void>;
  sendVerification(to: string, token: string): Promise<void>;
  sendPasswordReset(to: string, token: string): Promise<void>;
  sendOrganizationInvitation(to: string, organizationName: string, role: string): Promise<void>;
  sendOrganizationActivated(to: string, organizationName: string): Promise<void>;
  sendWorkshopInvitation(to: string, workshopName: string): Promise<void>;
  sendVehicleShareInvitation(
    to: string,
    vehicleName: string,
    inviterName: string,
    inviteUrl: string,
  ): Promise<void>;
  sendMaintenanceReminder(to: string, reminder: MaintenanceReminderEmail): Promise<void>;
};

function formatDate(value: string): string {
  const [year, month, day] = value.split("-").map(Number);
  return new Intl.DateTimeFormat("en", {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(Date.UTC(year, month - 1, day)));
}

function formatDistance(miles: number, unit: "mi" | "km"): string {
  const value = unit === "km" ? miles * 1.609344 : miles;
  return `${Math.round(value).toLocaleString("en-US")} ${unit}`;
}

export function maintenanceReminderCopy(reminder: MaintenanceReminderEmail) {
  const due: string[] = [];
  if (reminder.dueOn) due.push(`due on ${formatDate(reminder.dueOn)}`);
  if (reminder.dueMileage != null) {
    due.push(`due at ${formatDistance(reminder.dueMileage, reminder.mileageUnit)}`);
  }
  const dueText = due.length > 0 ? due.join(" and ") : "due";
  const subject = reminder.phase === "upcoming"
    ? `Upcoming maintenance: ${reminder.itemName}`
    : `Maintenance due: ${reminder.itemName}`;
  const intro = reminder.phase === "upcoming"
    ? `${reminder.itemName} is coming up for ${reminder.vehicleName}.`
    : `${reminder.itemName} is due for ${reminder.vehicleName}.`;
  const body = [
    intro,
    "",
    `It is ${dueText}.`,
    `Current odometer: ${formatDistance(reminder.currentMileage, reminder.mileageUnit)}.`,
    "",
    "Open the AutoX app to record the service or manage this reminder.",
  ].join("\n");
  return { subject, body };
}

function link(env: Env, path: string, token: string): string {
  const base = env.PUBLIC_API_URL.replace(/\/$/, "");
  return `${base}${path}?token=${encodeURIComponent(token)}`;
}

export function createMailer(env: Env): Mailer {
  return {
    async sendSubscriptionReminder(to, body) {
      if (env.MAIL_PROVIDER === "stdout") {
        if (env.APP_ENV === "prod") throw new Error("Production email delivery is not configured");
        console.log(`[mail] subscription ${to}: ${body}`); return;
      }
      await sendAcs(env, to, "AutoX subscription update", body);
    },
    async sendCode(to, code, purpose, locale) {
      const subject = locale === "my" ? "AutoX အတည်ပြုကုဒ်" : (purpose === "reset" ? "Reset your AutoX password" : "Verify your AutoX email");
      const body = locale === "my"
        ? `သင်၏ ${purpose === "reset" ? "စကားဝှက်ပြန်သတ်မှတ်ရန်" : "အီးမေးလ်အတည်ပြုရန်"} ကုဒ်မှာ ${code} ဖြစ်ပါသည်။ ၁၀ မိနစ်အတွင်း အသုံးပြုပါ။ ဤကုဒ်ကို မျှဝေခြင်းမပြုပါနှင့်။`
        : `Your ${purpose === "reset" ? "password reset" : "email verification"} code is ${code}. It expires in 10 minutes. Do not share it.`;
      if (env.MAIL_PROVIDER === "stdout") {
        if (env.APP_ENV === "prod") throw new Error("Production email delivery is not configured");
        console.log(`[mail] ${purpose} code ${to}: ${code}`);
        return;
      }
      await sendAcs(env, to, subject, body);
    },
    async sendVerification(to, token) {
      const url = link(env, "/auth/verify-email", token);
      if (env.MAIL_PROVIDER === "stdout") {
        console.log(`[mail] verify ${to}: ${url}`);
        return;
      }
      await sendAcs(env, to, "Verify your AutoX email", `Confirm your email: ${url}`);
    },
    async sendPasswordReset(to, token) {
      const url = link(env, "/auth/reset-password", token);
      if (env.MAIL_PROVIDER === "stdout") {
        console.log(`[mail] reset ${to}: ${url}`);
        return;
      }
      await sendAcs(env, to, "Reset your AutoX password", `Reset your password: ${url}`);
    },
    async sendOrganizationInvitation(to, organizationName, role) {
      const body = `You have been added to ${organizationName} as ${role}. Sign in to your AutoX account to access the organization workspace.`;
      if (env.MAIL_PROVIDER === "stdout") {
        console.log(`[mail] organization invite ${to}: ${body}`);
        return;
      }
      await sendAcs(env, to, `AutoX Fleet access: ${organizationName}`, body);
    },
    async sendOrganizationActivated(to, organizationName) {
      const body = `${organizationName} is now active. Sign in to AutoX; Fleet access is available to organization members.`;
      if (env.MAIL_PROVIDER === "stdout") {
        console.log(`[mail] organization activated ${to}: ${body}`);
        return;
      }
      await sendAcs(env, to, `AutoX Fleet activated: ${organizationName}`, body);
    },
    async sendWorkshopInvitation(to, workshopName) {
      const body = `You have been granted workshop access for ${workshopName}. Set your AutoX password using the password setup email, then sign in to the workshop workspace.`;
      if (env.MAIL_PROVIDER === "stdout") {
        console.log(`[mail] workshop invite ${to}: ${body}`);
        return;
      }
      await sendAcs(env, to, `AutoX Workshop access: ${workshopName}`, body);
    },
    async sendVehicleShareInvitation(to, vehicleName, inviterName, inviteUrl) {
      const body = `${inviterName} shared the vehicle "${vehicleName}" with you. Open the AutoX app and accept the invitation: ${inviteUrl}`;
      if (env.MAIL_PROVIDER === "stdout") {
        console.log(`[mail] vehicle share invite ${to}: ${body}`);
        return;
      }
      await sendAcs(env, to, `AutoX: ${vehicleName} shared with you`, body);
    },
    async sendMaintenanceReminder(to, reminder) {
      const { subject, body } = maintenanceReminderCopy(reminder);
      if (env.MAIL_PROVIDER === "stdout") {
        console.log(`[mail] maintenance ${reminder.phase} ${to}: ${subject}`);
        return;
      }
      await sendAcs(env, to, subject, body);
    },
  };
}

async function sendAcs(env: Env, to: string, subject: string, body: string): Promise<void> {
  const { EmailClient } = await import("@azure/communication-email");
  const connection = env.MAIL_API_KEY ?? env.ACS_ENDPOINT;
  if (!connection) throw new Error("ACS mail is not configured");
  const client = new EmailClient(connection);
  const poller = await client.beginSend({
    senderAddress: env.MAIL_FROM,
    content: { subject, plainText: body },
    recipients: { to: [{ address: to }] },
  });
  const result = await poller.pollUntilDone();
  if (result.status !== "Succeeded") throw new Error("Email delivery failed");
}
