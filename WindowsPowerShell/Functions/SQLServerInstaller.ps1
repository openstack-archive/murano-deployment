Import-Module NetSecurity

#Import-Module OptionParser
#Import-Module SQLServerOptionParsers

#$ErrorActionPreference = 'Stop'

function Test-Key([string]$path, [string]$key)
{
    if(!(Test-Path $path)) { return $false }
    if ((Get-ItemProperty $path).$key -eq $null) { return $false }
    return $true
}

function Resolve-SQLServerPrerequisites {
    <#
    .SYNOPSIS
    Installs MS SQL Server prerequisites (.Net Framework 3.5)

    .DESCRIPTION
    Installs MS SQL Server prerequisites (.Net Framework 3.5)

    #>
    if (-not (Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v3.5" "Install")) {
        Import-Module ServerManager
        Write-Host ".Net Framework 3.5 not found. Installing it using Server Manager..."
        $Feature = Get-WindowsFeature NET-Framework
        if ($Feature -eq $null) {
            # We are probably on Windows Server 2012
            $Feature = Get-WindowsFeature NET-Framework-Core
        }
        if (-not $Feature) {
            throw ".Net framework 3.5 feature was not found."
        }
        if (-not $Feature.DisplayName -match "3.5") {
            Log-Warning ".Net framework 3.5 is required, but $($Feature.DisplayName) is available as Windows feature. Proceeding with installation"
        }
        [void](Add-WindowsFeature $Feature)
    }
}

function New-SQLServer {
    <#
    .SYNOPSIS
    Installs new MS SQL Server instance. Returns $true if a reboot is required after the installation, 
    $false if a reboot is not required and throws an exception in case if installation fails.

    .DESCRIPTION
    Installs new MS SQL Server instance in unattended mode.

    .PARAMETER SetupRoot
    MS SQL Server installation files root directory. Normally it is just DVD drive name.

    .PARAMETER ExtraFeatures
    List of features to be installed in addition to default "SQLEngine", "Conn", "SSMS", "ADV_SSMS".
    #>

    param(
        [parameter(Mandatory = $true)]
        [string]$SetupRoot,
        [array]$ExtraFeatures = @(),
        [Hashtable]$ExtraOptions = @{}
    )

    $SetupDir = Get-Item $SetupRoot
    $SetupExe = $SetupDir.GetFiles("setup.exe")[0]

    Resolve-SQLServerPrerequisites

    $parser = New-OptionParserInstall
    $ExitCode = $parser.ExecuteBinary($SetupExe.FullName, @{"Q" = $null; "FEATURES" = @("SQLEngine", "Conn", "SSMS", "ADV_SSMS") + $ExtraFeatures} + $ExtraOptions)

    if ($ExitCode -eq 3010) {
        return $true
    }

    if ($ExitCode -ne 0) {
        throw "Installation executable exited with code $("{0:X8}" -f $ExitCode) (Decimal: $ExitCode)"
    }

    return $false
}

function New-SQLServerForAOAG {
    <#
    .SYNOPSIS
    Installs new MS SQL Server instance with all needed features to set up AlwaysOn Availability Group.
    Returns $true if a reboot is required after the installation, $false if a reboot is not required 
    and throws an exception in case if installation fails.

    .DESCRIPTION
    Installs new MS SQL Server instance in unattended mode. All features for AlwaysOn Availability Groups are
    installed.

    All availability group members must be installed with the same SQLSvcUsrDoman, SQLSvcUsrName and SQLSvcUsrPassword parameters.
    User must be a domain user since it will be used for nodes interconnection.

    .PARAMETER SetupRoot
    MS SQL Server installation files root directory. Normally it is just DVD drive name.

    .PARAMETER SQLSvcUsrDomain
    MS SQL Server user account domain name.

    .PARAMETER SQLSvcUsrName
    MS SQL Server user account name.

    .PARAMETER SQLSvcUsrPassword
    MS SQL Server user account password.

    .PARAMETER ExtraFeatures
    List of features to be removed besides "SQLEngine", "Conn", "SSMS", "ADV_SSMS", "DREPLAY_CTLR", "DREPLAY_CLT".
    #>

    param(
        [parameter(Mandatory = $true)]
        [string]$SetupRoot,
        [parameter(Mandatory = $true)]
        [string]$SQLSvcUsrDomain,
        [parameter(Mandatory = $true)]
        [string]$SQLSvcUsrName,
        [parameter(Mandatory = $true)]
        [string]$SQLSvcUsrPassword,
        [array]$ExtraFeatures = @()
    )

    $SetupDir = Get-Item $SetupRoot
    $SetupExe = $SetupDir.GetFiles("setup.exe")[0]

    $SQLUser = "$SQLSvcUsrDomain\$SQLSvcUsrName"
    $domain = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$SQLSvcUsrDomain", $SQLSvcUsrName, $SQLSvcUsrPassword)

    if ($domain.name -eq $null) {
        throw "Credentials validation failed for user $SQLUser. Check domain, login name and password."
    }

    Resolve-SQLServerPrerequisites

    $parser = New-OptionParserInstall
    $ExitCode = $parser.ExecuteBinary($SetupExe.FullName, @{"QS" = $null; "FEATURES" = @("SQLEngine", "Conn", "SSMS", "ADV_SSMS", "DREPLAY_CTLR", "DREPLAY_CLT") + $ExtraFeatures;
        "AGTSVCACCOUNT" = $SQLUser; "AGTSVCPASSWORD" = $SQLSvcUsrPassword; "ASSVCACCOUNT" = $SQLUser; "ASSVCPASSWORD" = $SQLSvcUsrPassword; "ASSYSADMINACCOUNTS" = $SQLUSer;
        "SQLSVCACCOUNT" = $SQLUser; "SQLSVCPASSWORD" = $SQLSvcUsrPassword; "SQLSYSADMINACCOUNTS" = $SQLUser; "ISSVCACCOUNT" = $SQLUser; "ISSVCPASSWORD" = $SQLSvcUsrPassword; 
        "RSSVCACCOUNT" = $SQLUser; "RSSVCPASSWORD" = $SQLSvcUsrPassword})

    if ($ExitCode -eq 3010) {
        return $true
    }

    if ($ExitCode -ne 0) {
        throw "Installation executable exited with code $("{0:X8}" -f $ExitCode) (Decimal: $ExitCode)"
    }

    return $false
}

function Remove-SQLServer {
    <#
    .SYNOPSIS
    Uninstalls MS SQL Server instance installed with New-SQLServer cmdlet

    .DESCRIPTION
    Uninstalls MS SQL Server instance installed with New-SQLServer cmdlet in unattended mode

    .PARAMETER SetupRoot
    MS SQL Server installation files root directory. Normally it is just DVD drive name.

    .PARAMETER ExtraFeatures
    List of features to be removed besides "SQLEngine", "Conn", "SSMS", "ADV_SSMS".
    #>

    param(
        [parameter(Mandatory = $true)]
        [string]$SetupRoot,
        [array]$ExtraFeatures = @()
    )

    $SetupDir = Get-Item $SetupRoot
    $SetupExe = $SetupDir.GetFiles("setup.exe")[0]

    $parser = New-OptionParserUninstall
    $ExitCode = $parser.ExecuteBinary($SetupExe.FullName, @{"Q" = $null; "FEATURES" = @("SQLEngine", "Conn", "SSMS", "ADV_SSMS") + $ExtraFeatures})

    if ($ExitCode -ne 0) {
        throw "Installation executable exited with code $("{0:X8}" -f $ExitCode)"
    }
}

function Install-SQLServerForSysPrep {
    <#
    .SYNOPSIS
    Installs new MS SQL Server in sysprep mode.

    .DESCRIPTION
    Installs new MS SQL Server in sysprep mode. Returns $true if a reboot is required after the installation, 
    $false if a reboot is not required and throws an exception in case if installation fails.

    Setup must be completed after booting rearmed machine by using Complete-SQLServer cmdlet

    .PARAMETER SetupRoot
    MS SQL Server installation files root directory. Normally it is just DVD drive name.

    .PARAMETER ExtraFeatures
    List of features to be installed in addition to default "SQLEngine". Note that prior to
    SQL Server version 2012 Service Pack 1 Cumulative Update 2 (January 2013) only "Replication", 
    "FullText" and "RS" may be installed in addition to "SQLEngine". See the following link for
    detials: http://msdn.microsoft.com/en-us/library/ms144259.aspx

    #>
}

function Install-SQLServerForSysPrep {
    <#
    .SYNOPSIS
    Installs new MS SQL Server in sysprep mode.

    .DESCRIPTION
    Installs new MS SQL Server in sysprep mode. Returns $true if a reboot is required after the installation, 
    $false if a reboot is not required and throws an exception in case if installation fails.

    Setup must be completed after booting rearmed machine by using Complete-SQLServer cmdlet

    .PARAMETER SetupRoot
    MS SQL Server installation files root directory. Normally it is just DVD drive name.

    .PARAMETER ExtraFeatures
    List of features to be installed in addition to default "SQLEngine". Note that prior to
    SQL Server version 2012 Service Pack 1 Cumulative Update 2 (January 2013) only "Replication", 
    "FullText" and "RS" may be installed in addition to "SQLEngine". See the following link for
    detials: http://msdn.microsoft.com/en-us/library/ms144259.aspx

    #>

    param(
        [parameter(Mandatory = $true)]
        [string]$SetupRoot,
        [array]$ExtraFeatures = @()
    )

    $SetupDir = Get-Item $SetupRoot
    $SetupExe = $SetupDir.GetFiles("setup.exe")[0]

    Resolve-SQLServerPrerequisites

    $parser = New-OptionParserPrepareImage
    $ExitCode = $parser.ExecuteBinary($SetupExe.FullName, @{"QS" = $null; "FEATURES" = @("SQLEngine") + $ExtraFeatures })

    if ($ExitCode -eq 3010) {
        return $true
    }

    if ($ExitCode -ne 0) {
        throw "Installation executable exited with code $("{0:X8}" -f $ExitCode) (Decimal: $ExitCode)"
    }

    return $false
}

function Complete-SQLServerAfterSysPrep {
    <#
    .SYNOPSIS
    Completes previously prepared with "Install-SQLServerForSysPrep" MS SQL Server after the system was rearmed.

    .DESCRIPTION
    Completes previously prepared with "Install-SQLServerForSysPrep" MS SQL Server after the system was rearmed.
    Returns $true if a reboot is required after the installation, $false if a reboot is not required and throws 
    an exception in case if installation fails.

    Setup must be completed after booting rearmed machine by using Complete-SQLServer cmdlet

    .PARAMETER SetupRoot
    MS SQL Server installation files root directory. Normally it is just DVD drive name.
    #>

    param(
        [parameter(Mandatory = $true)]
        [string]$SetupRoot
    )

    $SetupDir = Get-Item $SetupRoot
    $SetupExe = $SetupDir.GetFiles("setup.exe")[0]

    $parser = New-OptionParserCompleteImage
    $ExitCode = $parser.ExecuteBinary($SetupExe.FullName, @{"QS" = $null})

    if ($ExitCode -eq 3010) {
        return $true
    }

    if ($ExitCode -ne 0) {
        throw "Installation executable exited with code $("{0:X8}" -f $ExitCode) (Decimal: $ExitCode)"
    }

    return $false
}

function ConvertTo-SQLString {
    <#
    .SYNOPSIS
    Converts argument to a valid SQL string in quotes

    .DESCRIPTION
    Converts argument to a valid SQL string in quotes. The string may contain any characters.
    See http://msdn.microsoft.com/en-us/library/ms179899.aspx

    .PARAMETER S
    String to convert
    #>
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$S
    )
    
    return "'$($S -replace "'", "''")'"
}

