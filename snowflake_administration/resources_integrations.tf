resource "snowflake_email_notification_integration" "email_int" {
  for_each = var.execute ? var.transactRxEmailIntegrations : {}
  name     = each.key
  comment  = each.value.comment
  enabled  = each.value.enabled
  # lower(): Snowflake stores recipient addresses lowercase, so any other casing in the
  # input lists shows up as drift on every plan. Normalizing here converges regardless
  # of how the addresses are typed in the variables.
  allowed_recipients = [for r in each.value.allowed_recipients : lower(r)]

  lifecycle {
    create_before_destroy = true
  }
}

resource "snowflake_notification_integration" "notification_int" {
  for_each              = var.execute ? var.transactRxNotificationIntegrations : {}
  name                  = each.key
  comment               = each.value.comment
  enabled               = each.value.enabled
  notification_provider = each.value.notification_provider
  aws_sns_topic_arn     = each.value.aws_sns_topic_arn
  aws_sns_role_arn      = each.value.aws_sns_role_arn

  lifecycle {
    create_before_destroy = true
  }
}
