/**
------------------------------------------------------------------------------------------------------
Create Database Role
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_database_role" "transactRxDatabaseRoles" {
  for_each = var.execute ? var.transactRxDatabaseRoles : {}
  database = each.value.database
  name     = each.value.name
  comment  = each.value.comment

  lifecycle {
    create_before_destroy = true
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Ownership to UserAdmin
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_ownership" "grant_ownership_database_roles_to_useradmin" {
  depends_on = [
    snowflake_database_role.transactRxDatabaseRoles
  ]
  for_each            = var.execute ? var.transactRxDatabaseRoles : {}
  account_role_name   = "USERADMIN"
  outbound_privileges = "COPY"
  on {
    object_type = "DATABASE ROLE"
    object_name = "\"${each.value.database}\".\"${each.value.name}\""
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Database Role to Account Roles
  NOTE: This will be implemented when account roles add database_role_grants field
------------------------------------------------------------------------------------------------------
**/
# Placeholder for future implementation when account roles can grant database roles

/**
------------------------------------------------------------------------------------------------------
  Grant Database Privileges to Database Role
------------------------------------------------------------------------------------------------------
**/
locals {
  database_roles_with_db_privileges = flatten([
    for db_role_key, db_role in var.transactRxDatabaseRoles : {
      db_role_key         = db_role_key
      database            = db_role.database
      database_role_name  = db_role.name
      database_privileges = db_role.database_privileges
    }
  ])
}

resource "snowflake_grant_privileges_to_database_role" "database_grants" {
  depends_on = [
    snowflake_database_role.transactRxDatabaseRoles
  ]

  for_each = var.execute ? {
    for db_role in local.database_roles_with_db_privileges : db_role.db_role_key => db_role
    if length(db_role.database_privileges) > 0
  } : {}

  database_role_name = "\"${each.value.database}\".\"${each.value.database_role_name}\""
  privileges         = each.value.database_privileges

  on_database = each.value.database
}

/**
------------------------------------------------------------------------------------------------------
  Grant All Schemas Privileges to Database Role
------------------------------------------------------------------------------------------------------
**/
locals {
  database_roles_with_all_schemas_privileges = flatten([
    for db_role_key, db_role in var.transactRxDatabaseRoles : {
      db_role_key           = db_role_key
      database              = db_role.database
      database_role_name    = db_role.name
      schema_privileges_all = db_role.schema_privileges_all
    }
  ])
}

