
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
        [String] $SQLServiceUserPassword
    )
}
