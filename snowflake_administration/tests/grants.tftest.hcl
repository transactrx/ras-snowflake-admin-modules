# Mocked plan at the module root: "ALL PRIVILEGES" in a privileges list is sent as all_privileges = true (v2.3.0),
# any other list is passed through unchanged. No Snowflake login needed. Run before cutting a tag.
mock_provider "snowflake" {}
mock_provider "snowflake" { alias = "accountadmin" }
mock_provider "snowflake" { alias = "securityadmin" }
mock_provider "snowflake" { alias = "sysadmin" }
mock_provider "snowflake" { alias = "useradmin" }

variables {
  execute       = true
  DEFAULT_EMAIL = "example@example.com"
  transactRxRoles = {
    ROLE_EXAMPLE = {
      name             = "ROLE_EXAMPLE"
      role_grants      = []
      role_description = "example"
      warehouses       = []
      databases = {
        DB_EXAMPLE = {
          privileges               = ["USAGE"]
          schema_privileges_future = []
          schema_privileges_all    = []
          schemas = {
            ALL_SCHEMA = {
              privileges    = ["ALL PRIVILEGES"]
              allObjects    = { TABLES = { privileges = ["ALL PRIVILEGES"] } }
              futureObjects = { TABLES = { privileges = ["ALL PRIVILEGES"] } }
              targetObjects = {}
            }
            LIST_SCHEMA = {
              privileges    = ["USAGE", "MONITOR"]
              allObjects    = { TABLES = { privileges = ["SELECT", "INSERT"] } }
              futureObjects = {}
              targetObjects = {}
            }
          }
        }
      }
    }
  }
  transactRxDatabaseRoles = {
    DR_EXAMPLE_RW = {
      name                = "DR_EXAMPLE_RW"
      database            = "DB_EXAMPLE"
      comment             = "example"
      database_privileges = ["USAGE"]
      schemas = {
        ALL_SCHEMA = {
          privileges    = ["USAGE"]
          allObjects    = { TABLES = { privileges = ["ALL PRIVILEGES"] } }
          futureObjects = {}
          targetObjects = {}
        }
      }
    }
  }
}

run "all_privileges_v2_3_0" {
  command = plan

  # "ALL PRIVILEGES" becomes all_privileges = true with no list, which is how the provider reads such a grant back
  # on import. Sent as a list, the import plans all_privileges true -> false: a REVOKE ALL, then GRANT ALL PRIVILEGES.
  assert {
    condition     = snowflake_grant_privileges_to_account_role.target_schema_grants["ROLE_EXAMPLE-DB_EXAMPLE-ALL_SCHEMA"].all_privileges == true
    error_message = "a schema grant of ALL PRIVILEGES must set all_privileges"
  }
  assert {
    condition     = snowflake_grant_privileges_to_account_role.target_schema_grants["ROLE_EXAMPLE-DB_EXAMPLE-ALL_SCHEMA"].privileges == null
    error_message = "a schema grant of ALL PRIVILEGES must send no privileges list"
  }
  assert {
    condition     = snowflake_grant_privileges_to_account_role.schema_object_grants_all["ROLE_EXAMPLE-DB_EXAMPLE-ALL_SCHEMA-TABLES"].all_privileges == true
    error_message = "an all-objects grant of ALL PRIVILEGES must set all_privileges"
  }
  assert {
    condition     = snowflake_grant_privileges_to_account_role.schema_object_grants_future["ROLE_EXAMPLE-DB_EXAMPLE-ALL_SCHEMA-TABLES"].all_privileges == true
    error_message = "a future-objects grant of ALL PRIVILEGES must set all_privileges"
  }
  assert {
    condition     = snowflake_grant_privileges_to_database_role.schema_object_grants_all["DR_EXAMPLE_RW-ALL_SCHEMA-TABLES"].all_privileges == true
    error_message = "a database role grant of ALL PRIVILEGES must set all_privileges"
  }

  # Any other list passes through as before v2.3.0, with all_privileges left null, so existing callers plan no
  # differently.
  assert {
    condition     = toset(snowflake_grant_privileges_to_account_role.target_schema_grants["ROLE_EXAMPLE-DB_EXAMPLE-LIST_SCHEMA"].privileges) == toset(["USAGE", "MONITOR"])
    error_message = "a privilege list must reach the resource unchanged"
  }
  assert {
    condition     = snowflake_grant_privileges_to_account_role.target_schema_grants["ROLE_EXAMPLE-DB_EXAMPLE-LIST_SCHEMA"].all_privileges == null
    error_message = "a privilege list must leave all_privileges null"
  }
  assert {
    condition     = toset(snowflake_grant_privileges_to_account_role.schema_object_grants_all["ROLE_EXAMPLE-DB_EXAMPLE-LIST_SCHEMA-TABLES"].privileges) == toset(["SELECT", "INSERT"])
    error_message = "an all-objects privilege list must reach the resource unchanged"
  }
  assert {
    condition     = toset(snowflake_grant_privileges_to_account_role.database_grants["ROLE_EXAMPLE-DB_EXAMPLE"].privileges) == toset(["USAGE"])
    error_message = "a database privilege list must reach the resource unchanged"
  }
}
