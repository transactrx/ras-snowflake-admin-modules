# Mocked plan: no Snowflake login needed. Run before cutting a tag.
mock_provider "snowflake" {}
mock_provider "snowflake" { alias = "accountadmin" }
mock_provider "snowflake" { alias = "securityadmin" }
mock_provider "snowflake" { alias = "sysadmin" }
mock_provider "snowflake" { alias = "useradmin" }

run "plan" {
  command = plan

  # One storage integration (snowflake_storage_integration_aws) with its SYSADMIN and usage_roles grants, and one
  # service account with its role grant. No role schema grants: transactRxRoles is not passed.
  assert {
    condition     = length(module.snowflake_administration.local_schemas) == 0
    error_message = "this example must not plan any role schema grants"
  }
}
