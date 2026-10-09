/**
------------------------------------------------------------------------------------------------------
Create Custom Role (As UserAdmin)
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_account_role" "transactRxRoles" {
  for_each = var.execute ? var.transactRxRoles : {}
  name     = each.key
  comment  = each.value.role_description

  lifecycle {
    create_before_destroy = true
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Ownership to UserAdmin
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_ownership" "grant_ownership_roles_to_useradmin" {
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]
  for_each            = var.execute ? var.transactRxRoles : {}
  account_role_name   = "USERADMIN"
  outbound_privileges = "COPY"
  on {
    object_type = "ROLE"
    object_name = each.key
  }
}


/**
------------------------------------------------------------------------------------------------------
  Graant Custom Roles to SYSADMING (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_account_role" "grant_transactRxRoles_to_sysadmin" {
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]
  for_each         = var.execute ? var.transactRxRoles : {}
  role_name        = each.key
  parent_role_name = "SYSADMIN"
}

/**
------------------------------------------------------------------------------------------------------
  Grant Role to Another Role (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
locals {
  role_pairs = flatten([
    for parent, role in var.transactRxRoles : [
      for child in role.role_grants : {
        parent_role_name = parent
        child_role_name  = child
      }
    ]
  ])
}

resource "snowflake_grant_account_role" "grant_role_to_other_role" {
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]

  for_each = var.execute ? {
    for pair in local.role_pairs : "${pair.parent_role_name}-${pair.child_role_name}" => pair
  } : {}

  parent_role_name = each.value.parent_role_name
  role_name        = each.value.child_role_name
}

/**
------------------------------------------------------------------------------------------------------
  Grant Database Role to Account Role (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
locals {
  database_role_to_account_role_pairs = flatten([
    for account_role_name, role in var.transactRxRoles : [
      for database_role_obj in role.database_role_grants : {
        account_role_name = account_role_name
        database_name     = database_role_obj.database
        role_name         = database_role_obj.name
      }
    ]
  ])
}

resource "snowflake_grant_database_role" "grant_database_role_to_account_role" {
  depends_on = [
    snowflake_account_role.transactRxRoles,
    snowflake_database_role.transactRxDatabaseRoles
  ]

  for_each = var.execute ? {
    for pair in local.database_role_to_account_role_pairs : "${pair.account_role_name}-${pair.database_name}_${pair.role_name}" => pair
  } : {}

  database_role_name = "\"${each.value.database_name}\".\"${each.value.role_name}\""
  parent_role_name   = each.value.account_role_name
}

/**
------------------------------------------------------------------------------------------------------
  Grant Database Privileges (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
locals {
  roles = flatten([
    for name_role, role in var.transactRxRoles : [
      for name_db, db in role.databases : {
        name_role                = name_role
        name_db                  = name_db
        privileges_db            = db.privileges
        schema_privileges_future = db.schema_privileges_future
        schema_privileges_all    = db.schema_privileges_all
      }
    ]
  ])
}

resource "snowflake_grant_privileges_to_account_role" "database_grants" {
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]
  //The for each block is defining a key to object map....called....."each".
  for_each = var.execute ? {
    for role in local.roles : "${role.name_role}-${role.name_db}" => role
    if length(role.privileges_db) > 0
  } : {}
  account_role_name = each.value.name_role
  on_account_object {
    object_type = "DATABASE"
    object_name = each.value.name_db
  }
  privileges = each.value.privileges_db
}

/**
------------------------------------------------------------------------------------------------------
  Grant Account Privileges (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
locals {
  account_privilege_pairs = flatten([
    for role_name, role in var.transactRxRoles : [
      for privilege in role.account_privileges : {
        role_name = role_name
        privilege = privilege
      }
    ]
  ])
}

resource "snowflake_grant_privileges_to_account_role" "account_privilege_grants" {
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]

  for_each = var.execute ? {
    for pair in local.account_privilege_pairs : "${pair.role_name}-${pair.privilege}" => pair
  } : {}

  account_role_name = each.value.role_name
  privileges        = [each.value.privilege]

  on_account = true

  with_grant_option = false
}


/**
------------------------------------------------------------------------------------------------------
  Grant Integration Privileges (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
locals {
  integration_grants = flatten([
    for role_name, role in var.transactRxRoles : [
      for integration in lookup(role, "integrations", []) : {
        role_name        = role_name
        integration_name = integration
      }
    ]
  ])
}

resource "snowflake_grant_privileges_to_account_role" "integration_grants" {
  depends_on = [
    snowflake_account_role.transactRxRoles,
    snowflake_storage_integration.storage_int
  ]

  for_each = var.execute ? {
    for grant in local.integration_grants : "${grant.role_name}-${grant.integration_name}" => grant
  } : {}

  account_role_name = each.value.role_name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "INTEGRATION"
    object_name = each.value.integration_name
  }
}


/**
------------------------------------------------------------------------------------------------------
  Grant Failover Group Privileges (As AccountAdmin)

  NOTE: Grants on a FAILOVER GROUP require ACCOUNTADMIN - SECURITYADMIN cannot
        make them, so this uses the module's default (accountadmin) provider.
        Grants apply to the account this provider is pointed at; they do NOT
        cross into the secondary (West) account.
------------------------------------------------------------------------------------------------------
**/
locals {
  failover_group_grants = flatten([
    for role_name, role in var.transactRxRoles : [
      for failover_group in lookup(role, "failover_groups", []) : {
        role_name           = role_name
        failover_group_name = failover_group
        privileges          = role.failover_group_privileges
      }
    ]
  ])
}

