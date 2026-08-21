targetScope = 'subscription'

@minLength(1)
@maxLength(64)
param environmentName string

@minLength(1)
param location string = 'eastasia'

@description('Principal deploying via azd (optional AcrPush).')
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

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var prefix = 'dco${take(resourceToken, 8)}'
var tags = {
  'azd-env-name': environmentName
  product: 'dco'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module resources 'app.bicep' = {
  name: 'dco-resources'
  scope: rg
  params: {
    location: location
    prefix: prefix
    tags: tags
    postgresPassword: postgresPassword
    jwtAccessSecret: jwtAccessSecret
    jwtRefreshSecret: jwtRefreshSecret
    mediaSigningKey: mediaSigningKey
    bootstrapAdminEmail: bootstrapAdminEmail
    bootstrapAdminPassword: bootstrapAdminPassword
    principalId: principalId
  }
}

output AZURE_RESOURCE_GROUP string = rg.name
output API_URL string = resources.outputs.apiUrl
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.acrLoginServer