function ConvertTo-SQLName {
    <#
    .SYNOPSIS
    Converts argument to a valid SQL name in brackets

    .DESCRIPTION
    Converts argument to a valid SQL name in brackets. The string may contain any characters.
    See http://msdn.microsoft.com/en-us/library/ms175874.aspx

    .PARAMETER S
    String to convert
    #>
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$S
    )
    return "[$($S -replace "]", "]]")]"
}

function Invoke-SQLText {
    <#
    .SYNOPSIS
    Invokes SQL text

    .DESCRIPTION
    Invokes SQL text. Returns raw SQL server output.

    .PARAMETER SQL
    SQL Text

    .PARAMETER User
    SQL Server user name

    .PARAMETER Password
    SQL Server user password
    #>
    param(
        [parameter(Mandatory = $true)]
        [string]$SQL,
        [string]$User = $null,
        [string]$Password = $null
    )

    #Write-Warning "$SQL`n"
    #return

    $Binary = Get-Command "sqlcmd.exe"

    $tempFile = [IO.Path]::GetTempFileName()
    $tempFile = Get-Item $tempFile
    Set-Content -Path $tempFile -Value $SQL

    $CommandLine = @('-h', '-1', '-b', '-i', "`"$($tempFile.FullName)`"")
    if (($User -ne $null) -and ($User -ne '')) {
        $CommandLine = $CommandLine + '-U'
        $CommandLine = $CommandLine + $User
        $CommandLine = $CommandLine + '-P'
        $CommandLine = $CommandLine + $Password
    }

    Write-Debug "Executing: `n$SQL`n"
    [string]$output = &$Binary $CommandLine

    $ExitCode = $LastExitCode
    if ($ExitCode -ne 0) {
        Write-Warning $output
        throw "SQLCMD.EXE returned with exit code $ExitCode while running $Binary $CommandLine"
    }
   
    Remove-Item $tempFile

    return $output
}

function New-SQLUser {
    <#
    .SYNOPSIS
    Invokes SQL text

    .DESCRIPTION
    Invokes SQL text

    .PARAMETER SQL
    SQL Text

    .PARAMETER User
    SQL Server user name

    .PARAMETER Password
    SQL Server user password
    #>
    param(
        [parameter(Mandatory = $true)]
        [string]$SQL,
        [string]$User = $null,
        [string]$Password = $null
    )
}

function New-Password {
    <#
    .SYNOPSIS
    Creates random password of the specified length

    .DESCRIPTION
    Password contains random characters a-z, A-Z, numbers and special characters.
    There is no guarantee that all the types of symbols will be present in the password.

    .PARAMETER Length
    Desired length of the password.

    #>
    param(
        [parameter(Mandatory = $true)]
        [int]$Length=6
    )

    $Result = ""
    $alpha = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()'`"``_+[]\{}|;:,./<>?~"
    while ($Length -gt 0) {
        $x = Get-Random $alpha.Length
        $c = $alpha[$x]
        $Result = "$Result$c"
        $Length = $Length - 1
    }
    return $Result
}

function Initialize-MirroringEndpoint {
    <#
    .SYNOPSIS
    Creates mirroring endpoint.

    .DESCRIPTION
    Master key is created if necessary. Host certificate is created when necessary either (normally on first endpoint creation).

    Endpoint and certificate are recreated in case if master key did not existed (should not normally happen).

    Endpoint is recreated in case if certificate did not existed (should not happen unless the endpoint was created manually).

    Mirroring endpoint is created unless one already exists. The endpoint is created with the specified name. When the endpoint
    already exists is is unchanged.

    Endpoint port is selected automatically as 4022 or as first available port after 4022 in case if 4022 is already listening.
    If there is no firewall rule with name 'DatabaseMirroring-TCP-{portnumber}', allowing rule is created.

    Certificate is stored in the specified file.

    Returns endpoint listening port.

    .PARAMETER EncryptionPassword
    Encryption password used to create certificate.

    .PARAMETER CertificateFileName
    Certificate target file name. File MUST NOT exist.

    #>

    param(
        [parameter(Mandatory = $true)]
        [String]$EncryptionPassword,
        [parameter(Mandatory = $true)]
        [String]$CertificateFileName
    )

    $EndpointName = 'MirroringEndpoint'

    $Folder = Get-Item $WorkDir

    $H = $Env:COMPUTERNAME -replace '[^A-Za-z0-9_]', '_'

    $Port = Get-NextFreePort 4022

    $CreateMasterKey = "USE master;

                        IF NOT EXISTS(select * from sys.symmetric_keys where name = '##MS_DatabaseMasterKey##')
                        BEGIN
                            CREATE MASTER KEY ENCRYPTION BY PASSWORD = $(ConvertTo-SQLString $EncryptionPassword);
                            IF EXISTS(select * from sys.certificates where name = '${H}_cert')
                            BEGIN
                                DROP CERTIFICATE ${H}_cert
                            END
                            IF EXISTS(SELECT * FROM sys.endpoints WHERE type_desc='DATABASE_MIRRORING')
                            BEGIN
                                DECLARE `@name VARCHAR(255)
                                SELECT TOP 1 `@name = name FROM sys.endpoints WHERE type_desc='DATABASE_MIRRORING'
                                EXEC ('DROP ENDPOINT [' + `@name + ']')
                            END
                        END
                        GO

                        IF NOT EXISTS(select * from sys.certificates where name = '${H}_cert')
                        BEGIN
                            CREATE CERTIFICATE ${H}_cert WITH SUBJECT = '${H} endpoint certificate';
                            IF EXISTS(SELECT * FROM sys.endpoints WHERE type_desc='DATABASE_MIRRORING')
                            BEGIN
                                DECLARE `@name VARCHAR(255)
                                SELECT TOP 1 `@name = name FROM sys.endpoints WHERE type_desc='DATABASE_MIRRORING'
                                EXEC ('DROP ENDPOINT [' + `@name + ']')
                            END
                        END
                        GO

                        BACKUP CERTIFICATE ${H}_cert TO FILE = $(ConvertTo-SQLString "$CertificateFileName");
                        GO

                        DECLARE `@port int
                        IF EXISTS(SELECT * FROM sys.endpoints WHERE type_desc='DATABASE_MIRRORING')
                        BEGIN
                            SELECT `@port = port FROM sys.tcp_endpoints WHERE type_desc='DATABASE_MIRRORING'
                        END ELSE
                        BEGIN
                            CREATE ENDPOINT $(ConvertTo-SQLName $EndpointName)
                                STATE = STARTED
                                AS TCP (
                                    LISTENER_PORT = $Port
                                    , LISTENER_IP = ALL
                                ) 
                                FOR DATABASE_MIRRORING ( 
                                    AUTHENTICATION = CERTIFICATE ${H}_cert
                                    , ENCRYPTION = REQUIRED ALGORITHM AES
                                    , ROLE = ALL
                                );
                            SELECT `@port = $Port
                        END

                        SELECT 'port:(' + CONVERT(VARCHAR, `@port) + ')' as port
                        GO

                        "

    $rawdata = Invoke-SQLText -SQL $CreateMasterKey
    [int]$Port = $rawdata -replace '.*port:\(([^)]*)\).*', '$1'

    # Open port in Windows Firewall

    $PortOpen = $false
    $RuleName = "DatabaseMirroring-TCP-$Port"
    Get-NetFirewallRule | Foreach-Object {
        if ($_.Name -eq $RuleName) {
            $PortOpen = $true
        }
    }
    if (-not $PortOpen) {
        $DisplayName = "MS SQL Database Mirroring Endpoint at TCP port $Port"
        New-NetFirewallRule -Name $RuleName -DisplayName $DisplayName -Description $DisplayName -Protocol TCP -LocalPort $Port -Enabled True -Profile Any -Action Allow
    }
     
    return $Port
}

