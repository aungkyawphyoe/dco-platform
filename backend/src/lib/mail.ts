import type { Env } from "../config/env.js";

export type Mailer = {
  sendVerification(to: string, token: string): Promise<void>;
  sendPasswordReset(to: string, token: string): Promise<void>;
  sendOrganizationInvitation(to: string, organizationName: string, role: string): Promise<void>;
  sendOrganizationActivated(to: string, organizationName: string): Promise<void>;
  sendWorkshopInvitation(to: string, workshopName: string): Promise<void>;
};

function link(env: Env, path: string, token: string): string {
  const base = env.PUBLIC_API_URL.replace(/\/$/, "");
  return `${base}${path}?token=${encodeURIComponent(token)}`;
}

export function createMailer(env: Env): Mailer {
  return {
    async sendVerification(to, token) {
      const url = link(env, "/auth/verify-email", token);
      if (env.MAIL_PROVIDER === "stdout") {
        console.log(`[mail] verify ${to}: ${url}`);
        return;
      }
      await sendAcs(env, to, "Verify your DCO email", `Confirm your email: ${url}`);
    },
    async sendPasswordReset(to, token) {
      const url = link(env, "/auth/reset-password", token);
      if (env.MAIL_PROVIDER === "stdout") {
        console.log(`[mail] reset ${to}: ${url}`);
        return;
      }
      await sendAcs(env, to, "Reset your DCO password", `Reset your password: ${url}`);
    },
    async sendOrganizationInvitation(to, organizationName, role) {
      const body = `You have been added to ${organizationName} as ${role}. Sign in to your DCO account to access the organization workspace.`;
      if (env.MAIL_PROVIDER === "stdout") {
        console.log(`[mail] organization invite ${to}: ${body}`);
        return;
      }
      await sendAcs(env, to, `DCO Fleet access: ${organizationName}`, body);
    },
    async sendOrganizationActivated(to, organizationName) {
      const body = `${organizationName} is now active. Sign in to DCO; Fleet access is available to organization members.`;
      if (env.MAIL_PROVIDER === "stdout") {
        console.log(`[mail] organization activated ${to}: ${body}`);
        return;
      }
      await sendAcs(env, to, `DCO Fleet activated: ${organizationName}`, body);
    },
    async sendWorkshopInvitation(to, workshopName) {
      const body = `You have been granted workshop access for ${workshopName}. Set your DCO password using the password setup email, then sign in to the workshop workspace.`;
      if (env.MAIL_PROVIDER === "stdout") {
        console.log(`[mail] workshop invite ${to}: ${body}`);
        return;
      }
      await sendAcs(env, to, `DCO Workshop access: ${workshopName}`, body);
    },
  };
}

async function sendAcs(env: Env, to: string, subject: string, body: string): Promise<void> {
  const { EmailClient } = await import("@azure/communication-email");
  const connection = env.MAIL_API_KEY ?? env.ACS_ENDPOINT;
  if (!connection) throw new Error("ACS mail is not configured");
  const client = new EmailClient(connection);
  await client.beginSend({
    senderAddress: env.MAIL_FROM,
    content: { subject, plainText: body },
    recipients: { to: [{ address: to }] },
  });
}
