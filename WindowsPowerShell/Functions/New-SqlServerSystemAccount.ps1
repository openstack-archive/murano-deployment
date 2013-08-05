
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

    if ($PrimaryNode.ToLower() -ne ($Env:ComputerName).ToLower()) {
        Write-Log "THis function runs on AOAG primary node only."
        Write-Log "Exiting."
        return
    }

    if ((Get-Module -Name 'ActiveDirectory') -eq $null) {
        Add-WindowsFeature RSAT-AD-PowerShell
    }

    if ((Get-Module -Name 'ActiveDirectory') -eq $null) {
        throw "Module 'ActiveDirectory' is not available."
    }

    $Creds = New-Credential -UserName "$DomainName\$UserName" -Password "$UserPassword"

    $null = New-ADUser `
        -Name $SQLServiceUserName `
        -AccountPassword $(ConvertTo-SecureString -String $SQLServiceUserPassword -AsPlainText -Force) `
        -Credential $Creds
}
