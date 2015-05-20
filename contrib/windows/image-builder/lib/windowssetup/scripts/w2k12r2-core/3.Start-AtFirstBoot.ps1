
foreach ($ServiceName in @('cloudbase-init')) {
    Write-Host "Enabling service '$ServiceName'"
    & "sc.exe" config "$ServiceName" start= auto
    Start-Service "$ServiceName"
}

Remove-Item C:\Murano\nextunattend.xml
