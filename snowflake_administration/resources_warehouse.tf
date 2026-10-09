/**
---------------------------------------------------------------
   Create Warehouses (As Security Admin)
---------------------------------------------------------------
**/
locals {
  // Invert the monitors' warehouse lists into warehouse name -> monitor name. The monitor
  // definitions stay the single source of truth, and no warehouse definition has to name a monitor.
  // While local.monitorList is empty this map is empty, every lookup below returns null, and the
  // warehouses plan exactly as they do today.
  monitorByWarehouse = {
    for pair in flatten([
      for _, monitor in var.transactRxMonitors : [
        for warehouse in monitor.warehouses : { warehouse = warehouse, monitor = monitor.name }
      ]
    ]) : pair.warehouse => pair.monitor
  }
}

resource "snowflake_warehouse" "warehouse" {
  provider            = snowflake.sysadmin
  for_each            = var.execute ? var.transactRxWarehouses : {}
  name                = each.key
  comment             = each.value.comment
  warehouse_size      = each.value.warehouse_size
  initially_suspended = each.value.initially_suspended
  min_cluster_count   = each.value.min_cluster_count
  max_cluster_count   = each.value.max_cluster_count
  scaling_policy      = each.value.scaling_policy
  warehouse_type      = each.value.warehouse_type
  auto_suspend        = each.value.auto_suspend

  // null unless a monitor in transactrx_monitors.tf claims this warehouse.
  resource_monitor = lookup(local.monitorByWarehouse, each.key, null)

  lifecycle {
    create_before_destroy = true
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Ownership to Warehouse to SysAdmin
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_ownership" "grant_ownership_warehouse_to_sysadmin" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_warehouse.warehouse
  ]

  for_each            = var.execute ? var.transactRxWarehouses : {}
  account_role_name   = var.OWNER_ROLE_WAREHOUSES
  outbound_privileges = "COPY"
  on {
    object_type = "WAREHOUSE"
    object_name = each.key
  }
}

/**
---------------------------------------------------------------
   Grant Warehouse to Roles
---------------------------------------------------------------
**/

locals {
  rolesByWarehouse = flatten([
    for name_role, role in var.transactRxRoles : [
      for warehouse in role.warehouses : {
        name_role      = name_role
        name_warehouse = warehouse
        privileges     = role.warehouse_privileges
      }
    ]
  ])
}

resource "snowflake_grant_privileges_to_account_role" "warehouse_grants" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_warehouse.warehouse,
    snowflake_account_role.transactRxRoles
  ]

  for_each = var.execute ? {
    for role in local.rolesByWarehouse : "${role.name_role}-${role.name_warehouse}" => role
  } : {}

  account_role_name = each.value.name_role
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = each.value.name_warehouse
  }
  privileges = each.value.privileges

  with_grant_option = false
}
