$LogFolder = "D:\home\site\wwwroot\";
$DaysToKeepLogsAround = 1;
if (-not ([string]::IsNullOrEmpty($Env:LogsToKeep))) {
    $success = [System.Int32]::TryParse($Env:LogsToKeep, [ref]$DaysToKeepLogsAround)
}

Get-ChildItem -Path $LogFolder -File -Filter "httpplatform-stdout*.log" | Where-Object LastWriteTime -lt (Get-Date).AddDays(-$DaysToKeepLogsAround) | Remove-Item -Force
