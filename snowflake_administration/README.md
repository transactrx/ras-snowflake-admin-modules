# Snowflake Administration Module

The account-level administration module used by `SnowflakeWHAdministration`, published here so the split `ras-snowflake-admin-*` projects share one versioned copy. It creates users, service accounts, account roles, database roles, warehouses, compute pools, resource monitors, integrations, alerts and procedures from plain HCL maps.

This started as a copy of `SnowflakeWHAdministration/snowflake_administration` at commit `c501207`, with these deliberate differences:

- `transactRxUsers[*].isCreateUserDatabase` defaults to `false`. It was `optional(bool)` but used directly as a condition, so leaving it out failed.
- **No password support.** `isPasswordEnabled` and `DEFAULT_PASSWORD` are gone; users authenticate by SSO, key pair or WIF. The module never sets a password, and `ignore_changes` keeps it from removing one a user already has (break-glass).

`SnowflakeWHAdministration` still uses its own local copy. Until it switches to this source, keep the two in step.

**`v1.1.0` is in step with `SnowflakeWHAdministration` `Production` at `e2be81f` (2026-11-09).** It brings over every change SWA made to its module since `c501207`, keeping the differences above:

- `futureOwnership` on schemas in `transactRxRoles` and `transactRxDatabaseRoles`: the role or database role owns FUTURE objects of those types in the schema (SWA #1119).
- `network_policy` on `transactRxUsers`: the user's own network policy.
- JavaScript procedures no longer use `create_before_destroy` (a same-name replacement always failed with `002002`), and alerts no longer `depends_on` them.
- The `PHI_RESTRICTED` marker role SWA added and then removed is not included.

**`v2.0.0` (MAJOR) clears the provider's deprecation warnings and fixes `login_name`.** It differs further from SWA's copy:

- **Storage integrations use `snowflake_storage_integration_aws`**, not the deprecated `snowflake_storage_integration`. The address type changes, so a project taking over an integration from SWA imports it at the new address and SWA removes the old one from state; the handoff is also the type change. New optional inputs `storage_aws_external_id`, `storage_aws_object_acl` and `use_privatelink_endpoint`; `storage_provider` defaults to `S3` and must be `S3`, `S3GOV` or `S3CHINA`; `comment` is optional; `create_before_destroy` is gone. When taking one over, copy `storage_aws_external_id` and `use_privatelink_endpoint` from `DESC INTEGRATION`: the first is what AWS trust policies match on and is not Computed, and leaving out the second plans `"false" -> "default"`.
- **Streamlit support is removed**: `transactRxStreamlits`, `STREAMLITS_ROOT` and `SNOW_SQL_CONNECTION_NAME`, the deprecated `snowflake_stage` and the SnowSQL `local-exec` upload. SWA manages no Streamlits, and the upload needs SnowSQL on the runner. The module no longer uses the `hashicorp/null` provider.
- **`login_name` reaches the resource** on users and service accounts. It was a required input that was never passed, so taking over an existing user planned `login_name -> null` (an `UNSET LOGIN_NAME`). Login names compare case-insensitively.

## Versions

Callers pin a tag, never `main`: `?ref=snowflake_administration-v<MAJOR>.<MINOR>.<PATCH>`. Bump MAJOR when a change can alter what an existing caller plans (a renamed input, a changed default); MINOR for a new optional input or resource type; PATCH for fixes that plan no differently. `v1.0.0` is the first tag; `v1.1.0` (MINOR: new optional inputs and resources, nothing an existing caller plans differently) follows it. `v2.0.0` is MAJOR: a resource type changes and inputs are removed (none of which any caller used at release).

**Bumping to `v2.0.0`:** regenerate the caller's lock file in the same change (`rm .terraform.lock.hcl && terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`). The module no longer needs `hashicorp/null`, so a lock file that still lists it fails `terraform init -lockfile=readonly`.

## Usage

### Users-only project

```hcl
module "snowflake_administration" {
  source = "git::https://github.com/transactrx/ras-snowflake-admin-modules.git//snowflake_administration?ref=snowflake_administration-v2.0.0"
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

Every map you leave out defaults to `{}`, so nothing else is created. Full working callers are in [examples/users-only](./examples/users-only/main.tf) and [examples/platform-storage](./examples/platform-storage/main.tf) (a storage integration and a service account).

### Things a caller must know

- **`execute = true` is required.** It defaults to `false`, and with `false` the module creates nothing.
- **All five providers must be passed:** default, `accountadmin`, `securityadmin`, `sysadmin` and `useradmin`, even if the project uses only some of them. Terraform requires every alias the module declares.
- **Roles in a user's `roles` list must already exist.** Role grants come from each user's own `roles` list, not from `transactRxRoles`. A project that passes only users grants existing roles and creates none.
- **`isCreateUserDatabase = true` also creates a personal `UR_<name>` role and `DB_<name>` database** for that user, and makes the role the user's default.
- **A user's `network_policy` is managed on the user object.** Leaving it out (`null`) means the user follows the account-level policy, and an apply removes any user-level policy the user already has. When taking over an existing user, set `network_policy` to the policy they hold today.
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
| `transactRxStorageIntegrations` | map(object) | `{}` | AWS storage integrations (`snowflake_storage_integration_aws`) and usage grants |
| `transactRxAlerts` | map(object) | `{}` | Alerts |
| `transactRxProcedures` | map(object) | `{}` | JavaScript procedures |
| `transactRxSqlProcedures` | map(object) | `{}` | SQL procedures |
| `ADMIN_ACCOUNTS` | list(string) | `[]` | Not used by any resource; kept so existing callers still work |
| `DEFAULT_EMAIL` | string | `""` | Fallback e-mail for users with an empty `email` |
| `DEFAULT_ROLE` | string | `READ_ONLY` | Role granted to personal `UR_` roles |
| `USER_ROLE_PREFIX` | string | `UR_` | Prefix for personal roles |
| `USER_DATABASE_PREFIX` | string | `DB_` | Prefix for personal databases |
| `OWNER_ROLE_WAREHOUSES` | string | `SYSADMIN` | Warehouse owner |
| `OWNER_ROLE_COMPUTE_POOLS` | string | `SYSADMIN` | Compute pool owner |

The full object shape of each map is in [variables.tf](./variables.tf).

## Moving existing objects into a new project

Pointing a new project at this module does not move anything by itself. If a user already exists in `SnowflakeWHAdministration` state, the new project must take it over through state moves or imports, and the old project must stop managing it in the same change. Two projects must never manage the same object. The plan for that order lives in `SnowflakeWHAdministration/docs/refactor_plan/`.
