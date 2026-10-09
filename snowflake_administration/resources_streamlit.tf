/**
---------------------------------------------------------------
    Create Streamlit Stage
---------------------------------------------------------------
**/
resource "snowflake_stage" "streamlit_stage" {
  provider = snowflake.sysadmin
  for_each = var.transactRxStreamlits
  database = each.value.database
  schema   = each.value.schema
  name     = upper(each.key) //The Stage Will Have The Same Name As The Streamlit
  comment  = lookup(each.value, "comment", null)
}


/**
---------------------------------------------------------------
    Upload Streamlit Files to Stage
---------------------------------------------------------------
**/
locals {
  filesToStage = flatten([
    for name, streamlit in var.transactRxStreamlits : [
      for file in streamlit.upload_files : {
        file      = "${var.STREAMLITS_ROOT}/${streamlit.name}/${file}"
        streamlit = streamlit
      }
    ]
  ])
}

resource "null_resource" "streamlit_files" {
  depends_on = [snowflake_stage.streamlit_stage]
  for_each   = { for obj in local.filesToStage : obj.file => obj.streamlit }
  triggers = {
    always_run = timestamp() # This ensures the resource runs every time
  }

  provisioner "local-exec" {
    command = <<EOT
current_dir=$(pwd)
~/snowflake/snowsql -o log_level=DEBUG -c '${var.SNOW_SQL_CONNECTION_NAME}' -q "PUT file://$current_dir${each.key} @${upper("${each.value.database}.${each.value.schema}.${each.value.name}")} AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
    EOT
  }
}

/**
---------------------------------------------------------------
    Create Streamlits
---------------------------------------------------------------
**/
resource "snowflake_streamlit" "streamlit" {
  provider        = snowflake.sysadmin
  depends_on      = [null_resource.streamlit_files]
  for_each        = var.transactRxStreamlits
  name            = upper(each.value.name)
  database        = each.value.database
  schema          = each.value.schema
  stage           = "${each.value.database}.${each.value.schema}.${upper(each.value.name)}"
  main_file       = each.value.main_file
  query_warehouse = each.value.query_warehouse
  title           = each.value.title
  comment         = lookup(each.value, "comment", null)
}
