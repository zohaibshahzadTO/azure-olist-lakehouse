terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    key_vault { purge_soft_delete_on_destroy = true }
  }
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals { name = "${var.prefix}${random_string.suffix.result}" }

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.prefix}-lakehouse"
  location = var.location
}

# ----- Data lake -----
resource "azurerm_storage_account" "lake" {
  name                     = "st${local.name}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}

resource "azurerm_storage_data_lake_gen2_filesystem" "layers" {
  for_each           = toset(["bronze", "silver", "gold"])
  name               = each.key
  storage_account_id = azurerm_storage_account.lake.id
}

# ----- Orchestration -----
resource "azurerm_data_factory" "adf" {
  name                = "adf-${local.name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  identity { type = "SystemAssigned" }
}

resource "azurerm_role_assignment" "adf_lake" {
  scope                = azurerm_storage_account.lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.adf.identity[0].principal_id
}

# ----- Compute -----
resource "azurerm_databricks_workspace" "dbw" {
  name                        = "dbw-${local.name}"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  sku                         = "premium"
  managed_resource_group_name = "databricks-rg-${local.name}"
}

# ----- Secrets -----
resource "azurerm_key_vault" "kv" {
  name                       = "kv-${local.name}"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = false # if Terraform says this argument is unknown, use: enable_rbac_authorization = false
  soft_delete_retention_days = 7
}

resource "azurerm_key_vault_access_policy" "me" {
  key_vault_id       = azurerm_key_vault.kv.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

resource "azurerm_key_vault_access_policy" "adf" {
  key_vault_id       = azurerm_key_vault.kv.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_data_factory.adf.identity[0].principal_id
  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_secret" "storage_key" {
  name         = "lake-account-key"
  value        = azurerm_storage_account.lake.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.me]
}

# ----- Monitoring -----
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${local.name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1
}

resource "azurerm_monitor_diagnostic_setting" "adf_diag" {
  name                           = "adf-to-law"
  target_resource_id             = azurerm_data_factory.adf.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.law.id
  log_analytics_destination_type = "Dedicated"
  enabled_log { category = "PipelineRuns" }
  enabled_log { category = "ActivityRuns" }
  enabled_log { category = "TriggerRuns" }
}

resource "azurerm_monitor_action_group" "email" {
  name                = "ag-${local.name}-email"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "olistalert"
  email_receiver {
    name          = "me"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "pipeline_failed" {
  name                 = "alert-${local.name}-pipeline-failed"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  scopes               = [azurerm_log_analytics_workspace.law.id]
  severity             = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"
  criteria {
    query                   = "ADFPipelineRun | where Status == 'Failed' | project TimeGenerated, PipelineName, RunId"
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
  }
  action { action_groups = [azurerm_monitor_action_group.email.id] }
}