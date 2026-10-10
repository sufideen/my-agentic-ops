# Deployment Summary: sdgweb02 (dev)

- Date/time (UTC): 2026-10-10 13:10
- Region: uksouth
- Resource group: rg-sdgweb02-dev
- App Service hostname: app-sdgweb02-dev.azurewebsites.net
- Key Vault URI: https://kv-sdgweb02-dev.vault.azure.net/
- Status: **Succeeded**

## Second deployment (approved additions)
- SQL firewall rule `AllowAzureServices` (0.0.0.0 to 0.0.0.0) on sql-sdgweb02-dev.
- Key Vault secret `sql-connection-string` (passwordless, Authentication=Active Directory Default).
- Key Vault roles: Secrets User for the App Service identity; Secrets Officer for the deploying user.
- App setting `SqlConnectionString` set to a Key Vault reference.
- Verified: secret exists, firewall rule exists, app setting present.

## Pending
- SQL contained user for the managed identity is NOT done. Run manually as the Entra admin on sqldb-sdgweb02-dev:
  `CREATE USER [app-sdgweb02-dev] FROM EXTERNAL PROVIDER; ALTER ROLE db_datareader ADD MEMBER [app-sdgweb02-dev]; ALTER ROLE db_datawriter ADD MEMBER [app-sdgweb02-dev];`
