param location string
param prefix string
param tags object
param principalId string = ''

@secure()
param postgresPassword string

@secure()
param jwtAccessSecret string

@secure()
param jwtRefreshSecret string

@secure()
param mediaSigningKey string

@secure()
param bootstrapAdminPassword string = ''

param bootstrapAdminEmail string = ''

var acrName = replace('cr${prefix}', '-', '')
var kvName = take('kv-${prefix}', 24)
var pgName = take('psql-${prefix}', 40)
var storageName = take('st${prefix}', 24)
var caName = 'ca-api-${prefix}'
var envName = 'cae-${prefix}'
var lawName = 'log-${prefix}'
var aiName = 'appi-${prefix}'
var commName = 'acs-${prefix}'
var blobContainer = 'dco-media'
var pgAdmin = 'dcoadmin'
var pgDb = 'dco'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: aiName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
  }
}

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: pgName
  location: location
  tags: tags
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: pgAdmin
    administratorLoginPassword: postgresPassword
    storage: { storageSizeGB: 32 }
    backup: { backupRetentionDays: 7 }
    availabilityZone: '1'
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
  }
}

resource postgresDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: postgres
  name: pgDb
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

resource postgresFirewall 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = {
  parent: postgres
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource mediaContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: blobContainer
  properties: { publicAccess: 'None' }
}

resource comm 'Microsoft.Communication/communicationServices@2023-04-01' = {
  name: commName
  location: 'global'
  tags: tags
  properties: {
    dataLocation: 'UnitedStates'
  }
}

resource cae 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

var databaseUrl = 'postgres://${pgAdmin}:${postgresPassword}@${postgres.properties.fullyQualifiedDomainName}:5432/${pgDb}?sslmode=require'

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: caName
  location: location
  tags: union(tags, { 'azd-service-name': 'api' })
  identity: { type: 'SystemAssigned' }
  properties: {
    environmentId: cae.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        allowInsecure: false
      }
      secrets: [
        { name: 'database-url', value: databaseUrl }
        { name: 'jwt-access-secret', value: jwtAccessSecret }
        { name: 'jwt-refresh-secret', value: jwtRefreshSecret }
        { name: 'media-signing-key', value: mediaSigningKey }
        { name: 'storage-connection', value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=core.windows.net' }
        { name: 'mail-api-key', value: comm.listKeys().primaryConnectionString }
      ]
    }
    template: {
      scale: { minReplicas: 1, maxReplicas: 3 }
      containers: [
        {
          name: 'api'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: { cpu: json('0.5'), memory: '1Gi' }
          probes: [
            {
              type: 'liveness'
              httpGet: { path: '/v1/health', port: 8080 }
              initialDelaySeconds: 15
              periodSeconds: 30
            }
            {
              type: 'readiness'
              httpGet: { path: '/v1/ready', port: 8080 }
              initialDelaySeconds: 10
              periodSeconds: 10
            }
          ]
          env: [
            { name: 'APP_ENV', value: 'prod' }
            { name: 'PORT', value: '8080' }
            { name: 'JWT_OWNER_AUD', value: 'dco-owner' }
            { name: 'JWT_ADMIN_AUD', value: 'dco-admin' }
            { name: 'JWT_ACCESS_TTL', value: '15m' }
            { name: 'JWT_REFRESH_TTL', value: '720h' }
            { name: 'MAIL_PROVIDER', value: 'acs' }
            { name: 'MAIL_FROM', value: 'noreply@localhost' }
            { name: 'MEDIA_DRIVER', value: 'azure_blob' }
            { name: 'AZURE_BLOB_CONTAINER', value: blobContainer }
            { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
            { name: 'DATABASE_URL', secretRef: 'database-url' }
            { name: 'JWT_ACCESS_SECRET', secretRef: 'jwt-access-secret' }
            { name: 'JWT_REFRESH_SECRET', secretRef: 'jwt-refresh-secret' }
            { name: 'MEDIA_SIGNING_KEY', secretRef: 'media-signing-key' }
            { name: 'MAIL_API_KEY', secretRef: 'mail-api-key' }
            { name: 'AZURE_STORAGE_CONNECTION_STRING', secretRef: 'storage-connection' }
            { name: 'BOOTSTRAP_ADMIN_EMAIL', value: bootstrapAdminEmail }
            { name: 'BOOTSTRAP_ADMIN_PASSWORD', value: bootstrapAdminPassword }
            { name: 'PUBLIC_API_URL', value: 'https://placeholder.invalid/v1' }
          ]
        }
      ]
    }
  }
}

var kvSecretsOfficer = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
var kvSecretsUser = '4633458b-17de-408a-b874-0445c86b69e6'
var acrPull = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var blobContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource kvAccessApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, containerApp.id, kvSecretsUser)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsUser)
    principalId: containerApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvAccessDeployer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(keyVault.id, principalId, kvSecretsOfficer)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsOfficer)
    principalId: principalId
    principalType: 'User'
  }
}

module acrPullRole 'acr-pull-role.bicep' = {
  name: 'acr-pull'
  params: {
    acrName: acr.name
    principalId: containerApp.identity.principalId
  }
}

resource blobAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, containerApp.id, blobContributor)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobContributor)
    principalId: containerApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output apiUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output acrLoginServer string = acr.properties.loginServer
output keyVaultName string = keyVault.name
