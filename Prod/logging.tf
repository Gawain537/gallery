resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.environment}-main"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.default_tags
}

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_monitor_data_collection_endpoint" "cloudflare" {
  name                = "dce-cloudflare"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.resource_group_location

  description                   = "Data collection endpoint for Cloudflare logs"
  public_network_access_enabled = true
}

resource "azurerm_monitor_data_collection_rule" "cloudflare" {
  name                = "dcr-cloudflare"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.resource_group_location

  description                 = "Routes Cloudflare events into Log Analytics"
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.cloudflare.id

  destinations {
    log_analytics {
      name                  = "cloudflare-log-analytics"
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
    }
  }

  dynamic "stream_declaration" {
    for_each = local.cloudflare_tables

    content {
      stream_name = "Custom-${stream_declaration.key}"

      dynamic "column" {
        for_each = stream_declaration.value

        content {
          name = column.value.name

          # The custom-table resource expects "dateTime", while the
          # DCR resource expects lowercase "datetime".
          type = column.value.type == "dateTime" ? "datetime" : column.value.type
        }
      }
    }
  }

  dynamic "data_flow" {
    for_each = local.cloudflare_tables

    content {
      streams       = ["Custom-${data_flow.key}"]
      destinations  = ["cloudflare-log-analytics"]
      output_stream = "Custom-${data_flow.key}"
      transform_kql = "source"
    }
  }

  # Azure must create the destination tables before validating the DCR.
  depends_on = [
    azurerm_log_analytics_workspace_table_custom_log.cloudflare
  ]
}

locals {
  audit_log_table_name = "AuditLog_CL"
  audit_log_columns = [
    {
      "name" : "appId",
      "type" : "string"
    },
    {
      "name" : "correlationId",
      "type" : "string"
    },
    {
      "name" : "TimeGenerated",
      "type" : "datetime"
    }
  ]
}

locals {
  cloudflare_tables = {
    CloudflareSecurityEvents_CL = [
      { name = "TimeGenerated", type = "dateTime" },
      { name = "EventId",       type = "string" },
      { name = "ZoneId",        type = "string" },
      { name = "RayId",         type = "string" },
      { name = "Action",        type = "string" },
      { name = "ClientIP",      type = "string" },
      { name = "Host",          type = "string" },
      { name = "Path",          type = "string" },
      { name = "RuleId",        type = "string" },
      { name = "Source",        type = "string" },
    ]

    CloudflareAudit_CL = [
      { name = "TimeGenerated", type = "dateTime" },
      { name = "EventId",       type = "string" },
      { name = "AccountId",     type = "string" },
      { name = "Action",        type = "string" },
      { name = "Actor",         type = "string" },
      { name = "ResourceType",  type = "string" },
      { name = "ResourceId",    type = "string" },
      { name = "Result",        type = "string" },
    ]

    CloudflareCollectorHealth_CL = [
      { name = "TimeGenerated", type = "dateTime" },
      { name = "Source",        type = "string" },
      { name = "Success",       type = "boolean" },
      { name = "RecordsSent",   type = "long" },
      { name = "WindowEnd",     type = "dateTime" },
      { name = "ErrorCode",     type = "string" },
    ]
  }
}

resource "azurerm_log_analytics_workspace_table_custom_log" "cloudflare" {
  for_each = local.cloudflare_tables

  name         = each.key
  display_name = each.key
  workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.sentinel.workspace_id
  plan                    = "Analytics"
  retention_in_days       = 30
  total_retention_in_days = 30

  dynamic "column" {
    for_each = each.value

    content {
      name = column.value.name
      type = column.value.type
    }
  }
}