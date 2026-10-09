/**
---------------------------------------------------------------
    Create Custom Users (As)
---------------------------------------------------------------
**/
resource "snowflake_user" "user" {
  provider = snowflake.useradmin
  depends_on = [
    snowflake_account_role.transactRxRoles
  ]
  for_each = var.execute ? var.transactRxUsers : {}

  name                           = each.key
  comment                        = each.value.comment
  disabled                       = each.value.disabled
  display_name                   = each.value.display_name
  email                          = length(each.value.email) != 0 ? each.value.email : var.DEFAULT_EMAIL
  first_name                     = each.value.first_name
  last_name                      = each.value.last_name
  default_warehouse              = each.value.default_warehouse
  default_secondary_roles_option = coalesce(each.value.default_secondary_roles_option, "ALL")
  default_role                   = each.value.isCreateUserDatabase ? "${upper("${var.USER_ROLE_PREFIX}${replace("${each.value.first_name}${each.value.last_name}${each.value.index}", "/[^a-zA-Z0-9]/", "")}")}" : each.value.default_role
  password                       = lookup(each.value, "isPasswordEnabled", false) == true ? var.DEFAULT_PASSWORD : null
  must_change_password           = lookup(each.value, "isPasswordEnabled", false)
  rsa_public_key                 = lookup(each.value, "rsa_public_key", null)
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      password,
      must_change_password,
    ]
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Ownership to UserAdmin
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_ownership" "grant_ownership_user_to_useradmin" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_user.user
  ]
  for_each            = var.execute ? var.transactRxUsers : {}
  account_role_name   = "USERADMIN"
  outbound_privileges = "COPY"
  on {
    object_type = "USER"
    object_name = each.key
  }
}

/**
---------------------------------------------------------------
    Grant Roles To Users (As)
---------------------------------------------------------------
**/
locals {
  usersByRole = flatten([
    for user_name, user in var.transactRxUsers : [
      for role_name in user.roles : {
        user_name = user_name
        role_name = role_name
      }
    ]
  ])
}


resource "snowflake_grant_account_role" "grant_roles_to_users" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_user.user
  ]

  for_each = var.execute ? {
    for user in local.usersByRole : "${user.user_name}-${user.role_name}" => user
  } : {}
  user_name = each.value.user_name
  role_name = each.value.role_name
}


/**
---------------------------------------------------------------
    Create Custom User Dependencies/Roles
---------------------------------------------------------------
**/
locals {
  // Create a Map of Users that need to have a database created.  (Santized Snowflake Resource Name => User Object)
  /*
    NOTE: This map will ensure that the dynamic resources are unique based on {FIRST}{LAST}{INDEX}.
    In the event that two users have the same first and last name, the index will be used to differentiate them.
    This map will cause an error if two users have the same first and last name and index, safeguarding against duplicate resources. 
  */
  transactDatabaseUsers = {
    for key, user in var.transactRxUsers : "${upper(replace("${user.first_name}${user.last_name}${user.index}", "/[^a-zA-Z0-9]/", ""))}" => user
    if lookup(user, "isCreateUserDatabase", false) == true
  }
}

