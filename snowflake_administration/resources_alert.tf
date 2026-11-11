resource "snowflake_alert" "alerts" {
  provider = snowflake.accountadmin
  for_each = var.execute ? var.transactRxAlerts : {}

  # An alert's action can CALL a module procedure (ALERT_PMS_SHARE_METADATA) by name, as a string. There is
  # deliberately no depends_on on snowflake_procedure_javascript.procedures: this resource has create_before_destroy,
  # which Terraform forces onto everything it depends on, and a same-name procedure cannot be created before its old
  # copy is dropped (resource_procedure.tf).

  name      = each.key
  database  = each.value.database
  schema    = each.value.schema
  warehouse = each.value.warehouse
  enabled   = each.value.enabled
  comment   = each.value.comment
  condition = each.value.condition
  action    = each.value.action


  alert_schedule {
    cron {
      expression = each.value.cron
      time_zone  = each.value.timezone
    }

    # interval = each.value.interval    
  }

  lifecycle {
    create_before_destroy = true
  }
}
