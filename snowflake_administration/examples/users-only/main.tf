/**
---------------------------------------------------------------
  Example: a Users-only root (ras-snowflake-admin-users)

  Only transactRxUsers is passed; every other map defaults to {}.
  All five provider aliases are still required by the module.
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
  role = "ACCOUNTADMIN"
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
  transactRxUsers = {
    JDOE = {
      login_name        = "JDOE"
      index             = 1
      disabled          = false
      display_name      = "Jane Doe"
      email             = "jane.doe@redsailtechnologies.com"
      first_name        = "Jane"
      last_name         = "Doe"
      comment           = "Example user"
      default_warehouse = "COMPUTE_WH"
      default_role      = "READ_ONLY"
      roles             = ["READ_ONLY"] // roles must already exist; this module does not create them here
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

  execute         = true
  transactRxUsers = local.transactRxUsers
  DEFAULT_EMAIL   = "rasdataservices@redsailtechnologies.com"
}
