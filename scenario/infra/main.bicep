targetScope = 'subscription'

@description('Workload name, 8 characters or fewer, lowercase letters and digits.')
@maxLength(8)
param workloadName string

@description('Environment name.')
@allowed(['dev', 'test', 'prod'])
param environment string

@description('Azure region.')
param location string = 'uksouth'

@description('Entra admin login (UPN) for the SQL server.')
param sqlAdminLogin string

@description('Entra admin object ID for the SQL server.')
param sqlAdminObjectId string

var rgName = 'rg-${workloadName}-${environment}'

module rg 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'rg-${workloadName}'
  params: {
    name: rgName
    location: location
  }
}

module plan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  name: 'plan-${workloadName}'
  scope: resourceGroup(rgName)
  dependsOn: [rg]
  params: {
    name: 'asp-${workloadName}-${environment}'
    location: location
    skuName: 'B1'
    kind: 'linux'
    reserved: true
  }
}

module sql 'br/public:avm/res/sql/server:0.12.0' = {
  name: 'sql-${workloadName}'
  scope: resourceGroup(rgName)
  dependsOn: [rg]
  params: {
    name: 'sql-${workloadName}-${environment}'
    location: location
    minimalTlsVersion: '1.2'
    administrators: {
      azureADOnlyAuthentication: true
      administratorType: 'ActiveDirectory'
      login: sqlAdminLogin
      sid: sqlAdminObjectId
      principalType: 'User'
      tenantId: tenant().tenantId
    }
    firewallRules: [
      {
        name: 'AllowAllWindowsAzureIps'
        startIpAddress: '0.0.0.0'
        endIpAddress: '0.0.0.0'
      }
    ]
    databases: [
      {
        name: 'sqldb-${workloadName}-${environment}'
        availabilityZone: 'NoPreference'
        maxSizeBytes: 2147483648
        zoneRedundant: false
        sku: {
          name: 'Basic'
          tier: 'Basic'
          capacity: 5
        }
      }
    ]
  }
}

module app 'br/public:avm/res/web/site:0.15.1' = {
  name: 'app-${workloadName}'
  scope: resourceGroup(rgName)
  params: {
    name: 'app-${workloadName}-${environment}'
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

module kv 'br/public:avm/res/key-vault/vault:0.11.0' = {
  name: 'kv-${workloadName}'
  scope: resourceGroup(rgName)
  params: {
    name: 'kv-${workloadName}-${environment}'
    location: location
    sku: 'standard'
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    roleAssignments: [
      {
        principalId: app.outputs.?systemAssignedMIPrincipalId ?? ''
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
    ]
  }
}

output AZURE_RESOURCE_GROUP string = rgName
output APP_SERVICE_HOSTNAME string = app.outputs.defaultHostname
output KEY_VAULT_URI string = kv.outputs.uri
