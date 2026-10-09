# Owner = SYSADMIN (2026-09-09, CIS 1.16/1.17). The remaining JavaScript procedure (SEND_DISCREPANT_OBJECTS_NOTIFICATION)
# only reads CPE_DEV / CPE_PROD INFORMATION_SCHEMA and calls SYSTEM$SEND_EMAIL through TASK_FAILED_EMAIL_INTEGRATION,
# which SYSADMIN is granted USAGE on (transactrx_email_integrations.tf). Ownership of the live object was moved by hand.
resource "snowflake_procedure_javascript" "procedures" {
  provider = snowflake.sysadmin
  for_each = var.execute ? var.transactRxProcedures : {}

  name                 = each.key
  database             = each.value.database
  schema               = each.value.schema
  comment              = each.value.comment
  return_type          = each.value.return_type
  execute_as           = each.value.execute_as
  procedure_definition = each.value.procedure_definition

  lifecycle {
    create_before_destroy = true
  }
}
