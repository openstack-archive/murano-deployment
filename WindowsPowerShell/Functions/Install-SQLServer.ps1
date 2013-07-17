Function Install-SqlServer {
    param (
        [String] $SetupRoot = '',
        [String] $SAPassword = '',
        [String] $MuranoFileShare = '',
        [Boolean] $MixedModeAuth = $false
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
    

    $ExtraOptions = @{}
    
    if ($MixedModeAuth) {
        $ExtraOptions += @{'SECURITYMODE' = 'SQL'}
    }
    
    if ($SAPassword -ne '') {
        $ExtraOptions += @{'SAPWD' = $SAPassword}
    }
    
    New-SqlServer -SetupRoot $SetupRoot -ExtraOptions $ExtraOptions
}
