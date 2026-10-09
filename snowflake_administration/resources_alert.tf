resource "snowflake_alert" "alerts" {
  for_each = var.execute ? var.transactRxAlerts : {}

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
