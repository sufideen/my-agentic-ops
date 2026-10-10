# Deployment Summary

- Date/time (UTC): 2026-10-10 11:11
- Region: uksouth
- Resource group: rg-sdgweb01-dev
- App Service default hostname: app-sdgweb01-dev.azurewebsites.net
- Key Vault URI: https://kv-sdgweb01-dev.vault.azure.net/
- Status: **Succeeded**

Method: az deployment sub create (name sdgweb01-dev); azd not used (not installed).

History:
- Attempt 1 failed: InvalidMaxSizeTierCombination (Basic tier, max size 34359738368). Fix: maxSizeBytes 2147483648.
- Attempt 2 failed: ProvisioningDisabled (zone redundant database not supported). Fix: zoneRedundant: false on the database.
- Attempt 3 succeeded.

## Post-deploy SQL access (2026-10-10 UTC)
- Ran as the Entra admin against sqldb-sdgweb01-dev: CREATE USER [app-sdgweb01-dev] FROM EXTERNAL PROVIDER; added to db_datareader and db_datawriter.
- Verified: user exists (EXTERNAL_USER) with both roles.
- Temporary firewall rule tmp-admin-20261010 (193.237.193.85) was created and then removed. The 0.0.0.0 Azure-services rule was not touched.
- Status: Succeeded

## Managed identity SQL connectivity test (2026-10-10 UTC)
- Deployed a temporary .NET 8 test app to app-sdgweb01-dev; GET /sqltest connected to sqldb-sdgweb01-dev with "Authentication=Active Directory Managed Identity" (no password, no app settings).
- Response: HTTP 200 {"ok":true,"user":"app-sdgweb01-dev","datareader":1,"datawriter":1}
- Cleanup: test content replaced with a placeholder zip (clean deploy) and the app restarted; /sqltest now returns HTTP 404.
- Status: PASSED
