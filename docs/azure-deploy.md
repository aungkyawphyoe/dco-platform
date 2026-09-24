# Azure Manual Deployment Guide

Step-by-step guide for deploying the DCO backend API to Azure Container Apps. Use this when `azd deploy` is unavailable or when you need fine-grained control over the deployment.

---

## Prerequisites

- Azure CLI logged in (`az login`)
- Subscription set (`az account set --subscription <id>`)
- Docker running locally (for local builds) or use ACR Tasks (cloud builds)
- Access to the `dco-rg` resource group

---

## Resource Map

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | `dco-rg` | All resources live here |
| Container App | `dco-api-24739` | The running API |
| Container Registry | `dcoacr24739` | Docker image storage |
| PostgreSQL | `dco-pg-24739` | Database |
| Managed Environment | `dco-env-24739` | Container Apps environment |
| Log Analytics | `log-24739` | Logs and diagnostics |
| App Insights | `appi-24739` | Telemetry |

**Production URL:** `https://dco-api-24739.wonderfulplant-4ba5225f.southeastasia.azurecontainerapps.io/v1`

---

## Step 1 — Build the Docker Image

### Option A: Local build (Docker Desktop running)

```bash
cd backend/
docker build -t dcoacr24739.azurecr.io/dco-api:<tag> .
docker push dcoacr24739.azurecr.io/dco-api:<tag>
```

### Option B: ACR Task (no Docker needed)

```bash
az acr build \
  --registry dcoacr24739 \
  --image dco-api:<tag> \
  --image dco-api:latest \
  --file backend/Dockerfile \
  backend/
```

ACR Tasks build in the cloud and push directly. Takes ~90 seconds.

**Tag convention:** `v1.3.5`, `v1.4.0`, etc. Always rebuild if the previous image can't be pulled (corrupted layers happen).

---

## Step 2 — Verify Image Exists in ACR

```bash
az acr repository show-manifests \
  --name dcoacr24739 \
  --repository dco-api \
  --query "[?contains(tags, '<tag>')].{digest:digest, tags:tags, timestamp:timestamp}" \
  --output table
```

Confirm the digest is present and the timestamp is recent.

---

## Step 3 — Deploy to Container Apps

Use the **REST API PATCH** method. This is the only reliable way to update secrets + env vars + image in a single operation. The `az containerapp update` and `az containerapp ingress traffic set` CLIs strip secrets.

```bash
RESOURCE_ID="/subscriptions/58ba6f9b-1144-44cb-92c7-18e4bda5a6e2/resourceGroups/dco-rg/providers/Microsoft.App/containerapps/dco-api-24739"
ACCESS_TOKEN=$(az account get-access-token --query accessToken -o tsv)

curl -s -X PATCH "https://management.azure.com${RESOURCE_ID}?api-version=2024-03-01" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "properties": {
      "configuration": {
        "ingress": {
          "external": true,
          "targetPort": 8080,
          "transport": "auto",
          "allowInsecure": false
        },
        "secrets": [
          {"name": "database-url", "value": "<DATABASE_URL>"},
          {"name": "jwt-access-secret", "value": "<JWT_ACCESS_SECRET>"},
          {"name": "jwt-refresh-secret", "value": "<JWT_REFRESH_SECRET>"},
          {"name": "media-signing-key", "value": "<MEDIA_SIGNING_KEY>"}
        ]
      },
      "template": {
        "revisionSuffix": "<REVISION_SUFFIX>",
        "containers": [
          {
            "name": "dco-api-24739",
            "image": "dcoacr24739.azurecr.io/dco-api:<TAG>",
            "resources": {"cpu": 0.5, "memory": "1Gi"},
            "probes": [
              {"httpGet": {"path": "/v1/health", "port": 8080}, "initialDelaySeconds": 15, "periodSeconds": 30, "type": "Liveness"},
              {"httpGet": {"path": "/v1/ready", "port": 8080}, "initialDelaySeconds": 10, "periodSeconds": 10, "type": "Readiness"}
            ],
            "env": [
              {"name": "APP_ENV", "value": "prod"},
              {"name": "PORT", "value": "8080"},
              {"name": "JWT_OWNER_AUD", "value": "dco-owner"},
              {"name": "JWT_FLEET_AUD", "value": "dco-fleet"},
              {"name": "JWT_WORKSHOP_AUD", "value": "dco-workshop"},
              {"name": "JWT_ADMIN_AUD", "value": "dco-admin"},
              {"name": "JWT_ACCESS_TTL", "value": "15m"},
              {"name": "JWT_REFRESH_TTL", "value": "720h"},
              {"name": "MAIL_PROVIDER", "value": "stdout"},
              {"name": "MAIL_FROM", "value": "noreply@localhost"},
              {"name": "MEDIA_DRIVER", "value": "local"},
              {"name": "DATABASE_URL", "secretRef": "database-url"},
              {"name": "JWT_ACCESS_SECRET", "secretRef": "jwt-access-secret"},
              {"name": "JWT_REFRESH_SECRET", "secretRef": "jwt-refresh-secret"},
              {"name": "MEDIA_SIGNING_KEY", "secretRef": "media-signing-key"},
              {"name": "BOOTSTRAP_ADMIN_EMAIL", "value": "<ADMIN_EMAIL>"},
              {"name": "BOOTSTRAP_ADMIN_PASSWORD", "value": "<ADMIN_PASSWORD>"},
              {"name": "PUBLIC_API_URL", "value": "https://dco-api-24739.wonderfulplant-4ba5225f.southeastasia.azurecontainerapps.io/v1"},
              {"name": "DEPLOY_TS", "value": "<TIMESTAMP>"}
            ]
          }
        ],
        "scale": {"minReplicas": 1, "maxReplicas": 3}
      }
    }
  }' | jq '.properties.provisioningState // "submitted"'
```

