---
paths:
  - "**/*.bicep"
  - "**/*.bicepparam"
---
# Bicep Development Standards

## Scope
- `main.bicep` uses `targetScope = 'subscription'`, creates the resource group, and deploys every other resource as a module with `scope: rg`. This is what `azd provision` expects.

## Module Priority
1. Use Azure Verified Modules (AVM) first: `br/public:avm/res/<provider>/<resource>:<version>`.
2. Pin an exact version. Never invent one: if `az bicep build` fails to restore a module, pick an older published version.
3. Fall back to a native `resource` block only when no AVM module exists.

## Security Defaults
- `httpsOnly: true` on all App Service resources.
- Minimum TLS 1.2 on all web, SQL and storage resources.
- `SystemAssigned` managed identity on every App Service.
- Grant identities access with RBAC `roleAssignments`. No connection strings or passwords in `appSettings`.

## Parameters and Outputs
- Top-level parameters with `@description`: `workloadName`, `environment`, `location`, `sqlAdminLogin`, `sqlAdminObjectId`.
- Never hard-code subscription IDs, tenant IDs, resource group names or passwords.
- Output at minimum: `AZURE_RESOURCE_GROUP`, the App Service default hostname, and the Key Vault URI.

## Structure
- One `main.bicep` for six resources or fewer, always paired with `main.bicepparam`.
- After writing a Bicep file, it must compile cleanly with `az bicep build`.
