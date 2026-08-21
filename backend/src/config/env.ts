import { z } from "zod";

const schema = z.object({
  APP_ENV: z.enum(["local", "dev", "stage", "prod"]).default("local"),
  PORT: z.coerce.number().default(8080),
  DATABASE_URL: z.string().default("postgres://dco:dco@localhost:5432/dco"),
  JWT_ACCESS_SECRET: z.string().min(16),
  JWT_REFRESH_SECRET: z.string().min(16),
  JWT_ACCESS_TTL: z.string().default("15m"),
  JWT_REFRESH_TTL: z.string().default("720h"),
  JWT_OWNER_AUD: z.string().default("dco-owner"),
  JWT_ADMIN_AUD: z.string().default("dco-admin"),
  BOOTSTRAP_ADMIN_EMAIL: z.string().email().optional(),
  BOOTSTRAP_ADMIN_PASSWORD: z.string().optional(),
  MAIL_PROVIDER: z.enum(["stdout", "acs"]).default("stdout"),
  MAIL_API_KEY: z.string().optional(),
  MAIL_FROM: z.string().default("noreply@localhost"),
  ACS_ENDPOINT: z.string().optional(),
  MEDIA_DRIVER: z.enum(["local", "azure_blob"]).default("local"),
  MEDIA_LOCAL_DIR: z.string().default("var/media"),
  MEDIA_SIGNING_KEY: z.string().min(8),
  AZURE_STORAGE_CONNECTION_STRING: z.string().optional(),
  AZURE_BLOB_CONTAINER: z.string().default("dco-media"),
  CORS_ORIGINS: z.string().default("http://localhost:5173"),
  PUBLIC_API_URL: z.string().default("http://localhost:8080/v1"),
});

export type Env = z.infer<typeof schema>;

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const parsed = schema.safeParse(source);
  if (!parsed.success) {
    throw new Error(`Invalid environment: ${parsed.error.message}`);
  }
  return parsed.data;
}
