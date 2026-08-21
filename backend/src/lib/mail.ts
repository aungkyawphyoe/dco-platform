import type { Env } from "../config/env.js";

export type Mailer = {
  sendVerification(to: string, token: string): Promise<void>;
  sendPasswordReset(to: string, token: string): Promise<void>;
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
