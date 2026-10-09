resource "snowflake_storage_integration" "storage_int" {
  provider = snowflake.accountadmin
  for_each = var.execute ? var.transactRxStorageIntegrations : {}

  name                      = each.key
  comment                   = each.value.comment
  type                      = "EXTERNAL_STAGE"
  enabled                   = each.value.enabled
  storage_provider          = each.value.storage_provider
  storage_aws_role_arn      = each.value.storage_aws_role_arn
  storage_allowed_locations = each.value.storage_allowed_locations
  storage_blocked_locations = each.value.storage_blocked_locations

  lifecycle {
    create_before_destroy = true
  }
}

resource "snowflake_grant_privileges_to_account_role" "sysadmin_storage_integration" {
  provider          = snowflake.accountadmin
  for_each          = var.execute ? var.transactRxStorageIntegrations : {}
  account_role_name = "SYSADMIN"
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "INTEGRATION"
    object_name = each.key
  }

  depends_on = [snowflake_storage_integration.storage_int]
}

/**
  Additional USAGE grants on storage integrations to any extra account roles
  declared via each integration's optional `usage_roles`. Flattened to one grant
  per (integration, role) pair. Integrations that omit usage_roles produce none.
**/
locals {
  storageIntegrationUsageGrants = merge([
    for intName, int in var.transactRxStorageIntegrations : {
      for role in int.usage_roles : "${intName}|${role}" => {
        integration = intName
        role        = role
      }
    }
  ]...)
}

resource "snowflake_grant_privileges_to_account_role" "additional_usage_storage_integration" {
  provider          = snowflake.accountadmin
  for_each          = var.execute ? local.storageIntegrationUsageGrants : {}
  account_role_name = each.value.role
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "INTEGRATION"
    object_name = each.value.integration
  }

  depends_on = [snowflake_storage_integration.storage_int]
}
