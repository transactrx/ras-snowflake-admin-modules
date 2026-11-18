/**
---------------------------------------------------------------
  Example: a role with its warehouses (ras-snowflake-admin-serviceaccounts)

  WH_EXAMPLE_TAKEN_OVER states the four v2.2.0 fields, as a project taking a warehouse over from
  SnowflakeWHAdministration must (copied from SHOW WAREHOUSES). WH_EXAMPLE_NEW leaves them out and
  plans exactly as before v2.2.0. All five provider aliases are still required by the module.
---------------------------------------------------------------
**/
terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.21.0"
    }
  }
}

provider "snowflake" {
  role = "SYSADMIN"
}

provider "snowflake" {
  alias = "accountadmin"
  role  = "ACCOUNTADMIN"
}

provider "snowflake" {
  alias = "securityadmin"
  role  = "SECURITYADMIN"
}

provider "snowflake" {
  alias = "sysadmin"
  role  = "SYSADMIN"
}

provider "snowflake" {
  alias = "useradmin"
  role  = "USERADMIN"
}

locals {
  transactRxWarehouses = {
    WH_EXAMPLE_TAKEN_OVER = {
      name                = "WH_EXAMPLE_TAKEN_OVER"
      comment             = "Example warehouse taken over from another project"
      warehouse_size      = "x-Small"
      initially_suspended = false
      min_cluster_count   = 1
      max_cluster_count   = 10
      scaling_policy      = "STANDARD"
      warehouse_type      = "STANDARD"
      auto_suspend        = 60
      // Live values, so the import plans no UNSET.
      auto_resume                         = true
      enable_query_acceleration           = false
      query_acceleration_max_scale_factor = 8
      generation                          = "1"
    }
    WH_EXAMPLE_NEW = {
      name                = "WH_EXAMPLE_NEW"
      comment             = "Example warehouse created by this project"
      warehouse_size      = "x-Small"
      initially_suspended = true
      min_cluster_count   = 1
      max_cluster_count   = 1
      scaling_policy      = "STANDARD"
      warehouse_type      = "STANDARD"
      auto_suspend        = 60
    }
  }

  transactRxRoles = {
    EXAMPLE_LOADER = {
      name             = "EXAMPLE_LOADER"
      role_description = "Example service role"
      role_grants      = []
      database_role_grants = [
        { name = "DR_EXAMPLE_RO", database = "EXAMPLE_DB" }, // database roles must already exist
      ]
      warehouses = ["WH_EXAMPLE_TAKEN_OVER"]
      databases  = {}
    }
  }
}

module "snowflake_administration" {
  source = "../.."
  providers = {
    snowflake               = snowflake
    snowflake.accountadmin  = snowflake.accountadmin
    snowflake.securityadmin = snowflake.securityadmin
    snowflake.sysadmin      = snowflake.sysadmin
    snowflake.useradmin     = snowflake.useradmin
  }

  execute              = true
  transactRxWarehouses = local.transactRxWarehouses
  transactRxRoles      = local.transactRxRoles
  DEFAULT_EMAIL        = "example@example.com"
}
