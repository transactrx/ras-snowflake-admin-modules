/**
==================================================================================================================
  Master Switch (Tells Module To Run Or Not)
==================================================================================================================
**/
variable "execute" {
  type    = bool
  default = false
}

/**
==================================================================================================================
  Roles
==================================================================================================================
**/
variable "transactRxRoles" {
  type = map(object({
    name        = string
    role_grants = list(string)
    database_role_grants = optional(list(object({
      name     = string
      database = string
    })), [])
    role_description = string
    warehouses       = list(string)
    //Privileges granted on each warehouse in `warehouses`.
    //Defaults to USAGE so existing roles are unchanged.
    warehouse_privileges = optional(list(string), ["USAGE"])
    account_privileges   = optional(list(string), [])
    integrations         = optional(list(string), [])
    //Failover groups this role may act on, by name.
    failover_groups = optional(list(string), [])
    //Privileges granted on each failover group in `failover_groups`.
    //MONITOR allows SHOW/DESC and replication history only - not FAILOVER or REPLICATE.
    failover_group_privileges = optional(list(string), ["MONITOR"])
    //Compute pools this role may use, by name.
    compute_pools = optional(list(string), [])
    //Privileges granted on each compute pool in `compute_pools`.
    //USAGE lets the role run services/jobs on the pool; MONITOR is read-only.
    compute_pool_privileges = optional(list(string), ["USAGE"])
    databases = map(object({
      privileges               = list(string)
      schema_privileges_future = list(string)
      schema_privileges_all    = list(string)
      schemas = map(object({
        privileges = list(string)
        allObjects = map(object({
          privileges = list(string)
        }))
        futureObjects = map(object({
          privileges = list(string)
        }))
        targetObjects = map(object({
          object_type = string
          privileges  = list(string)
        }))
      }))
    }))
  }))
  default = {}
}

/**
==================================================================================================================
  Warehouses
==================================================================================================================
**/
variable "transactRxWarehouses" {
  type = map(object({
    name                = string
    comment             = string
    warehouse_size      = string
    initially_suspended = bool
    min_cluster_count   = number
    max_cluster_count   = number
    scaling_policy      = string
    warehouse_type      = string

    //Seconds of inactivity before auto-suspend.
    //Omit to leave the warehouse at the Snowflake default (unmanaged by Terraform).
    auto_suspend = optional(number)

    //OPTIONS TO CONSIDER SUPPORTING
    # auto_resume = bool
    # enable_query_acceleration = bool
    # initially_suspended = bool
    # max_concurrency_level = number
    # query_acceleration_max_scale_factor = number
    # resource_monitor = string
    # statement_queued_timeout_in_seconds = number
    # statement_timeout_in_seconds = number
    # wait_for_provisioning = bool
  }))
  default = {}
}

/**
==================================================================================================================
  Compute Pools

  Snowpark Container Services compute. NOTE: a compute pool is NOT a warehouse -- it runs
  containers, bills per-node per-second on its own meter, and is not restrained by any
  warehouse resource monitor.
==================================================================================================================
**/
variable "transactRxComputePools" {
  type = map(object({
    name            = string
    comment         = optional(string)
    instance_family = string
    min_nodes       = number
    max_nodes       = number

    //Seconds of inactivity before the pool suspends.
    //The Snowflake default is -1 (NEVER suspend), so this defaults to one hour instead:
    //an idle pool that has scaled out otherwise bills indefinitely.
    auto_suspend_secs = optional(number, 3600)

    //"true" / "false" / "default" -- resume the pool when a service or job is submitted.
    auto_resume = optional(string, "true")

    //Create the pool suspended. Applies at creation only; ignored on later applies.
    initially_suspended = optional(string, "default")
  }))
  default = {}
}

