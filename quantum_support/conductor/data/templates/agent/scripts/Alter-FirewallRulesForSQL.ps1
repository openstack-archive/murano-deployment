trap {
    &$TrapHandler
}


$FW_Rules = @{
    "SQL Server Data Connection" = "1433";
    "SQL Admin Connection" = "1434";
    "SQL Service Broker" = "4022";
    "SQL Debugger/RPC"="135";
}


$FW_Proto = "TCP"


function Add-NetshFirewallRule {
    param (
        [HashTable] $hshRules,
        [String] $proto
    )


    foreach ($h in $hshRules.GetEnumerator()) {
        try {
            $command="advfirewall firewall add rule name=`"$($h.Name)`" dir=in action=allow protocol=$proto localport=$($h.Value)"
            Start-Process -FilePath netsh -ArgumentList $command -Wait
        }
        catch {
            $except= $_ | Out-String
            Write-LogError "Add rule $($h.Name) FAILS with $except"
        }
    }
}

function Remove-NetShFirewallRule {
    param (
        [HashTable] $hshRules
    )

    foreach ($h in $hshRules.GetEnumerator()) {
        try {
            $command="advfirewall firewall delete rule name=`"$($h.Name)`""
            Start-Process -FilePath netsh -ArgumentList $command -Wait
        }
        catch {
            $except= $_ | Out-String
            Write-LogError "Delete rule $($h.Name) FAILS with $except"
        }
    }
}


function Enable-SQLExternalAccess {
    Add-NetshFirewallRule $FW_Rules $FW_Proto
}


function Disable-SQLExternalAccess {
    Remove-NetshFirewallRule $FW_Rules $FW_Proto
}
