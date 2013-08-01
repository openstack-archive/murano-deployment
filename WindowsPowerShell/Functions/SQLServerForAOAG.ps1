
function Install-SqlServerForAOAG {
    param (
        # Path to folder where msi files for additional SQL features are located
        [String] $SetupRoot = '',

        # Path to folder where msi files for additional SQLPS module are located
        [String] $SqlpsSetupRoot = ''

        [String] $MuranoFileShare = '',

        # (REQUIRED) Domain name
        [String] $SQLServiceUserDomain = 'fc-acme.local',

        # (REQUIRED) User name for the account which will be used by SQL service
        [String] $SQLServiceUserName = 'Administrator',

        # (REQUIRED) Password for that user
        [String] $SQLServiceUserPassword = 'P@ssw0rd',

        [Switch] $UpdateEnabled
    )


    if ($MuranoFileShare -eq '') {
        $MuranoFileShare = [Environment]::GetEnvironmentVariable('MuranoFileShare')
        if ($MuranoFileShare -eq '') {
            throw("Unable to find MuranoFileShare path.")
        }
    }

    if ($SetupRoot -eq '') {
        $SetupRoot = [IO.Path]::Combine($MuranoFileShare, 'Prerequisites\SQL Server\2012')
    }

    if ($SqlpsSetupRoot -eq '') {
        $SqlpsSetupRoot = [IO.Path]::Combine($MuranoFileShare, 'Prerequisites\SQL Server\Tools')
    }

    $ExtraOptions = @{}

    if ($UpdateEnabled) {
        $ExtraOptions += @{'UpdateEnabled' = $true}
    }
    else {
        $ExtraOptions += @{'UpdateEnabled' = $false}
    }

    New-SQLServerForAOAG `
        -SetupRoot $SetupRoot `
        -SQLSvcUsrDomain $SQLServiceUserDomain `
        -SQLSvcUsrName $SQLServiceUserName `
        -SQLSvcUsrPassword $SQLServiceUserPassword `
        -ExtraOptions $ExtraOptions

    Install-SqlServerPowerShellModule -SetupRoot $SqlpsSetupRoot
}



function Initialize-AlwaysOnAvailabilityGroup {
    param (
        [String] $DomainName,
        [String] $DomainAdminAccountName,
        [String] $DomainAdminAccountPassword
    )

    $DomainAdminAccountCreds = New-Credential -UserName "$DomainName\$DomainAdminAccountName" -Password "$DomainAdminAccountPassword"

    $FunctionsFile = Export-Function 'Get-NextFreePort', 'Initialize-AlwaysOn'

    Start-PowerShellProcess @"
. $FunctionsFile
Import-Module CoreFunctions
Initialize-AlwaysOn
"@ -Credential $DomainAdminAccountCreds

}


function Initialize-AOAGPrimaryReplica {
    param (
        # (OPTIONAL) Name of the new Availability Group. If not specified then default name will be used.
        [String] $GroupName,

        # (REQUIRED) Nodes that will be configured as replica partners.
        [Parameter(Mandatory=$true)]
        [String[]] $NodeList,

        # (REQUIRED) Node name that will be primary for selected Availability Group
        [Parameter(Mandatory=$true)]
        [String] $PrimaryNode,

        # (REQUIRED) Database list that will be added to the Availability Group
        [Parameter(Mandatory=$true)]
        [String[]] $DatabaseList,

        # (REQUIRED) Listener name that will be used by clients to connect to databases in that AG
        [Parameter(Mandatory=$true)]
        [String] $ListenerName,

        # (REQUIRED) IP address of the listener
        [Parameter(Mandatory=$true)]
        [String] $ListenerIP,

        # Sync Mode Node List
        [String[]] $SyncModeNodeList
    )


}



function Initialize-AOAGSecondaryReplica {
    param (
        # (REQUIRED) Nodes that will be configured as replica partners.
        [Parameter(Mandatory=$true)]
        [String[]] $NodeList,

        # (REQUIRED) Node name that will be primary for selected Availability Group
        [Parameter(Mandatory=$true)]
        [String] $PrimaryNode
    )
}

