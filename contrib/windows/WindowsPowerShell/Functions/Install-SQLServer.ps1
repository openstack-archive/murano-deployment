
trap {
    &$TrapHandler
}



Function ConvertTo-Boolean {
    param (
        $InputObject,
        [Boolean] $Default = $false
    )
    try {
        [System.Convert]::ToBoolean($InputObject)
    }
    catch {
        $Default
    }
}



Function Show-Environment {
    foreach ($item in (Get-ChildItem Env:)) {
        Write-Log ("'{0}' --> '{1}'" -f $item.Name, $item.Value)
    }
}



Function Install-SqlServer {
    param (
        [String] $SetupRoot = '',
        [String] $SAPassword = '',
        [String] $MuranoFileShare = '',
        [Switch] $MixedModeAuth = $false,
        [Switch] $UpdateEnabled = $false
    )
    begin {
        Show-InvocationInfo $MyInvocation
    }
    end {
        Show-InvocationInfo $MyInvocation -End
    }
    process {
        trap {
            &$TrapHandler
        }
    
        if ($SetupRoot -eq '') {
            if ($MuranoFileShare -eq '') {
                $MuranoFileShare = [Environment]::GetEnvironmentVariable('MuranoFileShare')
                if ($MuranoFileShare -eq '') {
                    throw("Unable to find MuranoFileShare path.")
                }
            }
            
            $SetupRoot = [IO.Path]::Combine($MuranoFileShare, 'Prerequisites\SQL Server\2012')
        }
        
        #$MixedModeAuthSwitch = ConvertTo-Boolean $MixedModeAuth

        $ExtraOptions = @{}
        
        if ($MixedModeAuth -eq $true) {
            $ExtraOptions += @{'SECURITYMODE' = 'SQL'}
            if ($SAPassword -eq '') {
                throw("SAPassword must be set when MixedModeAuth is requisted!")
            }
        }
        
        if ($SAPassword -ne '') {
            $ExtraOptions += @{'SAPWD' = $SAPassword}
        }

        if (-not $UpdateEnabled) {
            $ExtraOptions += @{'UpdateEnabled' = $false}
        }

        Show-Environment

        New-SqlServer -SetupRoot $SetupRoot -ExtraOptions $ExtraOptions
    }
}
