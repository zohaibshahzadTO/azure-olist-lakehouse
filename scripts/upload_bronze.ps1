param([string]$LoadDate = (Get-Date -Format "yyyy-MM-dd"))
$acct = terraform -chdir=terraform output -raw storage_account
Get-ChildItem data/raw/*.csv | Where-Object { $_.Name -notlike "*geolocation*" } | ForEach-Object {
  $table = $_.BaseName -replace '^olist_', '' -replace '_dataset$', ''
  az storage blob upload --account-name $acct --auth-mode login `
    --container-name bronze --file $_.FullName `
    --name "$table/load_date=$LoadDate/$($_.Name)" --overwrite --only-show-errors
  Write-Host "uploaded $table"
}