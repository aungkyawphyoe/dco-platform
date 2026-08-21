# ADR: Azure hosting (Phase 1)

**Status:** Accepted  
**Date:** 2026-08-21  
**Supersedes:** Azure VPS sketch in earlier `architecture/system.md`

## Context

The API must run on Microsoft Azure. Earlier docs sketched a single VPS. Grilling for Phase 1 chose managed PaaS so Blob, Postgres, Key Vault, and email are not files on a VM disk.

This slice makes the app **deployable** (`azure.yaml` + Bicep). It does not require a live `azd up`.

## Decision

| Concern | Choice |
|---------|--------|
| Compute | Azure Container Apps (external ingress, min 1 replica) |
| Image registry | Azure Container Registry |
| Database | Azure Database for PostgreSQL Flexible Server |
| Media | Azure Blob Storage (private container; API stores `blob_key`) |
| Secrets | Azure Key Vault + Container Apps secret refs; managed identity |
| Email | Azure Communication Services Email (local: log links to stdout) |
| Observability | Log Analytics + Application Insights |
| IaC | Bicep + Azure Developer CLI (`azure.yaml` at repo root) |

Out of Phase 1 hosting: APIM, AKS, Front Door, Entra External ID, Azure Functions as the API.

Local loop: Docker Compose (API + Postgres). `MEDIA_DRIVER=local` (gitignored directory).

## Consequences

- TLS termination is on Container Apps ingress, not a VM reverse proxy.
- JWT signing keys live in Key Vault, not an env file on a VPS.
- Swap local disk media to Blob without changing JSON resource URLs (`blob_key`).
- Region and subscription are `azd` parameters; they are not hardcoded.

## Alternatives considered

- Azure VM + Docker Compose — matches the old sketch; more ops, weaker secret/media story.
- Azure App Service — fine for a single API; Container Apps is the same recipe when a worker is added later.
- Azure Functions HTTP — poor fit for a versioned REST + sync change-log API.
