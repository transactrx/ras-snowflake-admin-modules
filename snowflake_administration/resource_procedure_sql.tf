/**
  SQL procedures come in as a single map (var.transactRxSqlProcedures). Terraform cannot select
  a provider dynamically, and the provider role determines the procedure's OWNER, so the map is
  split by each definition's `owner` and one resource block per owner consumes its slice.

  Supported owners are validated on the variable. Adding a new owner requires a matching
  resource block below.
**/
locals {
  sqlProceduresBySysadmin = {
    for procKey, proc in var.transactRxSqlProcedures : procKey => proc
    if upper(proc.owner) == "SYSADMIN"
  }

  sqlProceduresByAccountadmin = {
    for procKey, proc in var.transactRxSqlProcedures : procKey => proc
    if upper(proc.owner) == "ACCOUNTADMIN"
  }
}

resource "snowflake_procedure_sql" "procedures" {
  provider = snowflake.sysadmin
  for_each = var.execute ? local.sqlProceduresBySysadmin : {}

  name                 = each.value.name
  database             = each.value.database
  schema               = each.value.schema
  comment              = each.value.comment
  return_type          = each.value.return_type
  execute_as           = each.value.execute_as
  procedure_definition = each.value.procedure_definition

  dynamic "arguments" {
    for_each = each.value.arguments
    content {
      arg_name          = arguments.value.arg_name
      arg_data_type     = arguments.value.arg_data_type
      arg_default_value = arguments.value.arg_default_value
    }
  }
}

resource "snowflake_procedure_sql" "procedures_accountadmin" {
  provider = snowflake.accountadmin
  for_each = var.execute ? local.sqlProceduresByAccountadmin : {}

  name                 = each.value.name
  database             = each.value.database
  schema               = each.value.schema
  comment              = each.value.comment
  return_type          = each.value.return_type
  execute_as           = each.value.execute_as
  procedure_definition = each.value.procedure_definition

  dynamic "arguments" {
    for_each = each.value.arguments
    content {
      arg_name          = arguments.value.arg_name
      arg_data_type     = arguments.value.arg_data_type
      arg_default_value = arguments.value.arg_default_value
    }
  }
}
