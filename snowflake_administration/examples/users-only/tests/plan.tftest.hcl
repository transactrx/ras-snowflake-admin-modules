# Mocked plan: no Snowflake login needed. Run before cutting a tag.
mock_provider "snowflake" {}
mock_provider "snowflake" { alias = "accountadmin" }
mock_provider "snowflake" { alias = "securityadmin" }
mock_provider "snowflake" { alias = "sysadmin" }
mock_provider "snowflake" { alias = "useradmin" }

run "plan" {
  command = plan

  # Users only: every other map defaults to {}, so only the user's three resources plan.
  assert {
    condition     = length(module.snowflake_administration.local_schemas) == 0
    error_message = "a users-only call must not plan any role schema grants"
  }
}