/**
------------------------------------------------------------------------------------------------------
  Create User Role for User
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_account_role" "userRole" {
  provider = snowflake.useradmin
  depends_on = [
    snowflake_user.user
  ]
  for_each = var.execute ? local.transactDatabaseUsers : {}

  name    = upper("${var.USER_ROLE_PREFIX}${each.key}")
  comment = "User specific role for ${each.value.first_name} ${each.value.last_name} to access database ${upper("${var.USER_DATABASE_PREFIX}${each.key}")}"

  lifecycle {
    create_before_destroy = true
  }
}


/**
------------------------------------------------------------------------------------------------------
  Grant Ownership of Role to UserAdminn
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_ownership" "grant_user_roles_to_useradmin" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_account_role.userRole
  ]
  for_each            = var.execute ? local.transactDatabaseUsers : {}
  account_role_name   = "USERADMIN"
  outbound_privileges = "COPY"
  on {
    object_type = "ROLE"
    object_name = upper("${var.USER_ROLE_PREFIX}${each.key}")
  }


}

/**
------------------------------------------------------------------------------------------------------
  Grant Default Role to all User Roles (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_account_role" "grant_user_role_to_sysadmin" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_account_role.userRole
  ]
  for_each         = var.execute ? local.transactDatabaseUsers : {}
  role_name        = upper("${var.USER_ROLE_PREFIX}${each.key}")
  parent_role_name = "SYSADMIN"
}

/**
------------------------------------------------------------------------------------------------------
  Grant Default Role to all Custom Roles (As SecurityAdmin)
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_account_role" "grant_default_role_to_user_role" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_account_role.userRole,
    snowflake_database.user_databases

  ]
  for_each         = var.execute ? local.transactDatabaseUsers : {}
  role_name        = var.DEFAULT_ROLE
  parent_role_name = upper("${var.USER_ROLE_PREFIX}${each.key}")
}

/**
------------------------------------------------------------------------------------------------------
  Create User Database
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_database" "user_databases" {
  provider = snowflake.sysadmin
  for_each = var.execute ? local.transactDatabaseUsers : {}

  name    = upper("${var.USER_DATABASE_PREFIX}${each.key}")
  comment = "Database for user ${each.value.first_name} ${each.value.last_name}"

  lifecycle {
    create_before_destroy = true
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Ownership of Custom Users Database to User Role
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_ownership" "grant_ownership_user_databases_to_user_role" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_database.user_databases
  ]
  for_each = var.execute ? local.transactDatabaseUsers : {}

  account_role_name   = upper("${var.USER_ROLE_PREFIX}${each.key}")
  outbound_privileges = "COPY"
  on {
    object_type = "DATABASE"
    object_name = upper("${var.USER_DATABASE_PREFIX}${each.key}")
  }
}

/**
------------------------------------------------------------------------------------------------------
  Grant Custom User Role to User (As UserAdmin)  
------------------------------------------------------------------------------------------------------
**/
resource "snowflake_grant_account_role" "grant_user_roles_to_users" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_account_role.userRole
  ]
  for_each  = var.execute ? local.transactDatabaseUsers : {}
  user_name = each.value.login_name
  role_name = upper("${var.USER_ROLE_PREFIX}${each.key}")
}



/**
---------------------------------------------------------------
  [KNOWN ISSUES]
  If a user that has isCreateUserDatabase = true is deleted, the role and database will not be deleted properly.
  This appears to be a bug in the Snowflake provider.

  https://github.com/Snowflake-Labs/terraform-provider-snowflake/issues/1060

  In the above case, the roles, user and  database must be dropped manually via sql commands.
  
  -=[CLEAN UP PATTERN]=-
    user role         = UR_{first_name}{last_name}{index}   //NOTE: MUST BE ALL UPPERCASE
    user database     = DB_{first_name}{last_name}{index}   //NOTE: MUST BE ALL UPPERCASE
    user login_name   = {login_name}

  -=[Sample User To Drop]=-
    USER_JOHN_DOE = {
      login_name           = "John.Doe@redsailtechnologies.com"
      index                = 1
      isCreateUserDatabase = true
      disabled             = false
      display_name         = "John Doe"
      email                = "John.Doe@redsailtechnologies.com"
      first_name           = "John"
      last_name            = "Doe"
      comment              = "Sample Users"
      default_warehouse    = ""
      default_role         = ""
      roles = []
    }

  -=[EXAMPLE SQL COMMANDS]=-
    DROP ROLE UR_JOHNDOE0;
    DROP DATABASE DB_JOHNDOE0;
    DROP USER "John.Doe@redsailtechnologies.com";     //NOTE: Because the login_name is an email, it must be wrapped in quotes.
---------------------------------------------------------------
**/
