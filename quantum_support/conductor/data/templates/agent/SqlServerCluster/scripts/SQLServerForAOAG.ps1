
trap {
    &$TrapHandler
}

function Install-SqlServerPowerShellModule {
    param (
        [String] $SetupRoot = ''
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

        if ((Get-Module SQLPS -ListAvailable) -ne $null) {
            Write-Log "Module SQLSP already installed."
            return
        }

        if ($MuranoFileShare -eq '') {
            $MuranoFileShare = [String]([Environment]::GetEnvironmentVariable('MuranoFileShare'))
            if ($MuranoFileShare -eq '') {
                throw "Unable to find MuranoFileShare path."
            }
        }
        Write-LogDebug "MuranoFileShare = '$MuranoFileShare'"

        if ($SetupRoot -eq '') {
            $SetupRoot = [IO.Path]::Combine("$MuranoFileShare", 'Prerequisites\SQL Server\Tools')
        }
        Write-LogDebug "SetupRoot = '$SetupRoot'"
        
        $FileList = @(
            'SQLSysClrTypes.msi',
            'SharedManagementObjects.msi',
            'PowerShellTools.msi'
        )

        foreach ($MsiFile in $FileList) {
            Write-Log "Trying to install '$MsiFile' ..."
            $MsiPath = Join-Path $SetupRoot $MsiFile
            if ([IO.File]::Exists($MsiPath)) {
                Write-Log "Starting msiexe ..."
                $Result = Exec -FilePath "msiexec.exe" -ArgumentList @('/i', "`"$MsiPath`"", '/quiet') -PassThru
                if ($Result.ExitCode -ne 0) {
                    throw "Installation of MSI package '$MsiPath' failed with error code '$($Result.ExitCode)'"
                }
            }
            else {
                Write-Log "File '$MsiPath' not found."
            }
        }
    }
}



function Install-SqlServerForAOAG {
    param (
        # Path to folder where msi files for additional SQL features are located
        [String] $SetupRoot = '',

        # Path to folder where msi files for additional SQLPS module are located
        [String] $SqlpsSetupRoot = '',

        [String] $MuranoFileShare = '',

        # (REQUIRED) Domain name
        [String] $SQLServiceUserDomain = 'fc-acme.local',

        # (REQUIRED) User name for the account which will be used by SQL service
        [String] $SQLServiceUserName = 'Administrator',

        # (REQUIRED) Password for that user
        [String] $SQLServiceUserPassword = 'P@ssw0rd',

        [Switch] $UpdateEnabled
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

        if ($MuranoFileShare -eq '') {
            $MuranoFileShare = [String]([Environment]::GetEnvironmentVariable('MuranoFileShare'))
            if ($MuranoFileShare -eq '') {
                throw "Unable to find MuranoFileShare path."
            }
        }
        Write-LogDebug "MuranoFileShare = '$MuranoFileShare'"

        if ($SetupRoot -eq '') {
            $SetupRoot = [IO.Path]::Combine("$MuranoFileShare", 'Prerequisites\SQL Server\2012')
        }
        Write-LogDebug "SetupRoot = '$SetupRoot'"

        $ExtraOptions = @{}

        if ($UpdateEnabled) {
            $ExtraOptions += @{'UpdateEnabled' = $true}
        }
        else {
            $ExtraOptions += @{'UpdateEnabled' = $false}
        }

        $null = New-SQLServerForAOAG `
            -SetupRoot $SetupRoot `
            -SQLSvcUsrDomain $SQLServiceUserDomain `
            -SQLSvcUsrName $SQLServiceUserName `
            -SQLSvcUsrPassword $SQLServiceUserPassword `
            -ExtraOptions $ExtraOptions
    }
}



function Initialize-AlwaysOnAvailabilityGroup {
    param (
        [String] $DomainName,
        [String] $DomainAdminAccountName,
        [String] $DomainAdminAccountPassword,
        [String] $SqlServiceAccountName,
        [String] $PrimaryNode,
        [String] $ShareName = 'SharedWorkDir'
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

        $ShareNetworkPath = '\\' + $PrimaryNode + '\' + $ShareName

        $DomainAdminAccountCreds = New-Credential `
            -UserName "$DomainName\$DomainAdminAccountName" `
            -Password "$DomainAdminAccountPassword"

        $FunctionsFile = Export-Function 'Get-NextFreePort', 'Initialize-AlwaysOn'

        $null = Start-PowerShellProcess @"
trap {
    `$_
    exit 1
}

Import-Module CoreFunctions

Write-Log "Importing functions file '$FunctionsFile' ..."
. "$FunctionsFile"

Write-Log "Starting 'Initialize-AlwaysOn' ..."
`$XmlFile = [IO.Path]::Combine("$ShareNetworkPath", "`$(`$Env:ComputerName).xml")
Write-Log "Output XML file is '`$XmlFile'"
Initialize-AlwaysOn | Export-CliXml -Path `$XmlFile
"@ -Credential $DomainAdminAccountCreds -NoBase64
    }
}


function New-SharedFolderForAOAG {
    param (
        # (OPTIONAL)
        [String] $SharePath = [IO.Path]::Combine($Env:SystemDrive + '\', 'SharedWorkDir'),

        # (OPTIONAL)
        [String] $ShareName = 'SharedWorkDir',

        [String] $PrimaryNode = ' '
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

        if ($PrimaryNode.ToLower() -ne ($Env:ComputerName).ToLower()) {
            Write-Log "This script runs on primary node only."
            Write-Log "Exiting script."
            return
        }

        if ($ShareName -eq '') {
            $ShareName = [IO.Path]::GetFileNameWithoutExtension($SharePath)
        }

        Write-LogDebug "SharePath = '$SharePath'"
        Write-LogDebug "ShareName = '$ShareName'"

        try {
            Write-LogDebug "Trying to remove share '$ShareName'"
            $null = Get-SmbShare -Name $ShareName -ErrorAction 'Stop'
            $null = Remove-SmbShare -Name $ShareName -Force
            write-Log "Share '$ShareName' removed."
        }
        catch {
            Write-LogWarning "Share '$ShareName' not exists or cannot be deleted."
        }

        try {
            Write-LogDebug "Trying to remove folder '$SharePath"
            $null = Get-Item -Path $SharePath -ErrorAction 'Stop'
            $null = Remove-Item -Path $SharePath -Recurse -Force
            Write-Log "Folder '$SharePath' removed."
        }
        catch {
            Write-LogWarning "Folder '$SharePath' not exists or cannot be deleted."
        }

        $null = New-Item -Path $SharePath -ItemType Container -Force
                
        $null = New-SmbShare -Path $SharePath `
            -Name $ShareName `
            -FullAccess "Everyone" `
            -Description "Shared folder for AlwaysOn Availability Group setup."

        return '\\' + $Env:ComputerName + '\' + $ShareName
    }
}



function New-DatabaseForAOAG {
    param (
        [String] $DatabaseName,
        [String] $DomainName,
        [String] $UserName,
        [String] $UserPassword
    )

    $Creds = New-Credential -UserName "$DomainName\$UserName" -Password "$UserPassword"

    $FunctionsFile = Export-Function 'Invoke-SQLText', 'ConvertTo-SQLName', 'ConvertTo-SQLString', 'New-SQLDatabase'

    Start-PowerShellProcess @"
trap {
    `$_
    exit 1
}

Import-Module CoreFunctions

Write-Log "Importing functions from file '$FunctionsFile' ..."
. "$FunctionsFile"

Write-Log "Starting 'New-SQLDatabase' ..."
New-SQLDatabase $DatabaseName
"@ -Credential $Creds -NoBase64
}



function Initialize-AOAGPrimaryReplica {
    param (
        # (OPTIONAL) Name of the new Availability Group. If not specified then default name will be used.
        [String] $GroupName = 'MuranoAG',

        # (REQUIRED) Nodes that will be configured as replica partners.
        #[Parameter(Mandatory=$true)]
        [String[]] $NodeList,

        # (REQUIRED) Node name that will be primary for selected Availability Group
        #[Parameter(Mandatory=$true)]
        [String] $PrimaryNode,

        # (REQUIRED) Database list that will be added to the Availability Group
        #[Parameter(Mandatory=$true)]
        [String[]] $DatabaseList,

        # (REQUIRED) Listener name that will be used by clients to connect to databases in that AG
        #[Parameter(Mandatory=$true)]
        [String] $ListenerName = 'MuranoAG_Listener',

        # (REQUIRED) IP address of the listener
        #[Parameter(Mandatory=$true)]
        [String] $ListenerIP,

        [String] $ListenerIPMask = '255.255.255.0',

        [String] $ListenerPort = '5023',

        # Sync Mode Node List
        [String[]] $SyncModeNodeList,

        [String] $SharedWorkDir = 'SharedWorkDir',

        [String] $CliXmlFile = '',

        [String] $DomainName,
        [String] $UserName,
        [String] $UserPassword
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

        Write-Log "Primary node: '$($PrimaryNode.ToLower())'"
        Write-Log "Current node: '$(($Env:ComputerName).ToLower())'"

        if ($PrimaryNode.ToLower() -ne $($Env:ComputerName).ToLower()) {
            Write-Log "This function works on PrimaryNode only."
            Write-Log "Exiting."
            return
        }

        if ($CliXmlFile -eq '') {
            $ReplicaDefinitionList = @()
            foreach ($Node in $NodeList) {
                try {
                    $NodeEndpointPort = Import-CliXml -Path "\\$PrimaryNode\SharedWorkDir\$Node.xml"
                }
                catch {
                    Write-Log "Using default endpoint port 5022"
                    $NodeEndpointPort = 5022
                }

                $ReplicaDefinition = @{
                    "SERVER_INSTANCE" = "$Node";
                    "ENDPOINT_URL" = "TCP://${Node}:${NodeEndpointPort}";
                    "AVAILABILITY_MODE" = "ASYNCHRONOUS_COMMIT";
                    "FAILOVER_MODE"="MANUAL";
                }

                if ($SyncModeNodeList -contains $Node) {
                    Write-Log "$Node is in SyncModeNodeList"
                    $ReplicaDefinition['AVAILABILITY_MODE'] = "SYNCHRONOUS_COMMIT"
                    $ReplicaDefinition['FAILOVER_MODE'] = "AUTOMATIC"
                }
                else {
                    Write-Log "$Node is NOT in SyncModeNodeList"
                }

                $ReplicaDefinitionList += @($ReplicaDefinition)
            }

            $Preferences = @{}

            $ListenerDefinition = @{
                "NAME"=$ListenerName;
                "PORT" = "$ListenerPort";
                "STATIC" = "$ListenerIP/$ListenerIPMask"
            }

            $Parameters = @{
                'WorkDir' = "\\$PrimaryNode\$SharedWorkDir";
                'Name' = $GroupName;
                'DatabaseNames' = $DatabaseList;
                'ReplicaDefs' = $ReplicaDefinitionList;
                'Preferences' = $Preferences;
                'ListenerDef' = $ListenerDefinition;
            }

            $null = Remove-Item -Path "\\$PrimaryNode\SharedWorkDir\*" -Force

            $CliXmlFile = [IO.Path]::GetTempFileName()

            Write-LogDebug "CliXml file: '$CliXmlFile'"

            $null = Export-CliXml -Path $CliXmlFile -InputObject $Parameters -Depth 10

            $null = Initialize-AOAGPrimaryReplica `
                -CliXmlFile $CliXmlFile `
                -DomainName $DomainName `
                -UserName $UserName `
                -UserPassword $UserPassword `
                -PrimaryNode $PrimaryNode

            Write-LogDebug "Inner 'Initialize-AOAGPrimaryReplica' call completed."
        }
        else {
            $Creds = New-Credential -UserName "$DomainName\$UserName" -Password "$UserPassword"

            $FunctionsFile = Export-Function -All

            $null = Start-PowerShellProcess @"
trap {
    `$_
    exit 1
}

Import-Module CoreFunctions

Write-Log "Importing functions from '$FunctionsFile' ..."
. "$FunctionsFile"

Write-Log "Importing CliXml parameters file ..."
`$Parameters = Import-CliXml -Path $CliXmlFile

Write-Log "Starting 'New-AlwaysOnAvailabilityGroup' ..."
New-AlwaysOnAvailabilityGroup ``
    -WorkDir `$Parameters['WorkDir'] ``
    -Name `$Parameters['Name'] ``
    -DatabaseNames `$Parameters['DatabaseNames'] ``
    -ReplicaDefs `$Parameters['ReplicaDefs'] ``
    -Preferences `$Parameters['Preferences'] ``
    -ListenerDef `$Parameters['ListenerDef']
"@ -Credential $Creds -NoBase64
        }
    }
}



function Initialize-AOAGSecondaryReplica {
    param (
        # (REQUIRED) Nodes that will be configured as replica partners.
        [Parameter(Mandatory=$true)]
        [String[]] $NodeList,

        # (REQUIRED) Node name that will be primary for selected Availability Group
        [Parameter(Mandatory=$true)]
        [String] $PrimaryNode,

        [String] $SharedWorkDir = 'SharedWorkDir',

        [String] $DomainName,
        [String] $UserName,
        [String] $UserPassword
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

        if ($PrimaryNode.ToLower() -eq ($Env:ComputerName).ToLower()) {
            Write-Log "This function works on any SecondaryNode only."
            Write-Log "Exiting."
            return
        }

        $Creds = New-Credential -UserName "$DomainName\$UserName" -Password "$UserPassword"

        $FunctionsFile = Export-Function -All

        $null = Start-PowerShellProcess @"
trap {
    $_
    exit 1
}

Import-Module CoreFunctions

Write-Log "Importing functions from '$FunctionsFile' ..."
. "$FunctionsFile"

Write-Log "Starting 'New-AlwaysOnAvailabilityGroupReplica' ..."
New-AlwaysOnAvailabilityGroupReplica -WorkDir "\\$PrimaryNode\$SharedWorkDir"
"@ -Credential $Creds -NoBase64
    }
}



function Disable-Firewall {
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

        netsh advfirewall set allprofiles state off
    }
}



function Enable-Firewall {
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

        netsh advfirewall set allprofiles state on
    }
}



function Enable-TrustedHosts {
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

        Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force
    }
}
