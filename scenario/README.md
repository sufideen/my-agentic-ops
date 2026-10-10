# sdgweb01 (dev) Azure scenario

Bicep infrastructure for a small web workload in `uksouth`, with no passwords anywhere. The app reaches SQL and Key Vault through its managed identity.

## What it builds

| Resource | Name | Notes |
|---|---|---|
| Resource group | `rg-sdgweb01-dev` | Created by the subscription-scope deployment |
| App Service plan | `asp-sdgweb01-dev` | B1, Linux |
| App Service | `app-sdgweb01-dev` | Linux, .NET 8 (`DOTNETCORE\|8.0`), HTTPS only, TLS 1.2, FTPS disabled, system-assigned managed identity |
| SQL Server | `sql-sdgweb01-dev` | Entra ID-only authentication, TLS 1.2, deploying user is Entra admin |
| SQL Database | `sqldb-sdgweb01-dev` | Basic (5 DTU) |
| Key Vault | `kv-sdgweb01-dev` | Standard, RBAC authorisation, soft delete (7 days) |
| Role assignment | n/a | App identity gets `Key Vault Secrets User` on the vault |

Outputs: `AZURE_RESOURCE_GROUP`, `APP_SERVICE_HOSTNAME`, `KEY_VAULT_URI`.

All resources use pinned Azure Verified Modules (AVM).

## File layout

| File | Purpose |
|---|---|
| `requirements-architecture.md` | Parsed requirements, architecture assessment, artifact contract |
| `infra/main.bicep` | Subscription-scope template for all resources |
| `infra/main.bicepparam` | Parameter values |
| `azure.yaml` | azd project manifest (`infra.provider: bicep`, `path: infra`) |
| `deployment-summary.md` | Deployment record, post-deploy SQL step, managed identity test |

## Parameters

| Parameter | Description |
|---|---|
| `workloadName` | 8 characters or fewer, lowercase letters and digits (`sdgweb01`) |
| `environment` | `dev`, `test` or `prod` (`dev`) |
| `location` | Defaults to `uksouth` |
| `sqlAdminLogin` | Entra admin UPN for the SQL server |
| `sqlAdminObjectId` | Entra admin object ID for the SQL server |

No password parameters exist. Replace the admin values in `infra/main.bicepparam` with your own identity before deploying (`az ad signed-in-user show`).

## Deploy

azd was the originally intended method (via `azure.yaml`) but was not installed, so the actual deployment used `az deployment sub create`.

With Azure CLI (used for the real deployment):

    az deployment sub create \
      --name sdgweb01-dev \
      --location uksouth \
      --template-file scenario/infra/main.bicep \
      --parameters scenario/infra/main.bicepparam

With azd (run from `scenario/`):

    azd env new sdgweb01-dev --location uksouth --subscription <subscription-id> --no-prompt
    azd provision --no-prompt

## Post-deploy SQL step

The app identity needs a contained database user. Connect to `sqldb-sdgweb01-dev` as the Entra admin and run:

    CREATE USER [app-sdgweb01-dev] FROM EXTERNAL PROVIDER;
    ALTER ROLE db_datareader ADD MEMBER [app-sdgweb01-dev];
    ALTER ROLE db_datawriter ADD MEMBER [app-sdgweb01-dev];

This was done and verified. A temporary .NET 8 test app connected using `Authentication=Active Directory Managed Identity` and returned HTTP 200 `{"ok":true,"user":"app-sdgweb01-dev","datareader":1,"datawriter":1}`. The test content was then removed. Details are in `deployment-summary.md`.

## Deployment lessons

- Basic tier requires `maxSizeBytes: 2147483648` (the default 32 GB failed with `InvalidMaxSizeTierCombination`).
- Set `zoneRedundant: false` on the database (zone redundancy failed with `ProvisioningDisabled`).
- B1 App Service plan quota must be available in `uksouth`.

## Known caveat

The SQL firewall rule `AllowAllWindowsAzureIps` (0.0.0.0) allows any Azure service to reach the server. This is a dev-only assumption. Tighten it before production, for example with private endpoints or VNet integration.
