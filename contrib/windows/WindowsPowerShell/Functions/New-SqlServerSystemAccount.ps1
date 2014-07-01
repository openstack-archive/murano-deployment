
trap {
    &$TrapHandler
}



function New-SqlServerSystemAccount {
    param (
        # (REQUIRED) Domain Name
        [Parameter(Mandatory=$true)]
        [String] $DomainName,

        # (REQUIRED) User name who has permissions to create and modify userPassword
        # Usually this is the domain administrator '$domainName\Administrator' account
        [Parameter(Mandatory=$true)]
        [String] $UserName,

        # (REQUIRED) Password for that user
        [Parameter(Mandatory=$true)]
        [String] $UserPassword,

        # (REQUIRED) User name for a new account that will be used to run SQL Server
        [Parameter(Mandatory=$true)]
        [String] $SQLServiceUserName,

        # (REQUIRED) Password for that user
        [Parameter(Mandatory=$true)]
        [String] $SQLServiceUserPassword,

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
            Write-Log "THis function runs on AOAG primary node only."
            Write-Log "Exiting."
            return
        }

        Write-Log "Installing 'RSAT-AD-PowerShell' ... "
        Add-WindowsFeature RSAT-AD-PowerShell

        Import-Module ActiveDirectory

        $Creds = New-Credential -UserName "$DomainName\$UserName" -Password "$UserPassword"

        Write-Log "Adding new user ..."
        $null = New-ADUser `
            -Name $SQLServiceUserName `
            -AccountPassword $(ConvertTo-SecureString -String $SQLServiceUserPassword -AsPlainText -Force) `
            -Credential $Creds `
            -ErrorAction 'Stop'
    }
}
