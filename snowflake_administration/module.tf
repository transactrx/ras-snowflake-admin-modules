terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.21.0"
      configuration_aliases = [
        snowflake,
        snowflake.accountadmin,
        snowflake.securityadmin,
        snowflake.sysadmin,
        snowflake.useradmin
      ]
    }
  }
}
