# Mocked plan at the module root, so the assertions can read the module's own resources (a test in an example can
# only read the module's outputs). No Snowflake login needed. Run before cutting a tag.
mock_provider "snowflake" {}
mock_provider "snowflake" { alias = "accountadmin" }
mock_provider "snowflake" { alias = "securityadmin" }
mock_provider "snowflake" { alias = "sysadmin" }
mock_provider "snowflake" { alias = "useradmin" }

variables {
  execute       = true
  DEFAULT_EMAIL = "example@example.com"
  transactRxWarehouses = {
    WH_EXAMPLE_TAKEN_OVER = {
      name                                = "WH_EXAMPLE_TAKEN_OVER"
      comment                             = "taken over"
      warehouse_size                      = "x-Small"
      initially_suspended                 = false
      min_cluster_count                   = 1
      max_cluster_count                   = 10
      scaling_policy                      = "STANDARD"
      warehouse_type                      = "STANDARD"
      auto_suspend                        = 60
      auto_resume                         = true
      enable_query_acceleration           = false
      query_acceleration_max_scale_factor = 8
      generation                          = "1"
    }
    WH_EXAMPLE_NEW = {
      name                = "WH_EXAMPLE_NEW"
      comment             = "new"
      warehouse_size      = "x-Small"
      initially_suspended = true
      min_cluster_count   = 1
      max_cluster_count   = 1
      scaling_policy      = "STANDARD"
      warehouse_type      = "STANDARD"
      auto_suspend        = 60
    }
  }
}

run "warehouse_v2_2_0_fields" {
  command = plan

  # A taken-over warehouse carries its stated values to the resource.
  assert {
    condition     = snowflake_warehouse.warehouse["WH_EXAMPLE_TAKEN_OVER"].generation == "1"
    error_message = "generation must reach the resource"
  }
  assert {
    condition     = snowflake_warehouse.warehouse["WH_EXAMPLE_TAKEN_OVER"].auto_resume == "true"
    error_message = "auto_resume must reach the resource as \"true\""
  }
  assert {
    condition     = snowflake_warehouse.warehouse["WH_EXAMPLE_TAKEN_OVER"].enable_query_acceleration == "false"
    error_message = "enable_query_acceleration must reach the resource as \"false\""
  }
  assert {
    condition     = snowflake_warehouse.warehouse["WH_EXAMPLE_TAKEN_OVER"].query_acceleration_max_scale_factor == 8
    error_message = "query_acceleration_max_scale_factor must reach the resource"
  }

  # A warehouse that leaves them out passes null, the same config value as before v2.2.0 (when the module did not set
  # them); the real provider then applies its "default" / -1 sentinels. A mock provider applies no schema defaults.
  assert {
    condition     = snowflake_warehouse.warehouse["WH_EXAMPLE_NEW"].auto_resume == null
    error_message = "an omitted auto_resume must stay null"
  }
  assert {
    condition     = snowflake_warehouse.warehouse["WH_EXAMPLE_NEW"].enable_query_acceleration == null
    error_message = "an omitted enable_query_acceleration must stay null"
  }
  assert {
    condition     = snowflake_warehouse.warehouse["WH_EXAMPLE_NEW"].query_acceleration_max_scale_factor == null
    error_message = "an omitted query_acceleration_max_scale_factor must stay null"
  }
  assert {
    condition     = snowflake_warehouse.warehouse["WH_EXAMPLE_NEW"].generation == null
    error_message = "an omitted generation must stay unset"
  }
}
