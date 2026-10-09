import { z } from "zod";

const schema = z.object({
  APP_ENV: z.enum(["local", "dev", "stage", "prod"]).default("local"),
  AUTH_TRUST_PROXY_HOPS: z.coerce.number().int().min(0).max(3).default(0),
  AUTH_CODES_ENABLED: z.enum(["off", "on"]).default("off"),
  AUTH_CODE_SECRET: z.string().min(32).optional(),
  GOOGLE_CLIENT_ID: z.string().optional(),
  GOOGLE_CLIENT_SECRET: z.string().optional(),
  APPLE_CLIENT_ID: z.string().optional(),
  APPLE_TEAM_ID: z.string().optional(),
  APPLE_KEY_ID: z.string().optional(),
  APPLE_PRIVATE_KEY: z.string().optional(),
  PORT: z.coerce.number().default(8080),
  DATABASE_URL: z.string().default("postgres://dco:dco@localhost:5432/dco"),
  JWT_ACCESS_SECRET: z.string().min(16),
  JWT_REFRESH_SECRET: z.string().min(16),
  JWT_ACCESS_TTL: z.string().default("15m"),
  JWT_REFRESH_TTL: z.string().default("720h"),
  JWT_OWNER_AUD: z.string().default("dco-owner"),
  JWT_FLEET_AUD: z.string().default("dco-fleet"),
  JWT_WORKSHOP_AUD: z.string().default("dco-workshop"),
  JWT_ADMIN_AUD: z.string().default("dco-admin"),
  BOOTSTRAP_ADMIN_EMAIL: z.string().email().optional(),
  BOOTSTRAP_ADMIN_PASSWORD: z.string().optional(),
  MAIL_PROVIDER: z.enum(["stdout", "acs"]).default("stdout"),
  EMAIL_VERIFICATION: z.enum(["off", "on"]).default("off"),
  MAIL_API_KEY: z.string().optional(),
  MAIL_FROM: z.string().default("noreply@localhost"),
  ACS_ENDPOINT: z.string().optional(),
  MEDIA_DRIVER: z.enum(["local", "azure_blob"]).default("local"),
  MEDIA_LOCAL_DIR: z.string().default("var/media"),
  MEDIA_SIGNING_KEY: z.string().min(8),
  AZURE_STORAGE_CONNECTION_STRING: z.string().optional(),
  AZURE_BLOB_CONTAINER: z.string().default("dco-media"),
  CORS_ORIGINS: z.string().default("http://localhost:3000,http://localhost:5173"),
  OPENAPI_SPEC_PATH: z.string().optional(),
  PUBLIC_API_URL: z.string().default("http://localhost:8080/v1"),
  LICENSE_KID: z.string().default("lic-2026-10"),
  LICENSE_ED25519_KEY: z.string().optional(),
  LICENSE_TTL_DAYS: z.coerce.number().int().positive().default(30),
});

export type Env = z.infer<typeof schema>;

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const parsed = schema.safeParse(source);
  if (!parsed.success) {
    throw new Error(`Invalid environment: ${parsed.error.message}`);
  }
  if (parsed.data.AUTH_CODES_ENABLED === "on" && !parsed.data.AUTH_CODE_SECRET) {
    throw new Error("AUTH_CODE_SECRET is required when AUTH_CODES_ENABLED=on");
  }
  return parsed.data;
}
