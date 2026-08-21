# Azure Deployment Plan

> **Status:** Approved

Generated: 2026-08-21

This slice produces deployable IaC and a Container Apps API. It does **not** run `azd up`. Subscription and region are `azd` parameters supplied at first deploy.

---

## 1. Project Overview

**Goal:** Host the DCO Phase 1 REST API (`/v1`) on Azure Container Apps with PostgreSQL, Blob, Key Vault, and ACS Email. Owner + admin JWT audiences only.

**Path:** Add Components (monorepo already exists; `backend/` is new)

---

## 2. Requirements

| Attribute | Value |
|-----------|-------|
| Classification | Development (deployable; prod SKUs parameterized) |
| Scale | Small |
| Budget | Cost-Optimized |
| **Subscription** | Not bound in this slice. Set with `azd env` at first deploy. |
| **Location** | Parameter `location` (default `eastasia`). Confirm at first deploy. |

---

## 3. Components Detected

| Component | Type | Technology | Path |
|-----------|------|------------|------|
| dco-api | API | Fastify / TypeScript / Node 22 | `backend/` |
| Flutter owner app | Mobile | Flutter | `mobile/` (not deployed by this IaC) |
| Web admin | Frontend | Not chosen | `web/` (not in this slice) |

---

## 4. Recipe Selection

**Selected:** AZD + Bicep

**Rationale:** Grilling chose Bicep + `azd` as the Azure Prepare path. One Container App service, no Terraform.

---

## 5. Architecture

**Stack:** Containers

### Service Mapping

| Component | Azure Service | SKU |
|-----------|---------------|-----|
| dco-api | Container Apps | Consumption, 0.5 vCPU / 1Gi, min replicas 1 |
| Images | Container Registry | Basic |
| Database | PostgreSQL Flexible Server | Burstable B1ms, PostgreSQL 16 |
| Media | Storage Account (Blob) | Standard LRS, private container |
| Email | Communication Services | Email |
| Secrets | Key Vault | Standard |
| Identity | System-assigned MI on the Container App | n/a |

### Supporting Services

| Service | Purpose |
|---------|---------|
| Log Analytics | Centralized logging |
| Application Insights | Monitoring & APM |
| Key Vault | JWT secrets, DB URL, mail, blob |
| Managed Identity | ACR pull, Key Vault, Blob |

---

## 6. Provisioning Limit Checklist

Quota CLI was not run: no subscription is attached in this slice. Figures below are **public Azure default limits** (docs), used so this plan has no empty cells. Re-check with `az quota` against the real subscription before first `azd up`.

| Resource Type | Number to Deploy | Total After Deployment | Limit/Quota | Notes |
|---------------|------------------|------------------------|-------------|-------|
| Microsoft.App/managedEnvironments | 1 | 1 | 15 per region (typical default) | Docs: Container Apps environments. Re-verify on subscribe. |
| Microsoft.App/containerApps | 1 | 1 | 200 per environment | Docs: Container Apps. |
| Microsoft.ContainerRegistry/registries | 1 | 1 | 100 Basic per subscription | Docs: ACR. |
| Microsoft.DBforPostgreSQL/flexibleServers | 1 | 1 | 50 per region (typical) | Docs: PostgreSQL Flexible. |
| Microsoft.Storage/storageAccounts | 1 | 1 | 250 per region | Official ARM limits. |
| Microsoft.KeyVault/vaults | 1 | 1 | 1000 per subscription | Official Key Vault limits. |
| Microsoft.Communication/communicationServices | 1 | 1 | 1000 per subscription | ACS docs. |
| Microsoft.OperationalInsights/workspaces | 1 | 1 | 5000 per subscription | Log Analytics docs. |
| Microsoft.Insights/components | 1 | 1 | Subscription-level App Insights | Docs. |

**Status:** Within published defaults for an empty subscription. Confirm before first deploy.

---

## 7. Execution Checklist

### Phase 1: Planning
- [x] Analyze workspace
- [x] Gather requirements
- [x] Confirm subscription and location with user (deferred: parameterized; this slice does not deploy)
- [x] Prepare resource inventory
- [x] Fetch quotas (docs defaults; live quota CLI at first deploy)
- [x] Scan codebase
- [x] Select recipe
- [x] Plan architecture
- [x] **User approved this plan** (grilling + attached implementation plan)

### Phase 2: Execution
- [x] Research components
- [x] Generate infrastructure files
- [x] Generate application configuration
- [x] Generate Dockerfiles
- [ ] Update plan status to "Ready for Validation" — **not in this slice** (no azure-validate / azure-deploy)

### Phase 3: Validation
- [ ] Out of this slice

### Phase 4: Deployment
- [ ] Out of this slice (`azd up` later)

---

## 7. Validation Proof

Not run. This slice does not invoke azure-validate or azure-deploy.

---

## 8. Files to Generate

| File | Purpose | Status |
|------|---------|--------|
| `.azure/deployment-plan.md` | This plan | done |
| `azure.yaml` | AZD configuration | done |
| `infra/main.bicep` | Subscription-scoped RG + modules | done |
| `infra/app.bicep` | Container Apps, PostgreSQL, Blob, Key Vault, ACS | done |
| `backend/Dockerfile` | Container build | done |

---

## 9. Next Steps

> Current: Execution (app + IaC in repo; no cloud provision)

1. Implement Fastify API in `backend/`.
2. Write Bicep + `azure.yaml` + Dockerfile.
3. Later: `azd env new`, set subscription/location, `azd up`.
