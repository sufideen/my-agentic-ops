@description('Name of the existing App Service.')
param appName string

@description('Name of the existing Key Vault.')
param keyVaultName string

@description('Name of the Key Vault secret holding the SQL connection string.')
param secretName string

resource app 'Microsoft.Web/sites@2023-12-01' existing = {
  name: appName
}

resource settings 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: app
  name: 'appsettings'
  properties: {
    SqlConnectionString: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${secretName})'
  }
}
