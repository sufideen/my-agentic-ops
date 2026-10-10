# Requirements and Architecture: sdgweb01 (dev)

## Section 1 - Parsed Requirements

Target environment: dev. Region: uksouth. Workload: sdgweb01.

| Resource | Purpose | Constraints |
|---|---|---|
| Resource group (implied) | Container for all resources (subscription-scope deployment creates it) | uksouth |
| App Service plan (implied) | Hosts the web app | Linux |
| App Service (web app) | Web front-end | Linux, .NET 8 (DOTNETCORE\|8.0), system-assigned managed identity |
| SQL Server (implied) | Logical server for the database | Entra ID-only auth |
| Azure SQL Database | Relational data storage | Accessed by managed identity, no passwords |
| Key Vault | Stores connection strings and secrets | RBAC authorisation, soft delete |
| Managed identity | App Service identity for Key Vault and SQL access | No hard-coded passwords |
| Role assignment (implied) | Key Vault Secrets User for the app identity on the vault | Scope: Key Vault |
| SQL contained user (implied) | Grants the app identity database roles | Created post-deploy via T-SQL (CREATE USER ... FROM EXTERNAL PROVIDER) |

## Section 2 - Architecture Assessment

| Resource | Name | SKU | Region | Security baseline rules | Depends on |
|---|---|---|---|---|---|
| Resource group | `rg-sdgweb01-dev` | n/a | uksouth | n/a | none (first) |
| App Service plan | `asp-sdgweb01-dev` | B1 (Linux, reserved: true) | uksouth | n/a | Resource group |
| App Service | `app-sdgweb01-dev` | runs on B1 plan | uksouth | httpsOnly true; minTlsVersion 1.2; system-assigned managed identity; no passwords or connection strings in app settings (use Key Vault references only) | App Service plan |
| SQL Server | `sql-sdgweb01-dev` | n/a | uksouth | minimalTlsVersion 1.2; azureADOnlyAuthentication true; deploying user is Entra admin; no admin password | Resource group |
| SQL Database | `sqldb-sdgweb01-dev` | Basic (5 DTU) | uksouth | Inherits server Entra-only auth and TLS 1.2 | SQL Server |
| Key Vault | `kv-sdgweb01-dev` | Standard | uksouth | enableRbacAuthorization true; soft delete on; TLS 1.2 endpoint | Resource group |
| Role assignment | GUID name | Key Vault Secrets User | n/a | Least privilege, RBAC | Key Vault, App Service (principalId) |

Deployment order:
1. Resource group
2. App Service plan, SQL Server, Key Vault (parallel)
3. App Service (needs plan), SQL Database (needs server)
4. Key Vault role assignment (needs App Service identity)
5. Post-deploy: run T-SQL as Entra admin to create a contained user for the app identity (`app-sdgweb01-dev`) with db_datareader/db_datawriter; store any needed secrets in Key Vault.

Notes:
- Deploying principal parameters (Entra admin login, object ID) are supplied at deploy time, not hard-coded.
- Connection string uses `Authentication=Active Directory Managed Identity`, so no password exists.
- Key Vault name is 15 chars (limit 24); SQL server name is globally unique, so verify availability.
- The SQL server needs the "Allow Azure services" firewall rule (0.0.0.0) for dev connectivity from App Service.

## Section 3 - Artifact Contract

| File | Purpose |
|---|---|
| `scenario/infra/main.bicep` | Bicep template (subscription scope) for all resources |
| `scenario/infra/main.bicepparam` | Parameter values |
| `scenario/azure.yaml` | azd project manifest |
| `scenario/deployment-summary.md` | Post-deployment record |
