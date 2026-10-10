# Requirements and Architecture: sdgweb02 (dev)

## Section 1 - Parsed Requirements

Target environment: dev. Region: uksouth. Workload name: sdgweb02 (8 characters, lowercase letters and digits, compliant).

| Resource | Purpose | Constraints from prompt |
|---|---|---|
| Resource group (implied) | Container for all resources | Subscription-scope deployment creates it |
| App Service plan (implied) | Hosts the web app | Linux |
| Azure App Service | Web front-end | Linux, .NET 8 |
| System-assigned managed identity (on App Service) | Passwordless access to Key Vault and SQL | No hard-coded passwords |
| Azure SQL Server (implied) | Logical server for the database | Entra ID-only authentication |
| Azure SQL Database | Relational data storage | None beyond dev defaults |
| Azure Key Vault | Stores connection strings and secrets | Accessed by managed identity |
| Role assignment (implied) | Key Vault Secrets User for App Service identity on Key Vault | RBAC, not access policies |
| SQL access for managed identity (implied) | App identity needs a database user (for example `CREATE USER [app-sdgweb02-dev] FROM EXTERNAL PROVIDER` with db_datareader/db_datawriter) | Cannot be done in Bicep alone; post-deploy T-SQL step run by the Entra admin |
| SQL firewall rule (implied) | Allow Azure services so the App Service can reach SQL | Rule 0.0.0.0 |
| Key Vault secret (implied) | Holds a connection string with no password, using `Authentication=Active Directory Default` or Managed Identity | No passwords stored |
| App setting Key Vault reference (implied) | App reads the secret through `@Microsoft.KeyVault(...)` | No plain-text connection strings in app settings |

## Section 2 - Architecture Assessment

| Resource | Name | SKU | Region | Security baseline rules | Deploy after |
|---|---|---|---|---|---|
| Resource group | `rg-sdgweb02-dev` | n/a | uksouth | n/a | none (first) |
| App Service plan | `asp-sdgweb02-dev` | B1 (Linux, reserved: true) | uksouth | n/a | Resource group |
| App Service | `app-sdgweb02-dev` | Runs on B1 plan; `linuxFxVersion: DOTNETCORE|8.0` | uksouth | `httpsOnly: true`; minTlsVersion 1.2; FTPS disabled; system-assigned managed identity; no passwords or connection strings in app settings (Key Vault reference only) | App Service plan |
| SQL Server | `sql-sdgweb02-dev` | n/a | uksouth | minimalTlsVersion 1.2; `azureADOnlyAuthentication: true`; deploying user as Entra admin; no SQL admin password | Resource group |
| SQL Database | `sqldb-sdgweb02-dev` | Basic (5 DTU) | uksouth | Inherits server TLS and Entra-only auth | SQL Server |
| Key Vault | `kv-sdgweb02-dev` | Standard | uksouth | RBAC authorisation; soft delete on; dev only: `enablePurgeProtection: false`, `softDeleteRetentionInDays: 7`; TLS 1.2 endpoint | Resource group |
| Role assignment | GUID name | Key Vault Secrets User | n/a | RBAC, scoped to the vault, principal is the App Service identity | App Service and Key Vault |
| Key Vault secret | e.g. `sql-connection-string` | n/a | n/a | Passwordless connection string only | Key Vault, SQL Database (and the deployer needs a Secrets Officer role to write it) |
| App settings (Key Vault reference) | n/a | n/a | n/a | Resolved via managed identity | Role assignment and secret |

Deployment order:
1. Resource group
2. App Service plan, SQL Server, Key Vault (parallel)
3. App Service (with managed identity), SQL Database
4. Role assignment, secret, firewall rule
5. App settings with Key Vault reference
6. Post-deploy: create the SQL contained user for the managed identity (manual T-SQL by the Entra admin)

Notes and assumptions:
- Names are within Azure limits (Key Vault 24 characters: `kv-sdgweb02-dev` is 15).
- The deploying user's object ID and login name are supplied as parameters for the SQL Entra admin. They are not committed in the parameter file if it is excluded from git.
- Writing the secret requires the deployer to hold a data-plane role such as Key Vault Secrets Officer on the vault, which the template should also assign (implied).

## Section 3 - Artifact Contract

| File | Purpose |
|---|---|
| `scenario/infra/main.bicep` | Bicep template (subscription scope) for all resources |
| `scenario/infra/main.bicepparam` | Parameter values |
| `scenario/azure.yaml` | azd project manifest |
| `scenario/deployment-summary.md` | Post-deployment record |
