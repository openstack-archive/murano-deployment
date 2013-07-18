Function Install-SqlServer {
    param (
        [String] $SetupRoot = '',
        [String] $SAPassword = '',
        [String] $MuranoFileShare = '',
        [String] $MixedModeAuth = $false
    )
    
    if ($SetupRoot -eq '') {
        if ($MuranoFileShare -eq '') {
            $MuranoFileShare = [Environment]::GetEnvironmentVariable('MuranoFileShare')
            if ($MuranoFileShare -eq '') {
                throw("Unable to find MuranoFileShare path.")
            }
        }
        
        $SetupRoot = [IO.Path]::Combine($MuranoFileShare, 'Prerequisites\SQL Server\2012')
    }
    
    try {
        $MixedModeAuth = [System.Convert]::ToBoolean($MixedModeAuth)
    }
    catch {
        $MixedModeAuth = $false
    }

    $ExtraOptions = @{}
    
    if ($MixedModeAuth) {
        $ExtraOptions += @{'SECURITYMODE' = 'SQL'}
        if ($SAPassword -eq '') {
            throw("SAPassword must be set when MixedModeAuth is requisted!")
        }
    }
    
    if ($SAPassword -ne '') {
        $ExtraOptions += @{'SAPWD' = $SAPassword}
    }
    
    New-SqlServer -SetupRoot $SetupRoot -ExtraOptions $ExtraOptions
}
