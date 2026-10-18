output "resource_group" { value = azurerm_resource_group.rg.name }
output "storage_account" { value = azurerm_storage_account.lake.name }
output "data_factory" { value = azurerm_data_factory.adf.name }
output "databricks_url" { value = "https://${azurerm_databricks_workspace.dbw.workspace_url}" }
output "key_vault_name" { value = azurerm_key_vault.kv.name }
output "key_vault_uri" { value = azurerm_key_vault.kv.vault_uri }
output "key_vault_id" { value = azurerm_key_vault.kv.id }
output "log_analytics_id" { value = azurerm_log_analytics_workspace.law.id }