resource "snowflake_resource_monitor" "monitor" {
  depends_on = [
    snowflake_warehouse.warehouse
  ]
  for_each = var.execute ? var.transactRxMonitors : {}
  name     = each.key

  // These were hardcoded (quota 100, triggers [40,50], ADMIN_ACCOUNTS) while every per-monitor value
  // in transactrx_monitors.tf was silently ignored. They now come from the definition.
  credit_quota    = each.value.credit_quota
  notify_triggers = each.value.notify_triggers
  notify_users    = each.value.notify_users

  // frequency is deliberately not set: the provider requires frequency and start_timestamp together,
  // and Snowflake's default (MONTHLY, aligned to the billing month) is what these quotas are sized
  // for. Set both here if a monitor ever needs a different cycle.

  // Unset on every monitor today: notify-only. See the variable's comment before setting either.
  suspend_trigger           = each.value.suspend_trigger
  suspend_immediate_trigger = each.value.suspend_immediate_trigger

  // `warehouses` is not an attribute of this resource in provider 2.x; the association is set on the
  // warehouse instead. See local.monitorByWarehouse in resources_warehouse.tf.

  lifecycle {
    create_before_destroy = true
  }
}
