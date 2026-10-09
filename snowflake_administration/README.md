# Snowflake Administration Module

The account-level administration module used by `SnowflakeWHAdministration`, published here so the split `ras-snowflake-admin-*` projects share one versioned copy. It creates users, service accounts, account roles, database roles, warehouses, compute pools, resource monitors, integrations, alerts, procedures and Streamlits from plain HCL maps.

This started as a copy of `SnowflakeWHAdministration/snowflake_administration` at commit `c501207`, with these deliberate differences:

- `transactRxStreamlits` defaults to `{}` (it was the only map without a default).
- `transactRxUsers[*].isCreateUserDatabase` defaults to `false`. It was `optional(bool)` but used directly as a condition, so leaving it out failed.
- **No password support.** `isPasswordEnabled` and `DEFAULT_PASSWORD` are gone; users authenticate by SSO, key pair or WIF. The module never sets a password, and `ignore_changes` keeps it from removing one a user already has (break-glass).

`SnowflakeWHAdministration` still uses its own local copy. Until it switches to this source, keep the two in step.

## Versions

Callers pin a tag, never `main`: `?ref=snowflake_administration-v<MAJOR>.<MINOR>.<PATCH>`. Bump MAJOR when a change can alter what an existing caller plans (a renamed input, a changed default); MINOR for a new optional input or resource type; PATCH for fixes that plan no differently. `v1.0.0` is the first tag to cut.

## Usage

### Users-only project

```hcl
module "snowflake_administration" {
  source = "git::https://github.com/transactrx/ras-snowflake-admin-modules.git//snowflake_administration?ref=snowflake_administration-v1.0.0"
  providers = {
    snowflake               = snowflake
    snowflake.accountadmin  = snowflake.accountadmin
    snowflake.securityadmin = snowflake.securityadmin
    snowflake.sysadmin      = snowflake.sysadmin
    snowflake.useradmin     = snowflake.useradmin
  }

  execute         = true
  transactRxUsers = local.transactRxUsers
  DEFAULT_EMAIL   = var.DEFAULT_EMAIL
}
```

Every map you leave out defaults to `{}`, so nothing else is created. A full working caller is in [examples/users-only](./examples/users-only/main.tf).

### Things a caller must know

- **`execute = true` is required.** It defaults to `false`, and with `false` the module creates nothing.
- **All five providers must be passed:** default, `accountadmin`, `securityadmin`, `sysadmin` and `useradmin`, even if the project uses only some of them. Terraform requires every alias the module declares.
- **Roles in a user's `roles` list must already exist.** Role grants come from each user's own `roles` list, not from `transactRxRoles`. A project that passes only users grants existing roles and creates none.
- **`isCreateUserDatabase = true` also creates a personal `UR_<name>` role and `DB_<name>` database** for that user, and makes the role the user's default.
- **Provider version:** `snowflakedb/snowflake ~> 2.21.0`.

## Inputs

| Name | Type | Default | Creates |
|---|---|---|---|
| `execute` | bool | `false` | Master switch; must be `true` |
| `transactRxUsers` | map(object) | `{}` | Human users, ownership to USERADMIN, role grants, optional personal role and database |
| `transactRxServiceAccounts` | map(object) | `{}` | Service users and their role grants |
| `transactRxRoles` | map(object) | `{}` | Account roles plus their warehouse, integration, database and schema grants |
| `transactRxDatabaseRoles` | map(object) | `{}` | Database roles plus their grants |
| `transactRxWarehouses` | map(object) | `{}` | Warehouses |
| `transactRxComputePools` | map(object) | `{}` | Compute pools |
| `transactRxMonitors` | map(object) | `{}` | Resource monitors |
| `transactRxEmailIntegrations` | map(object) | `{}` | Email notification integrations |
| `transactRxNotificationIntegrations` | map(object) | `{}` | Notification integrations |
| `transactRxStorageIntegrations` | map(object) | `{}` | Storage integrations and usage grants |
| `transactRxAlerts` | map(object) | `{}` | Alerts |
| `transactRxProcedures` | map(object) | `{}` | JavaScript procedures |
| `transactRxSqlProcedures` | map(object) | `{}` | SQL procedures |
| `transactRxStreamlits` | map(object) | `{}` | Streamlit apps |
| `ADMIN_ACCOUNTS` | list(string) | `[]` | Not used by any resource; kept so existing callers still work |
| `DEFAULT_EMAIL` | string | `""` | Fallback e-mail for users with an empty `email` |
| `DEFAULT_ROLE` | string | `READ_ONLY` | Role granted to personal `UR_` roles |
| `USER_ROLE_PREFIX` | string | `UR_` | Prefix for personal roles |
| `USER_DATABASE_PREFIX` | string | `DB_` | Prefix for personal databases |
| `OWNER_ROLE_WAREHOUSES` | string | `SYSADMIN` | Warehouse owner |
| `OWNER_ROLE_COMPUTE_POOLS` | string | `SYSADMIN` | Compute pool owner |
| `STREAMLITS_ROOT` | string | `./streamlits` | Streamlit source folder |
| `SNOW_SQL_CONNECTION_NAME` | string | `my_connection` | SnowSQL connection name |

The full object shape of each map is in [variables.tf](./variables.tf).

## Moving existing objects into a new project

Pointing a new project at this module does not move anything by itself. If a user already exists in `SnowflakeWHAdministration` state, the new project must take it over through state moves or imports, and the old project must stop managing it in the same change. Two projects must never manage the same object. The plan for that order lives in `SnowflakeWHAdministration/docs/refactor_plan/`.