function Complete-MirroringEndpoint {
    <#
    .SYNOPSIS
    Completes mirroring endpoint

    .DESCRIPTION
    Allows inbound connections from remote host
    #>

    param(
        [parameter(Mandatory = $true)]
        [String]$RemoteHostName,
        [parameter(Mandatory = $true)]
        [String]$RemoteWorkDir,
        [String]$RemoteHostLogin,
        [String]$RemoteHostUser,
        [String]$RemoteHostPassword
    )

    $Folder = Get-Item $RemoteWorkDir
    $RemoteWorkDir = $Folder.FullName

    $H = $RemoteHostName -replace '[^A-Za-z0-9_]', '_'

    if (-not $RemoteHostLogin) {
        $RemoteHostLogin = "${H}_login"
    }
    if (-not $RemoteHostUser) {
        $RemoteHostUser = "${H}_user"
    }
    if (-not $RemoteHostPassword) {
        $RemoteHostPassword = "$(New-Password 10)aA#3"
    }

    $SQL =             "USE master;

                        IF NOT EXISTS(select * from sys.sql_logins where name=$(ConvertTo-SQLString $RemoteHostLogin))
                        BEGIN
                            CREATE LOGIN $(ConvertTo-SQLName $RemoteHostLogin) WITH PASSWORD = $(ConvertTo-SQLString $RemoteHostPassword);
                        END
                        GO

                        IF NOT EXISTS(select * from sys.sysusers where name=$(ConvertTo-SQLString $RemoteHostUser))
                        BEGIN
                            CREATE USER $(ConvertTo-SQLName $RemoteHostUser) FOR LOGIN $(ConvertTo-SQLName $RemoteHostLogin);
                        END
                        GO

                        IF EXISTS(select * from sys.certificates where name='${H}_remote_cert')
                        BEGIN
                            DROP CERTIFICATE ${H}_remote_cert
                        END
                        GO

                        CREATE CERTIFICATE ${H}_remote_cert AUTHORIZATION $(ConvertTo-SQLName $RemoteHostUser) FROM FILE = $(ConvertTo-SQLString "$RemoteWorkDir\certificate.cer");
                        GO

                        DECLARE `@name VARCHAR(255)
                        SELECT TOP 1 `@name = name FROM sys.endpoints WHERE type_desc='DATABASE_MIRRORING'
                        SELECT 'name:(' + `@name + ')' as name
                        "

    $rawdata = Invoke-SQLText -SQL $SQL
    $EndpointName = $rawdata -replace '.*name:\(([^)]*)\).*', '$1'
    $SQL =             "GRANT CONNECT ON ENDPOINT::$(ConvertTo-SQLName $EndpointName) TO $(ConvertTo-SQLName $RemoteHostLogin)"
    [void](Invoke-SQLText -SQL $SQL)
}

function Complete-SQLMirror {
    <#
    .SYNOPSIS
    Completes creation of mirrored SQL database

    .DESCRIPTION
    This cmdlet should be first executed on mirror server and then on principal server.
    Otherwise it will fail (however it may be executed again with no harm).
    #>

    param(
        [parameter(Mandatory = $true)]
        [String]$RemoteHostName,
        [parameter(Mandatory = $true)]
        [Int]$RemotePort,
        [parameter(Mandatory = $true)]
        [String]$DatabaseName
    )

    $Url = "TCP://${RemoteHostName}:${RemotePort}"
    $AlterDb = "ALTER DATABASE $(ConvertTo-SQLName $DataBaseName) SET PARTNER = $(ConvertTo-SQLString $Url);
                GO"
    [void](Invoke-SQLText -SQL $AlterDb)
}

function New-SQLDatabase {
    <#
    .SYNOPSIS
    Creates empty SQL database

    .DESCRIPTION
    Creates empty SQL database with default settings. Fails in case is the database already exists.

    .PARAMETER DataBaseName
    Database name.

    .PARAMETER mdfFile
    Name of the MDF (data) file. If not specified, the following value is used:
    "C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\{DataBasePathName}.mdf"
    Where {DataBasePathName} is database name with all but A-Z, a-z, 0-9 characters
    replaced by underscore.

    .PARAMETER DataBaseName
    Name of the LDF (transaction log) file. If not specified, the following value is used:
    "C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\{DataBasePathName}_log.mdf"
    Where {DataBasePathName} is database name with all but A-Z, a-z, 0-9 characters
    replaced by underscore.
    #>

    param(
        [parameter(Mandatory = $true)]
        [String]$DataBaseName,
        [String]$mdfFile=$null,
        [String]$ldfFile=$null
    )

    $DataBasePathName = $DataBaseName -replace '[^0-9a-zA-Z]', '_'
    if (-not $mdfFile) {
        $mdfFile = "C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\${DataBasePathName}.mdf"
    }
    if (-not $ldfFile) {
        $ldfFile = "C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\${DataBasePathName}_log.ldf"
    }

    $NewDatabase = "
        CREATE DATABASE $(ConvertTo-SQLName $DataBaseName)
                CONTAINMENT = NONE
                ON  PRIMARY 
            ( NAME = N$(ConvertTo-SQLString $DataBaseName), FILENAME = N$(ConvertTo-SQLString $mdfFile) , SIZE = 4096KB , FILEGROWTH = 1024KB )
                LOG ON 
            ( NAME = N$(ConvertTo-SQLString "${DataBaseName}_log"), FILENAME = N$(ConvertTo-SQLString $ldfFile) , SIZE = 1024KB , FILEGROWTH = 10%)
        GO
        USE $(ConvertTo-SQLName $DataBaseName)
        GO
        IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE $(ConvertTo-SQLName $DataBaseName) MODIFY FILEGROUP [PRIMARY] DEFAULT
        GO"

    [void](Invoke-SQLText -SQL $NewDatabase)
}

function Initialize-SQLMirroringPrincipalStep1 {
    <#
    .SYNOPSIS
    Prepares principal SQL Server for database mirroring (Stage 1)

    .DESCRIPTION
    Initializes mirroring endpoint (this is absolutely symmetric step to the mirror init). In addition to that it creates
    a database and stores backups of it and its transaction log in the same directory as the endpoint certificate.

    A firewall rule is created for endpoint if necessary.

    .PARAMETER WorkDir
    Workind directory. This directory should be tranferred to the mirror server after this
    step is executed.

    .PARAMETER DatabaseName
    Mirrored database name. This name MUST be use at mirror server either.
    
    #>

    param(
        [parameter(Mandatory = $true)]
        [String]$WorkDir,
        [parameter(Mandatory = $true)]
        [String]$DataBaseName
    )

    [String]$EncryptionPassword = "$(New-Password 10)aA#3"

    if (-not (Test-Path $WorkDir)) {
        [void](New-Item -Type Directory $WorkDir)
    }
    $WorkDir = (Get-Item $WorkDir).FullName
    if ((Get-ChildItem -Path $WorkDir).Length -gt 0) {
        throw "Working directory $WorkDir is not empty"
    }

    $EndpointPort = Initialize-MirroringEndpoint $EncryptionPassword "$WorkDir\certificate.cer"
    $EndpointPort | Set-Content "$WorkDir\endpoint-port.txt"
    New-SQLDatabase $DataBaseName

    $BackupDb = "BACKUP DATABASE $(ConvertTo-SQLName $DataBaseName) TO DISK = N$(ConvertTo-SQLString "$WorkDir\Source.bak") WITH NOFORMAT, INIT, NAME = N'Full Database Backup', SKIP, NOREWIND, NOUNLOAD, STATS = 10
                 GO"
    [void](Invoke-SQLText -SQL $BackupDb)
    $BackupLog = "BACKUP LOG $(ConvertTo-SQLName $DataBaseName) TO DISK = N$(ConvertTo-SQLString "$WorkDir\Source_log.bak") WITH NOFORMAT, INIT,  NAME = N'Transaction Log  Backup', SKIP, NOREWIND, NOUNLOAD, STATS = 10
                  GO"
    [void](Invoke-SQLText -SQL $BackupLog)
}

function Initialize-SQLMirroringPrincipalStep2 {
    <#
    .SYNOPSIS
    Prepares principal SQL Server for database mirroring (Stage 2)

    .DESCRIPTION
    Imports remote server certificate and grants it with access to the mirroring endpoint.

    .PARAMETER RemoteHostName
    Remote (mirror) host name. FQDN is preferred, but NetBIOS names and IP addresses are also accepted.

    .PARAMETER RemoteWorkDir
    Path to a copy of workdir obtained from mirror machine created on Stage 1.
    #>

    param(
        [parameter(Mandatory = $true)]
        [String]$RemoteHostName,
        [parameter(Mandatory = $true)]
        [String]$RemoteWorkDir
    )

    if (-not (Test-Path $RemoteWorkDir)) {
        throw "Remote work dir '$RemoteWorkDir' was not found"
    }
    $RemoteWorkDir = (Get-Item $RemoteWorkDir).FullName

    Complete-MirroringEndpoint $RemoteHostName $RemoteWorkDir
}

function Initialize-SQLMirroringPrincipalStep3 {
    <#
    .SYNOPSIS
    Prepares principal SQL Server for database mirroring (Stage 3)

    .DESCRIPTION
    Completes mirror creation. This step must be globally the last one in mirror creation sequence.

    Note that the remote host certificate is valid from the time it is created there. So
    this step will fail if there is noticable different in time local and remote machines.

    .PARAMETER RemoteHostName
    Remote (principal) host name. FQDN is preferred, but NetBIOS names and IP addresses are also accepted.

    .PARAMETER RemoteWorkDir
    Path to a copy of workdir obtained from principal machine created on Stage 1.

    .PARAMETER DatabaseName
    Mirrored database name. This name MUST match principal database name and name provided on step 1.
    #>

    param(
        [parameter(Mandatory = $true)]
        [String]$RemoteHostName,
        [parameter(Mandatory = $true)]
        [String]$RemoteWorkDir,
        [parameter(Mandatory = $true)]
        [String]$DatabaseName
    )

    [int]$port = Get-Content "${RemoteWorkDir}\endpoint-port.txt"
    Complete-SQLMirror $RemoteHostName $port $DatabaseName
}

function Initialize-SQLMirroringMirrorStep1 {
    <#
    .SYNOPSIS
    Prepares mirror SQL Server for database mirroring (Stage1)

    .DESCRIPTION
    Initializes mirroring endpoint for mirror server. Stores mirroring endpoint certificate in Workdir.

    .PARAMETER WorkDir
    Workind directory. This directory should be tranferred to the principal server after this
    step is executed.

    .PARAMETER DatabaseName
    Mirrored database name. This name MUST match principal database name.

    #>

    param(
        [parameter(Mandatory = $true)]
        [String]$WorkDir,
        [parameter(Mandatory = $true)]
        [String]$DatabaseName
    )

    [String]$EncryptionPassword = "$(New-Password 10)aA#3"

    if (-not (Test-Path $WorkDir)) {
        [void](New-Item -Type Directory $WorkDir)
    }
    $WorkDir = (Get-Item $WorkDir).FullName

    $EndpointPort = Initialize-MirroringEndpoint $EncryptionPassword "$WorkDir\certificate.cer"
    $EndpointPort | Set-Content "$WorkDir\endpoint-port.txt"
}

function Initialize-SQLMirroringMirrorStep2 {
    <#
    .SYNOPSIS
    Prepares mirror SQL Server for database mirroring (Stage 2)

    .DESCRIPTION
    Imports remote server certificate and grants it with access to the mirroring endpoint.
    Restores database obtained from principal and leaves it in 'Restoring' state.

    .PARAMETER RemoteHostName
    Remote (principal) host name. FQDN is preferred, but NetBIOS names and IP addresses are also accepted.

    .PARAMETER RemoteWorkDir
    Path to a copy of workdir obtained from principal machine created on Stage 1.

    .PARAMETER DatabaseName
    Mirrored database name. This name MUST match principal database name.

    #>

    param(
        [parameter(Mandatory = $true)]
        [String]$RemoteHostName,
        [parameter(Mandatory = $true)]
        [String]$RemoteWorkDir,
        [parameter(Mandatory = $true)]
        [String]$DataBaseName
    )

    if (-not (Test-Path $RemoteWorkDir)) {
        throw "Remote work dir '$RemoteWorkDir' was not found"
    }
    $RemoteWorkDir = (Get-Item $RemoteWorkDir).FullName

    Complete-MirroringEndpoint $RemoteHostName $RemoteWorkDir

    $RestoreDb = "RESTORE DATABASE $(ConvertTo-SQLName $DataBaseName) FROM DISK = N$(ConvertTo-SQLString "$RemoteWorkDir\Source.bak") WITH FILE = 1, NORECOVERY, NOUNLOAD, REPLACE, STATS = 5
                  GO"
    [void](Invoke-SQLText -SQL $RestoreDb)
    $RestoreLog = "RESTORE LOG $(ConvertTo-SQLName $DataBaseName) FROM DISK = N$(ConvertTo-SQLString "$RemoteWorkDir\Source_log.bak") WITH FILE = 1, NORECOVERY, NOUNLOAD, STATS = 10
                   GO"
    [void](Invoke-SQLText -SQL $RestoreLog)
}

function Initialize-SQLMirroringMirrorStep3 {
    <#
    .SYNOPSIS
    Prepares mirror SQL Server for database mirroring (Stage 3)

    .DESCRIPTION
    Completes mirror creation. This step must be executed strictly before symmetric step on the principal.

    Note that the remote host certificate is valid from the time it is created there. So
    this step will fail if there is noticable different in time local and remote machines.

    .PARAMETER RemoteHostName
    Remote (principal) host name. FQDN is preferred, but NetBIOS names and IP addresses are also accepted.

    .PARAMETER RemoteWorkDir
    Path to a copy of workdir obtained from principal machine created on Stage 1.

    .PARAMETER DatabaseName
    Mirrored database name. This name MUST match principal database name.

    #>

    param(
        [parameter(Mandatory = $true)]
        [String]$RemoteHostName,
        [parameter(Mandatory = $true)]
        [String]$RemoteWorkDir,
        [parameter(Mandatory = $true)]
        [String]$DatabaseName
    )

    [int]$port = Get-Content "${RemoteWorkDir}\endpoint-port.txt"
    Complete-SQLMirror $RemoteHostName $port $DatabaseName
}

function Get-NextFreePort {
    <#
    .SYNOPSIS
    Returns specified desired port or closest next one unoccupied.

    .PARAMETER Port
    Desired port number.

    #>

    param(
        [parameter(Mandatory = $true)]
        [int]$Port
    )
    $OpenPorts = netstat -aon | select-string 'LISTENING' | Foreach-Object { (($_ -replace '^\s*', '' -split '\s+')[1] -split '.*:')[1] } | Sort-Object | Get-Unique
    while ($OpenPorts.Contains(${Port})) {
        $Port = $Port + 1
    }
    return $Port
}

function Initialize-AlwaysOn {
    <#
    .SYNOPSIS
    Initializes AlwaysOn clustering on local SQL server and creates AlwaysOn endpoint listener. Returns AlwaysOn endpoint port number.

    .DESCRIPTION
    Enables AlwaysOn clustering on local SQL server. Creates AlwaysOn TCP endpoint on port 5022 or greater if the one is occupied.   
    #>

    if (!(Test-Path SQLSERVER:\)) {
        Import-Module sqlps
    }
    $MachineName = (Get-ChildItem SQLSERVER:\SQL)[0].PSChildName
    $InstanceName = (Get-ChildItem SQLSERVER:\SQL\$MachineName).PSChildName
    $AlwaysOnEnabled = ((Get-Item SQLSERVER:\SQL\$MachineName\$InstanceName) | select IsHadrEnabled).IsHadrEnabled
    if (-not $AlwaysOnEnabled) {
        Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\$MachineName\$InstanceName" -Force
    }
    $Instance = Get-Item SQLSERVER:\SQL\$MachineName\$InstanceName
    $endpoint = $Instance.Endpoints["AlwaysOnEndpoint"]
    if (-not $endpoint) {
        $Port = Get-NextFreePort 5022
        $endpoint = New-SqlHadrEndpoint AlwaysOnEndpoint -Port $Port -Path SQLSERVER:\SQL\$MachineName\$InstanceName
    } else {
        $Port = $endpoint.Protocol.Tcp.ListenerPort
    } 
    if ($endpoint.EndpointState -ne "Started") {
        $endpoint.Start()
    }    
    return $Port
}

function New-AlwaysOnAvailabilityGroup {
    <#
    .SYNOPSIS
    Creates new AlwaysOn availability group on primary replica.

    .DESCRIPTION
    Creates new AlwaysOn availability group on primary replica.

    .PARAMETER WorkDir
    Workind directory. This directory should be tranferred to the replica server(s) after this
    step is executed.

    .PARAMETER Name
    Availability group name.

    .PARAMETER DatabaseNames
    Replica database(s) names.

    .PARAMETER ReplicaDefs
    Array of replica definition. Each definition is a hash table with replica-specific values.
    
    Mandatory replica definition values are:

        * [String] SERVER_INSTANCE   - Replica server instance name
        * [String] ENDPOINT_URL      - Replica server endpoint URL. Normally it is TCP://fully.qualified.domain.name:5022 
                                       Port number should be obtained with Initialize-AlwaysOn at the replica server
        * [String] AVAILABILITY_MODE - Replica availability mode. Can be "SYNCHRONOUS_COMMIT" or "ASYNCHRONOUS_COMMIT" only.
        * [String] FAILOVER_MODE     - Replica availability mode. Can be "MANUAL" or "AUTOMATIC" only.

    Optional replica definition values are:

        * [Integer] BACKUP_PRIORITY          - Backup priority
        * [Integer] SESSION_TIMEOUT          - Session timeout
        * [String]  P_ALLOW_CONNECTIONS      - Allowed connection types for "Primary" replica mode. Can be "READ_WRITE" or "ALL" only.
        * [Array]   P_READ_ONLY_ROUTING_LIST - List of replicas proviring readonly access when this one is primary.
        * [String]  S_ALLOW_CONNECTIONS      - Allowed connection types for "Secondary" replica mode. Can be one of "NO", "READ_ONLY", "ALL".
        * [String]  S_READ_ONLY_ROUTING_URL  - Replica read-only requests listener URL. Normally default server listener at port 1433 is used.

    .PARAMETER Preferences
    Hash table of general availability group preferences. All the keys are optional. Supported entry keys are:

        * [String]  AUTOMATED_BACKUP_PREFERENCE - Automated backup preference. Can be "PRIMARY", "SECONDARY_ONLY", "SECONDARY" or "NONE".
        * [String]  FAILURE_CONDITION_LEVEL     - Failure condition level. Can be "1", "2", "3", "4" or "5".
        * [Integer] HEALTH_CHECK_TIMEOUT        - Replica health check timeout.

    .PARAMETER ListenerDef
    Hash table containing availability group listener configuration.

    Mandatory listener configuration values are:

        [String] NAME - Listener name.

    Optional listener configuration values are:
    
        [String] PORT - Listener port number. Integer value may be suffixed by a "+" symol (such as "5022+") which allows the routine to
                        select next free port with number greater or equal to the specified value.
        [String] DHCP - DHCP listener address configuration flag. When any value specified, DHCP is used to configure listener
                        (this is also the default behavior). Also, a specific interface for DHCP may be specified as IP_ADDRESS/MASK
                        (like "192.168.1.0/255.255.255.0") as a value of the parameter.
        [Array] STATIC - Static IP addresses to listen. IP addresses may be IPv4 addresses in the "IP_ADDRESS/MASK" form or IPv6
                        addresses in standard IPv6 notation.

    See http://msdn.microsoft.com/en-us/library/ff878399.aspx page for more details regarding all the supported options.
    #>

    param(
        [parameter(Mandatory = $true)]
        [String]$WorkDir,
        [parameter(Mandatory = $true)]
        [String]$Name,
        [parameter(Mandatory = $true)]
        [Array]$DatabaseNames,
        [parameter(Mandatory = $true)]
        [Array]$ReplicaDefs,
        [parameter]
        [Hashtable]$Preferences,
        [parameter(Mandatory = $true)]
        [Hashtable]$ListenerDef
    )

    if (-not (Test-Path $WorkDir)) {
        [void](New-Item -Type Directory $WorkDir)
    }
    $WorkDir = (Get-Item $WorkDir).FullName
    if ((Get-ChildItem -Path $WorkDir).Length -gt 0) {
        throw "Working directory $WorkDir is not empty"
    }

    $QuotedDBNames = ($DatabaseNames | ForEach-Object { ConvertTo-SQLName $_ }) -join ", "

    if ($Preferences -eq $null) {
        $Preferences = @()
    }
    $Prefs = @()
    foreach($Pref in $Preferences) {
        if ($Pref.Key -eq $null) {
            Continue
        }
        if ($Pref.Key -eq "AUTOMATED_BACKUP_PREFERENCE") {
            $Prefs = $Prefs + (Validate-Option $Pref.Key, $Pref.Value, @("PRIMARY", "SECONDARY_ONLY", "SECONDARY", "NONE") | New-ReplicaOption -Name $Pref.Key)
        } elseif ($Pref.Key -eq "FAILURE_CONDITION_LEVEL") {
            $Prefs = $Prefs + (Validate-Option $Pref.Key, $Pref.Value, @("1", "2", "3", "4", "5") | New-ReplicaOption -Name $Pref.Key)
        } elseif ($Pref.Key -eq "HEALTH_CHECK_TIMEOUT") {
            $Prefs = $Prefs + (Validate-IntOption $Pref.Key, $Pref.Value | New-ReplicaOption -Name $Pref.Key)
        } else {
            throw "Unexpected peferences option: '$($Pref.Key)'"
        }
    }

    $ReplicaDefinitionsArray = @()
    for ($i = 0; $i -lt $ReplicaDefs.Length; $i++) {
        $RDef = $ReplicaDefs[$i]
        if ($RDef.GetType().Name -ne "Hashtable") {
            throw "All elements of ReplicaDefs array should be Hashtables"
        }

        $ReplicaOpts = @()

        # Mandatory options
        $ReplicaName = Validate-DefinedOption "SERVER_INSTANCE" $RDef["SERVER_INSTANCE"]
        $ReplicaOpts = $ReplicaOpts + (Validate-DefinedOption "ENDPOINT_URL" $RDef["ENDPOINT_URL"] | ConvertTo-SQLString | New-ReplicaOption -Name "ENDPOINT_URL")
        $ReplicaOpts = $ReplicaOpts + (Validate-Option "AVAILABILITY_MODE" $RDef["AVAILABILITY_MODE"] @("SYNCHRONOUS_COMMIT", "ASYNCHRONOUS_COMMIT") | New-ReplicaOption -Name "AVAILABILITY_MODE")
        $ReplicaOpts = $ReplicaOpts + (Validate-Option "FAILOVER_MODE" $RDef["FAILOVER_MODE"] @("AUTOMATIC", "MANUAL") | New-ReplicaOption -Name "FAILOVER_MODE")

        # Optional options
        if ($RDef["BACKUP_PRIORITY"] -ne $null) {
            $ReplicaOpts = $ReplicaOpts + (Validate-IntOption "BACKUP_PRIORITY" $RDef["BACKUP_PRIORITY"] | New-ReplicaOption -Name "BACKUP_PRIORITY")
        }
        if ($RDef["SESSION_TIMEOUT"] -ne $null) {
            $ReplicaOpts = $ReplicaOpts + (Validate-IntOption "SESSION_TIMEOUT" $RDef["SESSION_TIMEOUT"] | New-ReplicaOption -Name "SESSION_TIMEOUT")
        }

        $SecondaryRole = @()
        if ($RDef["S_ALLOW_CONNECTIONS"] -ne $null) {
            $SecondaryRole = $SecondaryRole + (Validate-Option "S_ALLOW_CONNECTIONS" $RDef["S_ALLOW_CONNECTIONS"] @("NO", "READ_ONLY", "ALL") | New-ReplicaOption -Name "ALLOW_CONNECTIONS")
        }
        if ($RDef["S_READ_ONLY_ROUTING_URL"] -ne $null) {
            $SecondaryRole = $SecondaryRole + ($RDef["S_READ_ONLY_ROUTING_URL"] | ConvertTo-SQLString | New-ReplicaOption -Name "ALLOW_CONNECTIONS")
        }
        if ($SecondaryRole.Length -gt 0) {
            $ReplicaOpts = $ReplicaOpts + ("( $($SecondaryRole -join ', ') )" | New-ReplicaOption -Name "SECONDARY_ROLE")
        }

        $PrimaryRole = @()
        if ($RDef["P_ALLOW_CONNECTIONS"] -ne $null) {
            $PrimaryRole = $PrimaryRole + (Validate-Option "P_ALLOW_CONNECTIONS" $RDef["P_ALLOW_CONNECTIONS"] @("READ_WRITE", "ALL") | New-ReplicaOption -Name "ALLOW_CONNECTIONS")
        }
        if ($RDef["P_READ_ONLY_ROUTING_LIST"] -ne $null) {
            $PrimaryRole = $PrimaryRole + ((($RDef["P_READ_ONLY_ROUTING_LIST"] | ForEach-Object { ConvertTo-SQLString $_ }) -join ', ') | New-ReplicaOption -Name "ALLOW_CONNECTIONS")
        }
        if ($PrimaryRole.Length -gt 0) {
            $ReplicaOpts = $ReplicaOpts + ("( $($PrimaryRole -join ', ') )" | New-ReplicaOption -Name "PRIMARY_ROLE")
        }

        $ReplicaDefinitionsArray = $ReplicaDefinitionsArray +
            #  TCP://bravo.murano.local:5022
            "N$(ConvertTo-SQLString $ReplicaName) WITH ($($ReplicaOpts -join ', '))"
    }
    $ReplicaDefinitions = $ReplicaDefinitionsArray -join ",`r`n        ";

    if ($ListenerDef["DHCP"] -ne $null) {
        if ($ListenerDef["DHCP"].matches("\d+\d+\d+\d+/\d+\d+\d+\d+")) {
            ($IpAddr, $Mask) = $ListenerDef["DHCP"] -split "/"
            $ListenerAddr = "DHCP ON ( $IpAddr, $Mask )"
        } else {
            $ListenerAddr = "DHCP"
        }
    } else {
        [array]$IPAddresses = $ListenerDef["STATIC"]
        if (($IPAddresses -eq $null) -or ($IPAddresses.Count -eq 0)) {
            $ListenerAddr = "DHCP"
        } else {
            $ConvertedOpts = @()
            foreach ($IpOption in $IPAddresses) {
                # IPv4
                if ($IpOption -match "\d+\d+\d+\d+/\d+\d+\d+\d+") {
                    ($IpAddr, $Mask) = $IpOption -split "/"
                    $ConvertedOpts = $ConvertedOpts + "( $(ConvertTo-SQLString $IpAddr), $(ConvertTo-SQLString $Mask) )"
                    continue
                }
                # IPv6
                if ($IpOption -match "^(((?=(?>.*?::)(?!.*::)))(::)?([0-9A-F]{1,4}::?){0,5}|([0-9A-F]{1,4}:){6})(\2([0-9A-F]{1,4}(::?|$)){0,2}|((25[0-5]|(2[0-4]|1\d|[1-9])?\d)(\.|$)){4}|[0-9A-F]{1,4}:[0-9A-F]{1,4})(?<![^:]:|\.)\z") {
                    $ConvertedOpts = $ConvertedOpts + "( $(ConvertTo-SQLString $IpOption) )"
                    continue
                }
                throw "Malformed IPv4/IPv6 address: $IpOption"
            }
            $ListenerAddr = "IP ( $($ConvertedOpts -join ', ') )"
        }
    }
    if (($ListenerDef["NAME"] -eq $null) -or ($ListenerDef["NAME"] -match "^\s*$")) {
        throw "Listener name is required"
    }
    if (-not ($ListenerDef["NAME"] -match "^[A-Za-z0-9\._\-]+$")) {
        throw "Illegal listener name. It can contain only alphanumeric characters, dashes (-), and hyphens (_), in any order."
    }
    $Port = $null
    if ($ListenerDef["PORT"] -ne $null) {
        if ($ListenerDef["PORT"] -match "\d+\+") {
            $StartingPort = $ListenerDef["PORT"] -replace "\+", ""
            $Port = Get-NextFreePort $StartingPort
            $ListenerAddr = $ListenerAddr + ", PORT = $Port"
        } else {
            if ($ListenerDef["PORT"] -match "\d+") {
                $ListenerAddr = $ListenerAddr + ", PORT = $($ListenerDef["PORT"])"
            } else {
                throw "Invalid port value: $($ListenerDef["PORT"])"
            }
        }
    }
    $Listener = "LISTENER '$($ListenerDef["NAME"])' ( WITH $ListenerAddr )"

    $Name | Out-File "$WorkDir\avgroup.name"
    
    for ($i = 0; $i -lt $DatabaseNames.Length; $i++) {
        $DataBaseName = $DatabaseNames[$i]
        $DataBaseName | Out-File "$WorkDir\db$i.name"
        New-SQLDatabase $DataBaseName
        $BackupDb = "BACKUP DATABASE $(ConvertTo-SQLName $DataBaseName) TO DISK = N$(ConvertTo-SQLString "$WorkDir\db$i.bak") WITH NOFORMAT, INIT, NAME = N'Full Database Backup', SKIP, NOREWIND, NOUNLOAD, STATS = 10
                     GO"
        [void](Invoke-SQLText -SQL $BackupDb)
        $BackupLog = "BACKUP LOG $(ConvertTo-SQLName $DataBaseName) TO DISK = N$(ConvertTo-SQLString "$WorkDir\db${i}.log.bak") WITH NOFORMAT, INIT,  NAME = N'Transaction Log  Backup', SKIP, NOREWIND, NOUNLOAD, STATS = 10
                      GO"
        [void](Invoke-SQLText -SQL $BackupLog)
    }
    $ReplicaDefinitionsArray = @()
    if ($Prefs.Length -gt 0) {
        $PrefsLine = "WITH ( $($Prefs -join ', ') )"
    } else {
        $PrefsLine = ""
    }
    $SQL = "CREATE AVAILABILITY GROUP $(ConvertTo-SQLName $Name) $PrefsLine
                FOR DATABASE $QuotedDBNames
                REPLICA ON`r`n        $ReplicaDefinitions
                $Listener;
    "
    [void](Invoke-SQLText -SQL $SQL)
    return $Port
}

function New-AlwaysOnAvailabilityGroupReplica {
    <#
    .SYNOPSIS
    Creates AlwaysOn availability group secondary replica

    .DESCRIPTION
    Creates AlwaysOn availability group secondary replica based on information provided to and by New-AlwaysOnAvailabilityGroup.

    .PARAMETER WorkDir
    Working directory which was transferred from the primary replica.
    #>
    param(
        [parameter(Mandatory = $true)]
        [String]$WorkDir
    )
    if (-not (Test-Path $WorkDir)) {
        throw "Work dir '$WorkDir' not found"
    }
    $WorkDirObj = Get-Item -Path $WorkDir
    $WorkDir = $WorkDirObj.FullName
    $GroupName = Get-Content $WorkDirObj.GetFiles("avgroup.name").FullName

    $JoinGroup = "ALTER AVAILABILITY GROUP $(ConvertTo-SQLName $GroupName) JOIN
                   GO"
    [void](Invoke-SQLText -SQL $JoinGroup)

    for ($i = 0; ; $i++) {
        $File = $WorkDirObj.GetFiles("db$i.name")
        if (-not $File) {
            break;
        }
        $DataBaseName = Get-Content $WorkDirObj.GetFiles("db$i.name").FullName
        $RestoreDb = "RESTORE DATABASE $(ConvertTo-SQLName $DataBaseName) FROM DISK = N$(ConvertTo-SQLString "$WorkDir\db$i.bak") WITH FILE = 1, NORECOVERY, NOUNLOAD, REPLACE, STATS = 5
                    GO"
        [void](Invoke-SQLText -SQL $RestoreDb)
        $RestoreLog = "RESTORE LOG $(ConvertTo-SQLName $DataBaseName) FROM DISK = N$(ConvertTo-SQLString "$WorkDir\db$i.log.bak") WITH FILE = 1, NORECOVERY, NOUNLOAD, STATS = 10
                    GO"
        [void](Invoke-SQLText -SQL $RestoreLog)
        $AlterDB = "ALTER DATABASE $(ConvertTo-SQLName $DataBaseName) SET HADR AVAILABILITY GROUP = $(ConvertTo-SQLName $GroupName)
                    GO"
        [void](Invoke-SQLText -SQL $AlterDB)
    }
}

function New-ReplicaOption {
    param(
        [parameter(Mandatory = $true)]
        [String]$Name,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String]$Value
    )
    return "$Name = $Value"
}

function Validate-Option {
    <#
    .SYNOPSIS
    Checks that the value is one of allowed values

    .DESCRIPTION
    Checks that the value is one of allowed values or throws exception otherwise. Returns provided value.

    .PARAMETER Name
    Option name. Used only for error message.

    .PARAMETER Value
    Option value.

    .PARAMETER Allowed
    List of allowed option valus.
    #>
    param(
        [parameter(Mandatory = $true)]
        [String]$Name,
        [String]$Value,
        [Array]$Allowed
    )
    if (($Value -eq $null) -or ($Value -eq "")) {
        throw "No value was provided for $Name"
    }
    foreach ($V in $Allowed) {
        if ($V -eq $Value) {
            return $Value
        }
    }
    throw "Provided value '$Value' for $Name is not one of $($Allowed -join ', ')"
}

function Validate-IntOption {
    <#
    .SYNOPSIS
    Checks that the value is integer

    .DESCRIPTION
    Checks that the value is integer. Returns provided value.

    .PARAMETER Name
    Option name. Used only for error message.

    .PARAMETER Value
    Option value.
    #>
    param(
        [parameter(Mandatory = $true)]
        [String]$Name,
        [parameter]
        [String]$Value
    )
    if (($Value -eq $null) -or ($Value -eq "")) {
        throw "No value was provided for $Name"
    }
    if (-not ("$Value" -match "^[+-]?\d+$")) {
        throw "Provided value '$Value' for $Name is not a number"
    }
    return $Value
}

function Validate-DefinedOption {
    <#
    .SYNOPSIS
    Checks that the value is not null

    .DESCRIPTION
    Checks that the value is not null. Returns provided value.

    .PARAMETER Name
    Option name. Used only for error message.

    .PARAMETER Value
    Option value.
    #>
    param(
        [parameter(Mandatory = $true)]
        [String]$Name,
        [parameter(Mandatory = $false)]
        [String]$Value
    )
    if (($Value -eq $null) -or ($Value -eq "")) {
        throw "No value was provided for $Name"
    }
    return $Value
}


#Export-ModuleMember -Function New-SQLServer
#Export-ModuleMember -Function New-SQLServerForAOAG
#Export-ModuleMember -Function Remove-SQLServer
#Export-ModuleMember -Function Invoke-SQLText
#Export-ModuleMember -Function Initialize-MirroringEndpoint
#Export-ModuleMember -Function Initialize-SQLMirroringPrincipalStep1
#Export-ModuleMember -Function Initialize-SQLMirroringMirrorStep1
#Export-ModuleMember -Function Initialize-SQLMirroringPrincipalStep2
#Export-ModuleMember -Function Initialize-SQLMirroringMirrorStep2
#Export-ModuleMember -Function Initialize-SQLMirroringPrincipalStep3
#Export-ModuleMember -Function Initialize-SQLMirroringMirrorStep3
#Export-ModuleMember -Function Install-SQLServerForSysPrep
#Export-ModuleMember -Function Complete-SQLServerAfterSysPrep
#Export-ModuleMember -Function Initialize-AlwaysOn
#Export-ModuleMember -Function New-AlwaysOnAvailabilityGroup
#Export-ModuleMember -Function New-AlwaysOnAvailabilityGroupReplica
