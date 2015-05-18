
foreach ($ServiceName in @('cloudbase-init')) {
    Write-Host "Enabling service '$ServiceName'"
    & "sc.exe" config "$ServiceName" start= auto
    Start-Service "$ServiceName"
}

