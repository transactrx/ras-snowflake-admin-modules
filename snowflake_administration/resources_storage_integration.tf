/**
---------------------------------------------------------------
    Storage integrations (AWS)

    snowflake_storage_integration_aws, not the deprecated snowflake_storage_integration (provider 2.21.0
    directs callers to the per-cloud resources). Only S3 is supported here; every integration in
    SnowflakeWHAdministration is S3.

    Taking over an integration from SnowflakeWHAdministration: import it at this address (its type there
    is the deprecated resource, so the handoff is also the type change) and copy these from
    DESC INTEGRATION, never retype them:
      - storage_aws_external_id: Snowflake generates it at CREATE and never rotates it, and AWS trust
        policies match on it (sts:ExternalId). It is Optional and not Computed, so leaving it out does
        not keep it.
      - use_privatelink_endpoint: the schema default is the sentinel "default", but import writes the
        live "true"/"false" into state. Leave it out and every adopted integration plans
        "false" -> "default".
    comment, storage_blocked_locations and storage_aws_object_acl round-trip as null when empty live.

    No create_before_destroy: a replacement cannot create a second integration with the same name, and
    a replaced integration gets a new external ID and IAM user, so every stage on it stops until the
    AWS trust policy is updated.
---------------------------------------------------------------
**/
resource "snowflake_storage_integration_aws" "storage_int" {
  provider = snowflake.accountadmin
  for_each = var.execute ? var.transactRxStorageIntegrations : {}

  name                      = each.key
  comment                   = each.value.comment
  enabled                   = each.value.enabled
  storage_provider          = each.value.storage_provider
  storage_aws_role_arn      = each.value.storage_aws_role_arn
  storage_aws_external_id   = each.value.storage_aws_external_id
  storage_aws_object_acl    = each.value.storage_aws_object_acl
  use_privatelink_endpoint  = each.value.use_privatelink_endpoint
  storage_allowed_locations = each.value.storage_allowed_locations
  storage_blocked_locations = each.value.storage_blocked_locations
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

  depends_on = [snowflake_storage_integration_aws.storage_int]
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

  depends_on = [snowflake_storage_integration_aws.storage_int]
}
