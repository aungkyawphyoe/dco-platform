# ADR: Backend stack (Phase 1)

**Status:** Accepted  
**Date:** 2026-08-21  
**Closes:** Backend language/DB ADR in `docs/implementation-readiness.md`

## Context

The API contract is REST `/v1` + JWT (`architecture/openapi.yaml`). Hosting is Azure Container Apps (`docs/adr/azure-hosting.md`). The data model is relational (`architecture/data-model.md`). Mobile is already Flutter. Web admin framework is still open.

## Decision

- **Language:** TypeScript on Node.js 22
- **HTTP:** Fastify 5
- **Database:** PostgreSQL 16 (Azure Database for PostgreSQL Flexible Server in Azure; Docker Postgres locally)
- **ORM / migrations:** Drizzle + drizzle-kit
- **Validation:** Zod, aligned to the OpenAPI contract
- **Tests:** Vitest + Fastify `inject`

Contract-first: implement against `architecture/openapi.yaml`. Do not generate a second OpenAPI from route decorators as the source of truth.

## Consequences

- `backend/` is a standalone Node package in this monorepo.
- Shared types with a future admin web app are out of scope; duplicate DTOs if needed.
- NestJS was rejected to keep the HTTP layer thin and avoid a code-first Swagger drift.
- Prisma was rejected so the ERD stays one schema (Drizzle), not a second Prisma schema.

## Alternatives considered

- ASP.NET Core 8 + EF Core — strongest Azure story; not chosen (TypeScript preference).
- NestJS + Prisma — more ceremony; worse fit for an existing OpenAPI file.
- Go + sqlc — small images; more boilerplate for this CRUD + sync surface.