resource "snowflake_grant_privileges_to_database_role" "all_schemas_grants" {
  depends_on = [
    snowflake_database_role.transactRxDatabaseRoles
  ]

  for_each = var.execute ? {
    for db_role in local.database_roles_with_all_schemas_privileges : db_role.db_role_key => db_role
    if length(db_role.schema_privileges_all) > 0
  } : {}

  database_role_name = "\"${each.value.database}\".\"${each.value.database_role_name}\""
  privileges         = each.value.schema_privileges_all

  on_schema {
    all_schemas_in_database = each.value.database
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Future Schemas Privileges to Database Role
------------------------------------------------------------------------------------------------------
**/
locals {
  database_roles_with_future_schemas_privileges = flatten([
    for db_role_key, db_role in var.transactRxDatabaseRoles : {
      db_role_key              = db_role_key
      database                 = db_role.database
      database_role_name       = db_role.name
      schema_privileges_future = db_role.schema_privileges_future
    }
  ])
}

resource "snowflake_grant_privileges_to_database_role" "future_schemas_grants" {
  depends_on = [
    snowflake_database_role.transactRxDatabaseRoles
  ]

  for_each = var.execute ? {
    for db_role in local.database_roles_with_future_schemas_privileges : db_role.db_role_key => db_role
    if length(db_role.schema_privileges_future) > 0
  } : {}

  database_role_name = "\"${each.value.database}\".\"${each.value.database_role_name}\""
  privileges         = each.value.schema_privileges_future

  on_schema {
    future_schemas_in_database = each.value.database
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Target Schema Privileges to Database Role
------------------------------------------------------------------------------------------------------
**/
locals {
  database_role_schemas = flatten([
    for db_role_key, db_role in var.transactRxDatabaseRoles : [
      for schema_name, schema in db_role.schemas : {
        db_role_key        = db_role_key
        database           = db_role.database
        database_role_name = db_role.name
        schema_name        = schema_name
        privileges_schema  = schema.privileges
      }
    ]
  ])
}

resource "snowflake_grant_privileges_to_database_role" "target_schema_grants" {
  depends_on = [
    snowflake_database_role.transactRxDatabaseRoles
  ]

  for_each = var.execute ? {
    for schema in local.database_role_schemas : "${schema.db_role_key}-${schema.schema_name}" => schema
    if length(schema.privileges_schema) > 0
  } : {}

  database_role_name = "\"${each.value.database}\".\"${each.value.database_role_name}\""
  privileges         = each.value.privileges_schema

  on_schema {
    schema_name = "\"${each.value.database}\".\"${each.value.schema_name}\""
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant All Schema Object Privileges to Database Role
------------------------------------------------------------------------------------------------------
**/
locals {
  database_role_allSchemaObjects = flatten([
    for db_role_key, db_role in var.transactRxDatabaseRoles : [
      for schema_name, schema in db_role.schemas : [
        for object_type_plural, obj_all in schema.allObjects : {
          db_role_key        = db_role_key
          database           = db_role.database
          database_role_name = db_role.name
          schema_name        = schema_name
          object_type_plural = object_type_plural
          privileges         = obj_all.privileges
        }
      ]
    ]
  ])
}

resource "snowflake_grant_privileges_to_database_role" "schema_object_grants_all" {
  depends_on = [
    snowflake_database_role.transactRxDatabaseRoles
  ]

  for_each = var.execute ? {
    for obj in local.database_role_allSchemaObjects : "${obj.db_role_key}-${obj.schema_name}-${obj.object_type_plural}" => obj
    if length(obj.privileges) > 0
  } : {}

  database_role_name = "\"${each.value.database}\".\"${each.value.database_role_name}\""
  privileges         = each.value.privileges

  on_schema_object {
    all {
      object_type_plural = each.value.object_type_plural
      in_schema          = "\"${each.value.database}\".\"${each.value.schema_name}\""
    }
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Future Schema Object Privileges to Database Role
------------------------------------------------------------------------------------------------------
**/
locals {
  database_role_futureSchemaObjects = flatten([
    for db_role_key, db_role in var.transactRxDatabaseRoles : [
      for schema_name, schema in db_role.schemas : [
        for object_type_plural, obj_future in schema.futureObjects : {
          db_role_key        = db_role_key
          database           = db_role.database
          database_role_name = db_role.name
          schema_name        = schema_name
          object_type_plural = object_type_plural
          privileges         = obj_future.privileges
        }
      ]
    ]
  ])
}

resource "snowflake_grant_privileges_to_database_role" "schema_object_grants_future" {
  depends_on = [
    snowflake_database_role.transactRxDatabaseRoles
  ]

  for_each = var.execute ? {
    for obj in local.database_role_futureSchemaObjects : "${obj.db_role_key}-${obj.schema_name}-${obj.object_type_plural}" => obj
    if length(obj.privileges) > 0
  } : {}

  database_role_name = "\"${each.value.database}\".\"${each.value.database_role_name}\""
  privileges         = each.value.privileges

  on_schema_object {
    future {
      object_type_plural = each.value.object_type_plural
      in_schema          = "\"${each.value.database}\".\"${each.value.schema_name}\""
    }
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Target Schema Object Privileges to Database Role
------------------------------------------------------------------------------------------------------
**/
locals {
  database_role_targetSchemaObjects = flatten([
    for db_role_key, db_role in var.transactRxDatabaseRoles : [
      for schema_name, schema in db_role.schemas : [
        for object_name, obj_target in schema.targetObjects : {
          db_role_key        = db_role_key
          database           = db_role.database
          database_role_name = db_role.name
          schema_name        = schema_name
          object_name        = object_name
          object_type        = obj_target.object_type
          privileges         = obj_target.privileges
        }
      ]
    ]
  ])
}

resource "snowflake_grant_privileges_to_database_role" "schema_object_grants_target" {
  depends_on = [
    snowflake_database_role.transactRxDatabaseRoles
  ]

  for_each = var.execute ? {
    for obj in local.database_role_targetSchemaObjects : "${obj.db_role_key}-${obj.schema_name}-${obj.object_name}" => obj
    if length(obj.privileges) > 0
  } : {}

  database_role_name = "\"${each.value.database}\".\"${each.value.database_role_name}\""
  privileges         = each.value.privileges

  on_schema_object {
    object_type = each.value.object_type
    object_name = "\"${each.value.database}\".\"${each.value.schema_name}\".\"${each.value.object_name}\""
  }
}
