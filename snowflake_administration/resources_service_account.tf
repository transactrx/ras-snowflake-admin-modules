/**
---------------------------------------------------------------
    Create Custom Service Account (As)
---------------------------------------------------------------
**/
resource "snowflake_service_user" "service_account" {
  provider = snowflake.useradmin
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]
  for_each = var.execute ? var.transactRxServiceAccounts : {}

  name                           = each.key
  comment                        = each.value.comment
  disabled                       = each.value.disabled
  display_name                   = each.value.display_name
  email                          = length(each.value.email) != 0 ? each.value.email : var.DEFAULT_EMAIL
  default_warehouse              = each.value.default_warehouse
  default_secondary_roles_option = coalesce(each.value.default_secondary_roles_option, "ALL")
  default_role                   = each.value.default_role
  rsa_public_key                 = lookup(each.value, "rsa_public_key", null)

  // AWS workload identity: emitted only for service accounts that carry an ARN. It coexists with
  // rsa_public_key, so adding one changes nothing until the service's driver switches to
  // authenticator = WORKLOAD_IDENTITY. Needs experimental_features_enabled on the useradmin provider.
  dynamic "default_workload_identity" {
    for_each = lookup(each.value, "workload_identity_aws_arn", null) == null ? [] : [each.value.workload_identity_aws_arn]
    content {
      aws {
        arn = default_workload_identity.value
      }
    }
  }
  #TODO: Add Support for 'default_namespace'   Examples ("CPE_DEV", "CPE_DEV.DATA")
  lifecycle {
    create_before_destroy = true
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Ownership to UserAdmin
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_ownership" "grant_ownership_service_account_to_useradmin" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_service_user.service_account
  ]
  for_each            = var.execute ? var.transactRxServiceAccounts : {}
  account_role_name   = "USERADMIN"
  outbound_privileges = "COPY"
  on {
    object_type = "USER"
    object_name = each.key
  }
}

/**
---------------------------------------------------------------
    Grant Roles To ServiceAccount (As)
---------------------------------------------------------------
**/
locals {
  serviceAccountByRole = flatten([
    for service_user_name, serviceAccount in var.transactRxServiceAccounts : [
      for role_name in serviceAccount.roles : {
        service_user_name = service_user_name
        role_name         = role_name
      }
    ]
  ])
}


resource "snowflake_grant_account_role" "grant_roles_to_service_account" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_service_user.service_account
  ]

  for_each = var.execute ? {
    for serviceAccount in local.serviceAccountByRole : "${serviceAccount.service_user_name}-${serviceAccount.role_name}" => serviceAccount
  } : {}
  user_name = each.value.service_user_name
  role_name = each.value.role_name
}


