/**
---------------------------------------------------------------
  Example: storage integration and service account (ras-snowflake-admin-platform)

  Passes one AWS storage integration and one service account; every other map defaults to {}.
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
  transactRxStorageIntegrations = {
    EXAMPLE_S3_INT = {
      name                      = "EXAMPLE_S3_INT"
      enabled                   = true
      storage_aws_role_arn      = "arn:aws:iam::000000000000:role/example-snowflake-role"
      storage_allowed_locations = ["s3://example-bucket/inbound/"]
      // Copied from DESC INTEGRATION when taking over an existing integration; placeholders here.
      storage_aws_external_id  = "EXAMPLE_SFCRole=1_EXAMPLE="
      use_privatelink_endpoint = "false"
      usage_roles              = ["EXAMPLE_LOADER"]
    }
  }

  transactRxServiceAccounts = {
    SA_EXAMPLE = {
      login_name        = "SA_EXAMPLE"
      disabled          = false
      display_name      = "Example service account"
      email             = ""
      comment           = "Example service account"
      default_warehouse = "COMPUTE_WH"
      default_role      = "EXAMPLE_LOADER"
      roles             = ["EXAMPLE_LOADER"] // roles must already exist
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

  execute                       = true
  transactRxStorageIntegrations = local.transactRxStorageIntegrations
  transactRxServiceAccounts     = local.transactRxServiceAccounts
  DEFAULT_EMAIL                 = "example@example.com"
}
