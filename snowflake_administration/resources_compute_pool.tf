/**
---------------------------------------------------------------
   Create Compute Pools (As AccountAdmin)

   NOTE: CREATE COMPUTE POOL is an account-level privilege that
         SYSADMIN does not hold by default, so this uses the
         module's default (accountadmin) provider. Ownership is
         handed to SYSADMIN below, mirroring the warehouses.

   NOTE: A compute pool is Snowpark Container Services compute --
         it runs containers, not SQL. Its nodes bill per-second on
         a separate meter from warehouse credits, so warehouse
         resource monitors do NOT restrain it.
---------------------------------------------------------------
**/
resource "snowflake_compute_pool" "compute_pool" {
  for_each = var.execute ? var.transactRxComputePools : {}

  name            = each.key
  comment         = each.value.comment
  instance_family = each.value.instance_family
  min_nodes       = each.value.min_nodes
  max_nodes       = each.value.max_nodes

  auto_suspend_secs   = each.value.auto_suspend_secs
  auto_resume         = each.value.auto_resume
  initially_suspended = each.value.initially_suspended
}

/**
------------------------------------------------------------------------------------------------------
  Grant Ownership of Compute Pools to SysAdmin
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_ownership" "grant_ownership_compute_pool_to_sysadmin" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_compute_pool.compute_pool
  ]

  for_each            = var.execute ? var.transactRxComputePools : {}
  account_role_name   = var.OWNER_ROLE_COMPUTE_POOLS
  outbound_privileges = "COPY"
  on {
    object_type = "COMPUTE POOL"
    object_name = each.key
  }
}

/**
---------------------------------------------------------------
   Grant Compute Pools to Roles

   Snowflake grants privileges to ROLES only -- a compute pool
   cannot be granted to a user directly.
---------------------------------------------------------------
**/
locals {
  rolesByComputePool = flatten([
    for name_role, role in var.transactRxRoles : [
      for compute_pool in role.compute_pools : {
        name_role         = name_role
        name_compute_pool = compute_pool
        privileges        = role.compute_pool_privileges
      }
    ]
  ])
}

resource "snowflake_grant_privileges_to_account_role" "compute_pool_grants" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_compute_pool.compute_pool,
    snowflake_account_role.transactRxRoles
  ]

  for_each = var.execute ? {
    for grant in local.rolesByComputePool : "${grant.name_role}-${grant.name_compute_pool}" => grant
    if length(grant.privileges) > 0
  } : {}

  account_role_name = each.value.name_role
  on_account_object {
    object_type = "COMPUTE POOL"
    object_name = each.value.name_compute_pool
  }
  privileges = each.value.privileges

  with_grant_option = false
}