**Replace these placeholders:**
- `<TAG>` — Docker image tag (e.g. `v1.4.0`)
- `<REVISION_SUFFIX>` — Unique revision name (e.g. `v143`). Increment from the latest.
- `<DATABASE_URL>` — Full Postgres connection string with `?sslmode=require`
- `<JWT_ACCESS_SECRET>` — 64-char hex string
- `<JWT_REFRESH_SECRET>` — 64-char hex string
- `<MEDIA_SIGNING_KEY>` — Min 8 chars (can reuse access secret)
- `<ADMIN_EMAIL>` — Bootstrap admin email
- `<ADMIN_PASSWORD>` — Bootstrap admin password
- `<TIMESTAMP>` — e.g. `20260916120000`

The PATCH returns HTTP 202 (accepted). The deployment runs asynchronously.

---

## Step 4 — Wait and Verify

### Check revision status

```bash
az containerapp revision list \
  --name dco-api-24739 \
  --resource-group dco-rg \
  --query "[].{name:name, runningState:properties.runningState, image:properties.template.containers[0].image}" \
  --output table
```

Wait for `Running` state. Typical startup: 30-60 seconds.

### Check health endpoints

```bash
curl -s https://dco-api-24739.wonderfulplant-4ba5225f.southeastasia.azurecontainerapps.io/v1/health | jq .
curl -s https://dco-api-24739.wonderfulplant-4ba5225f.southeastasia.azurecontainerapps.io/v1/ready | jq .
```

Expected: `{"status": "ok"}` and `{"status": "ready"}`.

### Check startup logs

```bash
WORKSPACE_ID=$(az containerapp env show \
  --ids "/subscriptions/58ba6f9b-1144-44cb-92c7-18e4bda5a6e2/resourceGroups/dco-rg/providers/Microsoft.App/managedEnvironments/dco-env-24739" \
  --query "properties.appLogsConfiguration.logAnalyticsConfiguration.customerId" -o tsv)

az monitor log-analytics query -w "$WORKSPACE_ID" \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s == 'dco-api-24739' | order by TimeGenerated desc | take 20" \
  --output table
```

You should see `[STARTUP]` messages and `Server listening at` in the logs.

---

## Step 5 — Verify the New Endpoint

```bash
# Should return 401 (not 404) — proves the route is registered
curl -s https://dco-api-24739.wonderfulplant-4ba5225f.southeastasia.azurecontainerapps.io/v1/families/me/vehicles | jq .
```

---

## Troubleshooting

### Revision stuck in "Activating"

Check system logs — this usually means the image can't be pulled:

```bash
az monitor log-analytics query -w "$WORKSPACE_ID" \
  --analytics-query "ContainerAppSystemLogs_CL | where ContainerAppName_s == 'dco-api-24739' | order by TimeGenerated desc | take 20" \
  --output table
```

**Common causes:**
- `ImagePullFailure` — The image tag exists but layers are corrupted. Rebuild with `az acr build`.
- `ImagePullFailure` with `unauthorized` — Managed identity lost ACR pull role. Reassign:
  ```bash
  PRINCIPAL_ID=$(az containerapp show --name dco-api-24739 --resource-group dco-rg --query "identity.principalId" -o tsv)
  az role assignment create \
    --assignee "$PRINCIPAL_ID" \
    --role AcrPull \
    --scope "/subscriptions/58ba6f9b-1144-44cb-92c7-18e4bda5a6e2/resourceGroups/dco-rg/providers/Microsoft.ContainerRegistry/registries/dcoacr24739"
  ```

### Container starts but Node.js crashes immediately (zero logs)

Almost always means **env vars are missing**. The `az containerapp update` CLI strips env vars and secrets silently. Always use the REST API PATCH method (Step 3) which preserves them.

Verify env vars are set:
```bash
az containerapp show --name dco-api-24739 --resource-group dco-rg \
  --query "properties.template.containers[0].env | length(@)" -o tsv
```

Should be 17. If 0, the secrets/envs were stripped — redeploy with PATCH.

### Health probe failing

If the container runs but never passes readiness, check:
1. Database connection: the init SQL runs on every startup. If the DB is down or unreachable, startup hangs.
2. Memory: the container has 1Gi. If the process exceeds this, it gets OOM-killed.
3. Probe timing: readiness fires after 10s. If startup takes longer, increase `initialDelaySeconds`.

### Rollback to a previous revision

There's no direct rollback command in single-revision mode. Deploy the previous image tag as a new revision:

```bash
# Redeploy v1.2 (or any known-good tag) using the same PATCH command from Step 3
# Change the image tag and increment revisionSuffix
```

---

## Secrets Reference

These are the current production secret values. **Rotate if exposed.**

| Secret | Value |
|--------|-------|
| `database-url` | `postgres://dcoadmin:<PG_PASSWORD>@dco-pg-24739.postgres.database.azure.com:5432/dco?sslmode=require` |
| `jwt-access-secret` | 64-char hex |
| `jwt-refresh-secret` | 64-char hex |
| `media-signing-key` | Min 8 chars (can match access secret) |

---

## What NOT to Do

1. **Do not use `az containerapp update`** — It strips secrets and env vars, causing silent crashes.
2. **Do not use `az containerapp ingress traffic set`** — Fails in single-revision mode and doesn't help.
3. **Do not use REST API PUT** — Also strips secrets. Only PATCH works correctly.
4. **Do not skip the `revisionSuffix`** — Without it, you may not get a new revision.
5. **Do not forget the `DEPLOY_TS` env var** — It forces a new revision even if nothing else changed.
