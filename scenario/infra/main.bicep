targetScope = 'subscription'

@description('Workload name: 8 characters or fewer, lowercase letters and digits.')
@maxLength(8)
param workloadName string

@description('Environment name.')
@allowed(['dev', 'test', 'prod'])
param environment string

@description('Azure region.')
param location string = 'uksouth'

@description('Entra login (UPN) of the SQL administrator.')
param sqlAdminLogin string

@description('Entra object ID of the SQL administrator.')
param sqlAdminObjectId string

var suffix = '${workloadName}-${environment}'
var kvSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var kvSecretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
var sqlConnectionString = 'Server=tcp:sql-${suffix}${az.environment().suffixes.sqlServerHostname},1433;Database=sqldb-${suffix};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${suffix}'
  location: location
}

module plan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  scope: rg
  name: 'plan'
  params: {
    name: 'asp-${suffix}'
    location: location
    skuName: 'B1'
    kind: 'linux'
    reserved: true
  }
}

module app 'br/public:avm/res/web/site:0.15.1' = {
  scope: rg
  name: 'app'
  params: {
    name: 'app-${suffix}'
    location: location
    kind: 'app,linux'
    serverFarmResourceId: plan.outputs.resourceId
    httpsOnly: true
    managedIdentities: {
      systemAssigned: true
    }
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|8.0'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
    }
  }
}

module sql 'br/public:avm/res/sql/server:0.12.0' = {
  scope: rg
  name: 'sql'
  params: {
    name: 'sql-${suffix}'
    location: location
    minimalTlsVersion: '1.2'
    firewallRules: [
      {
        name: 'AllowAzureServices'
        startIpAddress: '0.0.0.0'
        endIpAddress: '0.0.0.0'
      }
    ]
    administrators: {
      azureADOnlyAuthentication: true
      administratorType: 'ActiveDirectory'
      login: sqlAdminLogin
      sid: sqlAdminObjectId
      principalType: 'User'
      tenantId: tenant().tenantId
    }
    databases: [
      {
        name: 'sqldb-${suffix}'
        availabilityZone: 'NoPreference'
        zoneRedundant: false
        maxSizeBytes: 2147483648
        sku: {
          name: 'Basic'
          tier: 'Basic'
          capacity: 5
        }
      }
    ]
  }
}

module kv 'br/public:avm/res/key-vault/vault:0.11.0' = {
  scope: rg
  name: 'kv'
  params: {
    name: 'kv-${suffix}'
    location: location
    sku: 'standard'
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: environment == 'prod' ? 90 : 7
    enablePurgeProtection: environment == 'prod'
    roleAssignments: [
      {
        principalId: app.outputs.?systemAssignedMIPrincipalId ?? ''
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsUserRoleId)
      }
      {
        principalId: sqlAdminObjectId
        principalType: 'User'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsOfficerRoleId)
      }
    ]
    secrets: [
      {
        name: 'sql-connection-string'
        value: sqlConnectionString
      }
    ]
  }
}

module appSettings 'appsettings.bicep' = {
  scope: rg
  name: 'appsettings'
  params: {
    appName: app.outputs.name
    keyVaultName: kv.outputs.name
    secretName: 'sql-connection-string'
  }
}

output AZURE_RESOURCE_GROUP string = rg.name
output APP_SERVICE_HOSTNAME string = app.outputs.defaultHostname
output KEY_VAULT_URI string = kv.outputs.uri
