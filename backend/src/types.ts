import type { FastifyInstance, FastifyRequest } from "fastify";
import type { Env } from "./config/env.js";
import type { Db } from "./db/client.js";
import type { Mailer } from "./lib/mail.js";
import type { MediaStore } from "./lib/media.js";
import type { AccessClaims } from "./lib/crypto.js";

declare module "fastify" {
  interface FastifyContextConfig {
    public?: boolean;
  }

  interface FastifyInstance {
    env: Env;
    db: Db;
    mailer: Mailer;
    media: MediaStore;
  }

  interface FastifyRequest {
    authUser?: AccessClaims & { sub: string };
  }
}

export type AppInstance = FastifyInstance;

export function bearer(request: FastifyRequest): string | null {
  const header = request.headers.authorization;
  if (!header?.startsWith("Bearer ")) return null;
  return header.slice(7);
}