/**
==================================================================================================================
  Monitors
==================================================================================================================
**/
variable "transactRxMonitors" {
  type = map(object({
    name            = string
    credit_quota    = number
    notify_triggers = list(number)
    notify_users    = list(string)

    // Warehouses this monitor covers. NOTE: snowflake provider 2.x removed `warehouses` from
    // snowflake_resource_monitor -- the association now lives on the WAREHOUSE
    // (snowflake_warehouse.resource_monitor). resources_warehouse.tf inverts this list into a
    // warehouse -> monitor lookup, so the monitor definition stays the single source of truth.
    // A warehouse named here that this Terraform does not manage is simply ignored.
    warehouses = list(string)

    // Credit percentages at which Snowflake SUSPENDS the covered warehouses. Leave unset for a
    // notify-only monitor -- which is what we want until the quotas have been observed for a full
    // cycle. Setting these can stop production compute.
    suspend_trigger           = optional(number)
    suspend_immediate_trigger = optional(number)
    })
  )
  default = {}
}

/**
==================================================================================================================
  StreamLits
==================================================================================================================
**/
variable "transactRxStreamlits" {
  type = map(object({
    name            = string
    database        = string
    schema          = string
    query_warehouse = string
    title           = string
    main_file       = string
    upload_files    = list(string)
    comment         = optional(string)
  }))
  default = {}
}

/**
==================================================================================================================
  Users (Key = Login Name, Value = User Object)
==================================================================================================================
**/
variable "transactRxUsers" {
  type = map(object({
    login_name                     = string
    index                          = number
    disabled                       = bool
    display_name                   = string
    email                          = string
    first_name                     = string
    last_name                      = string
    comment                        = string
    default_warehouse              = string
    default_secondary_roles_option = optional(string)
    default_role                   = string
    roles                          = list(string)
    rsa_public_key                 = optional(string)
    isCreateUserDatabase           = optional(bool, false)
    // No password option: users authenticate by SSO (people) or key pair / WIF (services). Passwords are not
    // supported by this module.
  }))
  default = {}
}

/**
==================================================================================================================
  Service Users (Key = Login Name, Value = Service User Object)
==================================================================================================================
**/
variable "transactRxServiceAccounts" {
  type = map(object({
    login_name                     = string
    disabled                       = bool
    display_name                   = string
    email                          = string
    comment                        = string
    default_warehouse              = string
    default_secondary_roles_option = optional(string)
    default_role                   = string
    roles                          = list(string)
    rsa_public_key                 = optional(string)
    // AWS workload identity (CIS 1.7): the task-role ARN the service authenticates with instead of a key
    // pair. A user can hold BOTH a key and a workload identity, so setting this is a no-op until the
    // service is redeployed with authenticator = WORKLOAD_IDENTITY. Remove rsa_public_key once that
    // user's logins show first_authentication_factor = 'WORKLOAD_IDENTITY'.
    workload_identity_aws_arn = optional(string)
  }))
  default = {}
}

/**
==================================================================================================================
  Alerts
==================================================================================================================
**/
variable "transactRxAlerts" {
  type = map(object({
    name      = string
    database  = string
    schema    = string
    warehouse = string
    enabled   = bool
    comment   = string
    cron      = string
    timezone  = string
    condition = string
    action    = string
  }))
  default = {}
}

/**
==================================================================================================================
  Integrations
==================================================================================================================
**/
variable "transactRxEmailIntegrations" {
  type = map(object({
    name               = string
    comment            = string
    enabled            = bool
    allowed_recipients = list(string)
    })
  )
  default = {}
}

variable "transactRxNotificationIntegrations" {
  type = map(object({
    name                  = string
    comment               = string
    enabled               = bool
    notification_provider = string
    aws_sns_topic_arn     = string
    aws_sns_role_arn      = string
    })
  )
  default = {}
}

/**
==================================================================================================================
  Procedures
==================================================================================================================
**/
variable "transactRxProcedures" {
  type = map(object({
    name                 = string
    database             = string
    schema               = string
    comment              = string
    return_type          = string
    execute_as           = string
    procedure_definition = string
    })
  )
  default = {}
}