resource "snowflake_grant_privileges_to_account_role" "failover_group_grants" {
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]

  for_each = var.execute ? {
    for grant in local.failover_group_grants : "${grant.role_name}-${grant.failover_group_name}" => grant
    if length(grant.privileges) > 0
  } : {}

  account_role_name = each.value.role_name
  privileges        = each.value.privileges

  on_account_object {
    object_type = "FAILOVER GROUP"
    object_name = each.value.failover_group_name
  }

  with_grant_option = false
}


/**
------------------------------------------------------------------------------------------------------
  Grant Future Schema Privileges (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_privileges_to_account_role" "schema_grants_future" {
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]
  for_each = var.execute ? {
    for role in local.roles : "${role.name_role}-${role.name_db}" => role
    if length(role.schema_privileges_future) > 0
  } : {}
  account_role_name = each.value.name_role
  privileges        = each.value.schema_privileges_future
  on_schema {
    future_schemas_in_database = each.value.name_db
  }
}


/**
------------------------------------------------------------------------------------------------------
  Grant All Schema Privileges (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_privileges_to_account_role" "schema_grants_all" {
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]
  for_each = var.execute ? {
    for role in local.roles : "${role.name_role}-${role.name_db}" => role
    if length(role.schema_privileges_all) > 0
  } : {}
  account_role_name = each.value.name_role
  privileges        = each.value.schema_privileges_all
  on_schema {
    all_schemas_in_database = each.value.name_db
  }
}


/**
------------------------------------------------------------------------------------------------------
  Grant Target Schema Privileges (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
locals {
  schemas = flatten([
    for name_role, role in var.transactRxRoles : [
      for name_db, db in role.databases : [
        for name_schema, schema in db.schemas : {
          name_role         = name_role
          name_db           = name_db
          name_schema       = name_schema
          privileges_schema = schema.privileges
        }
      ]
    ]
  ])
}

resource "snowflake_grant_privileges_to_account_role" "target_schema_grants" {
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]
  //The for each block is defining a key to object map....called....."each".
  for_each = var.execute ? {
    for schema in local.schemas : "${schema.name_role}-${schema.name_db}-${schema.name_schema}" => schema
    if length(schema.privileges_schema) > 0
  } : {}
  account_role_name = each.value.name_role
  on_schema {
    schema_name = "\"${each.value.name_db}\".\"${each.value.name_schema}\""
  }
  privileges = each.value.privileges_schema
}


/**
------------------------------------------------------------------------------------------------------
  Grant All Schema Object Privileges (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/

locals {
  allSchemaObjects = flatten([
    for name_role, role in var.transactRxRoles : [
      for name_db, db in role.databases : [
        for name_schema, schema in db.schemas : [
          for name_sObjPlural, sObjAll in schema.allObjects : {
            name_role       = name_role
            name_db         = name_db
            name_schema     = name_schema
            name_sObjPlural = name_sObjPlural
            privileges      = sObjAll.privileges
          }
        ]
      ]
    ]
  ])
}

resource "snowflake_grant_privileges_to_account_role" "schema_object_grants_all" {
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]
  for_each = var.execute ? {
    for schemaObjAll in local.allSchemaObjects : "${schemaObjAll.name_role}-${schemaObjAll.name_db}-${schemaObjAll.name_schema}-${schemaObjAll.name_sObjPlural}" => schemaObjAll
    if length(schemaObjAll.privileges) > 0
  } : {}
  privileges        = each.value.privileges
  account_role_name = each.value.name_role
  on_schema_object {
    all {
      object_type_plural = each.value.name_sObjPlural
      in_schema          = "\"${each.value.name_db}\".\"${each.value.name_schema}\""
    }
  }
}



/**
------------------------------------------------------------------------------------------------------
  Grant Future Schema Object Privileges (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
locals {
  futureSchemaObjects = flatten([
    for name_role, role in var.transactRxRoles : [
      for name_db, db in role.databases : [
        for name_schema, schema in db.schemas : [
          for name_sObjPlural, sObjFuture in schema.futureObjects : {
            name_role       = name_role
            name_db         = name_db
            name_schema     = name_schema
            name_sObjPlural = name_sObjPlural
            privileges      = sObjFuture.privileges
          }
        ]
      ]
    ]
  ])
}

resource "snowflake_grant_privileges_to_account_role" "schema_object_grants_future" {
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]
  for_each = var.execute ? {
    for schemaObjFuture in local.futureSchemaObjects : "${schemaObjFuture.name_role}-${schemaObjFuture.name_db}-${schemaObjFuture.name_schema}-${schemaObjFuture.name_sObjPlural}" => schemaObjFuture
    if length(schemaObjFuture.privileges) > 0
  } : {}

  privileges        = each.value.privileges
  account_role_name = each.value.name_role
  on_schema_object {
    future {
      object_type_plural = each.value.name_sObjPlural
      in_schema          = "\"${each.value.name_db}\".\"${each.value.name_schema}\""
    }
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Target Schema Object Privileges (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
locals {
  targetSchemaObjects = flatten([
    for name_role, role in var.transactRxRoles : [
      for name_db, db in role.databases : [
        for name_schema, schema in db.schemas : [
          for name_object, sObjTarget in schema.targetObjects : {
            name_role   = name_role
            name_db     = name_db
            name_schema = name_schema
            name_object = name_object
            object_type = sObjTarget.object_type
            privileges  = sObjTarget.privileges
          }
        ]
      ]
    ]
  ])
}

resource "snowflake_grant_privileges_to_account_role" "schema_object_grants_target" {
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]
  for_each = var.execute ? {
    for schemaObjTarget in local.targetSchemaObjects : "${schemaObjTarget.name_role}-${schemaObjTarget.name_db}-${schemaObjTarget.name_schema}-${schemaObjTarget.name_object}" => schemaObjTarget
    if length(schemaObjTarget.privileges) > 0
  } : {}
  privileges        = each.value.privileges
  account_role_name = each.value.name_role
  on_schema_object {
    object_type = each.value.object_type
    object_name = "\"${each.value.name_db}\".\"${each.value.name_schema}\".\"${each.value.name_object}\""
  }
}
