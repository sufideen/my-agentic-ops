---
name: azure-ops-defaults
description: Shared naming, region, SKU and security defaults for Azure infrastructure provisioning. Use for any Azure architecture or Bicep work.
---
# Azure Operations Defaults

## Region
Default region: `uksouth`. Use `ukwest` only if the scenario asks for a paired/DR region or uksouth has no capacity.

## Naming Conventions
Follow Azure Cloud Adoption Framework (CAF) patterns. Workload name: 8 characters or fewer, lowercase letters and digits only. Environment: `dev`, `test` or `prod`.

| Resource | Pattern | Example |
|---|---|---|
| Resource group | `rg-{workload}-{env}` | `rg-sdgweb01-dev` |
| App Service plan | `asp-{workload}-{env}` | `asp-sdgweb01-dev` |
| App Service | `app-{workload}-{env}` | `app-sdgweb01-dev` |
| SQL Server | `sql-{workload}-{env}` | `sql-sdgweb01-dev` |
| SQL Database | `sqldb-{workload}-{env}` | `sqldb-sdgweb01-dev` |
| Key Vault | `kv-{workload}-{env}` | `kv-sdgweb01-dev` |

## Security Baseline
- TLS: minimum TLS 1.2 on all public endpoints.
- HTTPS: `httpsOnly: true` on every App Service.
- Authentication: managed identity for service-to-service access. Never store passwords or connection strings in app settings.
- Key Vault: RBAC authorisation (`Key Vault Secrets User` role), not access policies. Soft delete on.
- SQL: Entra ID-only authentication (`azureADOnlyAuthentication: true`). The deploying user is the Entra admin. No SQL admin password anywhere.

## Default SKUs
| Service | Development | Production |
|---|---|---|
| App Service plan | B1 (Linux) | P1v3 (Linux) |
| SQL Database | Basic (5 DTU) | S1 (20 DTU) |
| Key Vault | Standard | Standard |