/**
==================================================================================================================
  SQL Procedures

  `owner` selects which role owns the created procedure. Terraform cannot choose a provider
  dynamically, so the module keys one resource block per supported owner and filters this map
  by `owner` - see resource_procedure_sql.tf. Adding a new owner means adding a resource block
  there and extending the validation below.

  Owner matters for EXECUTE AS OWNER procedures: the procedure body runs with the owner's
  privileges. Use ACCOUNTADMIN only when SYSADMIN cannot perform the operation - e.g.
  ALTER ICEBERG TABLE ... REFRESH, which Snowflake restricts to the table owner "or higher".
==================================================================================================================
**/
variable "transactRxSqlProcedures" {
  type = map(object({
    name        = string
    database    = string
    schema      = string
    comment     = string
    return_type = string
    execute_as  = string
    owner       = optional(string, "SYSADMIN")
    arguments = optional(list(object({
      arg_name          = string
      arg_data_type     = string
      arg_default_value = optional(string)
    })), [])
    procedure_definition = string
    })
  )
  default = {}

  validation {
    condition = alltrue([
      for proc in var.transactRxSqlProcedures : contains(["SYSADMIN", "ACCOUNTADMIN"], upper(proc.owner))
    ])
    error_message = "SQL procedure `owner` must be one of: SYSADMIN, ACCOUNTADMIN."
  }
}



/**
==================================================================================================================
  Storage Integrations
==================================================================================================================
**/
variable "transactRxStorageIntegrations" {
  type = map(object({
    name                      = string
    comment                   = string
    enabled                   = bool
    storage_provider          = string
    storage_aws_role_arn      = string
    storage_allowed_locations = list(string)
    storage_blocked_locations = optional(list(string), [])
    usage_roles               = optional(list(string), [])
  }))
  default = {}
}

/**
==================================================================================================================
  Database Roles
==================================================================================================================
**/
variable "transactRxDatabaseRoles" {
  type = map(object({
    name                     = string
    database                 = string
    comment                  = string
    database_privileges      = list(string)
    schema_privileges_all    = optional(list(string), [])
    schema_privileges_future = optional(list(string), [])
    schemas = map(object({
      privileges = list(string)
      allObjects = map(object({
        privileges = list(string)
      }))
      futureObjects = map(object({
        privileges = list(string)
      }))
      targetObjects = map(object({
        object_type = string
        privileges  = list(string)
      }))
    }))
  }))
  default = {}
}

/**
==================================================================================================================
  External Options
==================================================================================================================
**/
variable "ADMIN_ACCOUNTS" {
  type    = list(string)
  default = []
}

variable "DEFAULT_EMAIL" {
  type    = string
  default = ""
}

variable "OWNER_ROLE_WAREHOUSES" {
  type    = string
  default = "SYSADMIN"
}

variable "OWNER_ROLE_COMPUTE_POOLS" {
  type    = string
  default = "SYSADMIN"
}

variable "USER_ROLE_PREFIX" {
  type    = string
  default = "UR_"
}
variable "USER_DATABASE_PREFIX" {
  type    = string
  default = "DB_"
}

variable "DEFAULT_ROLE" {
  type    = string
  default = "READ_ONLY"
}
variable "STREAMLITS_ROOT" {
  type    = string
  default = "./streamlits"
}

/**
  [SnowSQL]
  To upload files to stages you need to have snowsql installed on your local machine.

  You will need to add a connection to your snowsql config file located here.
    .snowsql/config

  You will need to add a connection with a name that matches the value of this variable
  ([connections.<name>] in that file). See the SnowSQL documentation for its fields.
  **/
variable "SNOW_SQL_CONNECTION_NAME" {
  type    = string
  default = "my_connection" //my_connection is the name used in the Terraform_apply.yml
}

