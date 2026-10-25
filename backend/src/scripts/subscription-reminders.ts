import { loadEnv } from '../config/env.js';
import { createPgDb } from '../db/client.js';
import { createMailer } from '../lib/mail.js';
import { sendSubscriptionReminders } from '../lib/subscription-reminders.js';
const env = loadEnv();
const { db, pool } = await createPgDb(env.DATABASE_URL);
try {
    const result = await sendSubscriptionReminders(db, createMailer(env));
    console.log(JSON.stringify(result));
    if (result.failures)
        process.exitCode = 1;
}
finally {
    await pool.end();
}
