# Mocked plan: no Snowflake login needed. Run before cutting a tag.
# The field-by-field assertions for the v2.2.0 warehouse inputs live in ../../tests/warehouse.tftest.hcl (module root).
mock_provider "snowflake" {}
mock_provider "snowflake" { alias = "accountadmin" }
mock_provider "snowflake" { alias = "securityadmin" }
mock_provider "snowflake" { alias = "sysadmin" }
mock_provider "snowflake" { alias = "useradmin" }

run "plan" {
  command = plan

  # One role with its warehouse grant and database-role membership, two warehouses. No role schema grants.
  assert {
    condition     = length(module.snowflake_administration.local_schemas) == 0
    error_message = "this example must not plan any role schema grants"
  }
}
