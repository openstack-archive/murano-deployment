function New-OptionParserInstall {
    <#
    .SYNOPSIS
    Creates an option parser for MS SQL Server 2012 setup "INSTALL" action.

    .DESCRIPTION
    Use this cmdlet to create an option parser for MS SQL Server 2012 setup "INSTALL" action.
    All documented option are supported. See the following link for details:
    http://msdn.microsoft.com/en-us/library/ms144259.aspx
    #>
    $OptionParser = New-OptionParser

    $IsPartOfDomain = (Get-WmiObject Win32_ComputerSystem).PartOfDomain

    $OptionParser.AddOption((New-Option "ACTION" -String -Constraints "INSTALL"), $true, "INSTALL")
    $OptionParser.AddOption((New-Option "IACCEPTSQLSERVERLICENSETERMS" -Switch), $true)
    $OptionParser.AddOption((New-Option "ENU" -Switch))
    #$OptionParser.AddOption((New-Option "UpdateEnabled" -Switch))
    $OptionParser.AddOption((New-Option "UpdateEnabled" -Boolean))
    $OptionParser.AddOption((New-Option "UpdateSource" -String))
    $OptionParser.AddOption((New-Option "CONFIGURATIONFILE" -String))
    $OptionParser.AddOption((New-Option "ERRORREPORTING" -Boolean))
    $OptionParser.AddOption((New-Option "FEATURES" -List -Constraints ("SQL","SQLEngine","Replication","FullText","DQ","AS","RS","DQC","IS","MDS","Tools","BC","BOL","BIDS","Conn","SSMS","ADV_SSMS","DREPLAY_CTLR","DREPLAY_CLT","SNAC_SDK","SDK","LocalDB")))
    $OptionParser.AddOption((New-Option "ROLE" -String -Constraints ("SPI_AS_ExistingFarm", "SPI_AS_NewFarm", "AllFeatures_WithDefaults")))
    $OptionParser.AddOption((New-Option "INDICATEPROGRESS" -Switch))
    $OptionParser.AddOption((New-Option "INSTALLSHAREDDIR" -String))
    $OptionParser.AddOption((New-Option "INSTALLSHAREDWOWDIR" -String))
    $OptionParser.AddOption((New-Option "INSTANCEDIR" -String))
    $OptionParser.AddOption((New-Option "INSTANCEID" -String))
    $OptionParser.AddOption((New-Option "INSTANCENAME" -String), $true, "MSSQLSERVER")
    $OptionParser.AddOption((New-Option "PID" -String))
    $OptionParser.AddOption((New-Option "Q" -Switch))
    $OptionParser.AddOption((New-Option "QS" -Switch))
    $OptionParser.AddOption((New-Option "UIMODE" -String -Constraints ("Normal", "AutoAdvance")))
    $OptionParser.AddOption((New-Option "SQMREPORTING" -Boolean))
    $OptionParser.AddOption((New-Option "HIDECONSOLE" -Switch))
    $OptionParser.AddOption((New-Option "AGTSVCACCOUNT" -String), $true, "NT AUTHORITY\Network Service")
    $OptionParser.AddOption((New-Option "AGTSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "AGTSVCSTARTUPTYPE" -String -Constraints ("Manual", "Automatic", "Disabled")))
    $OptionParser.AddOption((New-Option "ASBACKUPDIR" -String))
    $OptionParser.AddOption((New-Option "ASCOLLATION" -String))
    $OptionParser.AddOption((New-Option "ASCONFIGDIR" -String))
    $OptionParser.AddOption((New-Option "ASDATADIR" -String))
    $OptionParser.AddOption((New-Option "ASLOGDIR" -String))
    $OptionParser.AddOption((New-Option "ASSERVERMODE" -String -Constraints ("MULTIDIMENSIONAL", "POWERPIVOT", "TABULAR")))
    $OptionParser.AddOption((New-Option "ASSVCACCOUNT" -String), $true, "NT AUTHORITY\Network Service")
    $OptionParser.AddOption((New-Option "ASSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "ASSVCSTARTUPTYPE" -String -Constraints ("Manual", "Automatic", "Disabled")))

    #$OptionParser.AddOption((New-Option "ASSYSADMINACCOUNTS" -String), $true, "$ENV:USERDOMAIN\$ENV:USERNAME")
    if ($IsPartOfDomain) {
        $OptionParser.AddOption((New-Option "ASSYSADMINACCOUNTS" -String), $true, "$Env:USERDOMAIN\Administrator")
    }
    else {
        $OptionParser.AddOption((New-Option "ASSYSADMINACCOUNTS" -String), $true, "$Env:COMPUTERNAME\Administrator")
    }

    $OptionParser.AddOption((New-Option "ASTEMPDIR" -String))
    $OptionParser.AddOption((New-Option "ASPROVIDERMSOLAP" -Boolean))
    $OptionParser.AddOption((New-Option "FARMACCOUNT" -String))
    $OptionParser.AddOption((New-Option "FARMPASSWORD" -String))
    $OptionParser.AddOption((New-Option "PASSPHRASE" -String))
    $OptionParser.AddOption((New-Option "FARMADMINIPORT" -String))
    $OptionParser.AddOption((New-Option "BROWSERSVCSTARTUPTYPE" -String -Constraints ("Manual", "Automatic", "Disabled")))
    $OptionParser.AddOption((New-Option "ENABLERANU" -Switch))
    $OptionParser.AddOption((New-Option "INSTALLSQLDATADIR" -String))
    $OptionParser.AddOption((New-Option "SAPWD" -String))
    $OptionParser.AddOption((New-Option "SECURITYMODE" -String -Constrainrs ("SQL")))
    $OptionParser.AddOption((New-Option "SQLBACKUPDIR" -String))
    $OptionParser.AddOption((New-Option "SQLCOLLATION" -String))
    $OptionParser.AddOption((New-Option "ADDCURRENTUSERASSQLADMIN" -Switch))
    $OptionParser.AddOption((New-Option "SQLSVCACCOUNT" -String), $true, "NT AUTHORITY\Network Service")
    $OptionParser.AddOption((New-Option "SQLSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "SQLSVCSTARTUPTYPE" -String -Constraints ("Manual", "Automatic", "Disabled")))
    
    #$OptionParser.AddOption((New-Option "SQLSYSADMINACCOUNTS" -String), $true, "$ENV:USERDOMAIN\$ENV:USERNAME")
    if ($IsPartOfDomain) {
        $OptionParser.AddOption((New-Option "SQLSYSADMINACCOUNTS" -String), $true, "$ENV:USERDOMAIN\Administrator")
    }
    else {
        $OptionParser.AddOption((New-Option "SQLSYSADMINACCOUNTS" -String), $true, "$ENV:COMPUTERNAME\Administrator")
    }
    
    $OptionParser.AddOption((New-Option "SQLTEMPDBDIR" -String))
    $OptionParser.AddOption((New-Option "SQLTEMPDBLOGDIR" -String))
    $OptionParser.AddOption((New-Option "SQLUSERDBDIR" -String))
    $OptionParser.AddOption((New-Option "SQLUSERDBLOGDIR" -String))
    $OptionParser.AddOption((New-Option "FILESTREAMLEVEL" -String -Constraints ("0", "1", "2", "3")))
    $OptionParser.AddOption((New-Option "FILESTREAMSHARENAME" -String))
    $OptionParser.AddOption((New-Option "FTSVCACCOUNT" -String))
    $OptionParser.AddOption((New-Option "FTSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "ISSVCACCOUNT" -String), $true, "NT AUTHORITY\Network Service")
    $OptionParser.AddOption((New-Option "ISSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "ISSVCStartupType" -String -Constraints ("Manual", "Automatic", "Disabled")))
    $OptionParser.AddOption((New-Option "NPENABLED" -Boolean))
    $OptionParser.AddOption((New-Option "TCPENABLED" -Boolean))
    $OptionParser.AddOption((New-Option "RSINSTALLMODE" -String -Constraints ("SharePointFilesOnlyMode", "DefaultNativeMode", "FilesOnlyMode")))
    $OptionParser.AddOption((New-Option "RSSVCACCOUNT" -String), $true, "NT AUTHORITY\Network Service")
    $OptionParser.AddOption((New-Option "RSSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "RSSVCStartupType" -String -Constraints ("Manual", "Automatic", "Disabled")))

    return $OptionParser
}

function New-OptionParserPrepareImage {
    <#
    .SYNOPSIS
    Creates an option parser for MS SQL Server 2012 setup "PrepareImage" action.

    .DESCRIPTION
    Use this cmdlet to create an option parser for MS SQL Server 2012 setup "PrepareImage" action.

    Note that for installer version of MS SQL Server prior to 2012 SP1 Cumulative Update 2 only the
    following features are supported: SQLEngine, Replication, FullText, RS

    All documented option are supported. See the following link for details:
    http://msdn.microsoft.com/en-us/library/ms144259.aspx
    #>
    $OptionParser = New-OptionParser

    $OptionParser.AddOption((New-Option "ACTION" -String -Constraints "PrepareImage"), $true, "PrepareImage")
    $OptionParser.AddOption((New-Option "IACCEPTSQLSERVERLICENSETERMS" -Switch), $true)
    $OptionParser.AddOption((New-Option "ENU" -Switch))
    $OptionParser.AddOption((New-Option "UpdateEnabled" -Switch))
    $OptionParser.AddOption((New-Option "UpdateSource" -String))
    $OptionParser.AddOption((New-Option "CONFIGURATIONFILE" -String))
#    $OptionParser.AddOption((New-Option "FEATURES" -List -Constraints ("SQLEngine","Replication","FullText","RS")))
    $OptionParser.AddOption((New-Option "FEATURES" -List -Constraints ("SQL","SQLEngine","Replication","FullText","DQ","AS","RS","DQC","IS","MDS","Tools","BC","BOL","BIDS","Conn","SSMS","ADV_SSMS","DREPLAY_CTLR","DREPLAY_CLT","SNAC_SDK","SDK","LocalDB")))
    $OptionParser.AddOption((New-Option "HIDECONSOLE" -Switch))
    $OptionParser.AddOption((New-Option "INDICATEPROGRESS" -Switch))
    $OptionParser.AddOption((New-Option "INSTALLSHAREDDIR" -String))
    $OptionParser.AddOption((New-Option "INSTANCEDIR" -String))
    $OptionParser.AddOption((New-Option "INSTANCEID" -String), $true, "MSSQLSERVER")
    $OptionParser.AddOption((New-Option "Q" -Switch))
    $OptionParser.AddOption((New-Option "QS" -Switch))

    return $OptionParser
}

function New-OptionParserPrepareImageSP1U2 {
    <#
    .SYNOPSIS
    Creates an option parser for MS SQL Server 2012 setup "PrepareImage" action.

    .DESCRIPTION
    Use this cmdlet to create an option parser for MS SQL Server 2012 setup "PrepareImage" action.

    This cmdlet should be used only for MS SQL Server 2012 SP1 Cimilative Update 2 or later.

    Note that for installer version of MS SQL Server prior to 2012 SP1 Cimilative Update 2 only the
    following features are supported: SQLEngine, Replication, FullText, RS

    All documented option are supported. See the following link for details:
    http://msdn.microsoft.com/en-us/library/ms144259.aspx
    #>
    $OptionParser = New-OptionParser

    $OptionParser.AddOption((New-Option "ACTION" -String -Constraints "PrepareImage"), $true, "PrepareImage")
    $OptionParser.AddOption((New-Option "IACCEPTSQLSERVERLICENSETERMS" -Switch), $true)
    $OptionParser.AddOption((New-Option "ENU" -Switch))
    $OptionParser.AddOption((New-Option "UpdateEnabled" -Switch))
    $OptionParser.AddOption((New-Option "UpdateSource" -String))
    $OptionParser.AddOption((New-Option "CONFIGURATIONFILE" -String))
    $OptionParser.AddOption((New-Option "FEATURES" -List -Constraints ("SQL","SQLEngine","Replication","FullText","DQ","AS","RS","DQC","IS","MDS","Tools","BC","BOL","BIDS","Conn","SSMS","ADV_SSMS","SNAC_SDK","SDK","LocalDB")))
    $OptionParser.AddOption((New-Option "HIDECONSOLE" -Switch))
    $OptionParser.AddOption((New-Option "INDICATEPROGRESS" -Switch))
    $OptionParser.AddOption((New-Option "INSTALLSHAREDDIR" -String))
    $OptionParser.AddOption((New-Option "INSTANCEDIR" -String))
    $OptionParser.AddOption((New-Option "INSTANCEID" -String), $true, "MSSQLSERVER")
    $OptionParser.AddOption((New-Option "Q" -Switch))
    $OptionParser.AddOption((New-Option "QS" -Switch))

    return $OptionParser
}

function New-OptionParserCompleteImage {
    <#
    .SYNOPSIS
    Creates an option parser for MS SQL Server 2012 setup "CompleteImage" action.

    .DESCRIPTION
    Use this cmdlet to create an option parser for MS SQL Server 2012 setup "CompleteImage" action.

    Note that INSTANCEID parameter value MUST be the same as specified on "PrepareImage" phase.

    All documented option are supported. See the following link for details:
    http://msdn.microsoft.com/en-us/library/ms144259.aspx
    #>
    $OptionParser = New-OptionParser

    $OptionParser.AddOption((New-Option "ACTION" -String -Constraints "CompleteImage"), $true, "CompleteImage")
    $OptionParser.AddOption((New-Option "IACCEPTSQLSERVERLICENSETERMS" -Switch), $true)
    $OptionParser.AddOption((New-Option "ENU" -Switch))
    $OptionParser.AddOption((New-Option "CONFIGURATIONFILE" -String))
    $OptionParser.AddOption((New-Option "ERRORREPORTING" -Boolean))
    $OptionParser.AddOption((New-Option "INDICATEPROGRESS" -Switch))
    $OptionParser.AddOption((New-Option "INSTANCEID" -String), $true, "MSSQLSERVER")
    $OptionParser.AddOption((New-Option "INSTANCENAME" -String), $true, "MSSQLSERVER")
    $OptionParser.AddOption((New-Option "PID" -String))
    $OptionParser.AddOption((New-Option "Q" -Switch))
    $OptionParser.AddOption((New-Option "QS" -Switch))
    $OptionParser.AddOption((New-Option "SQMREPORTING" -Boolean))
    $OptionParser.AddOption((New-Option "HIDECONSOLE" -Switch))
    $OptionParser.AddOption((New-Option "AGTSVCACCOUNT" -String), $true, "NT AUTHORITY\Network Service")
    $OptionParser.AddOption((New-Option "AGTSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "AGTSVCSTARTUPTYPE" -String -Constraints ("Manual", "Automatic", "Disabled")))
    $OptionParser.AddOption((New-Option "BROWSERSVCSTARTUPTYPE" -String -Constraints ("Manual", "Automatic", "Disabled")))
    $OptionParser.AddOption((New-Option "ENABLERANU" -Switch))
    $OptionParser.AddOption((New-Option "INSTALLSQLDATADIR" -String))
    $OptionParser.AddOption((New-Option "SAPWD" -String))
    $OptionParser.AddOption((New-Option "SECURITYMODE" -String -Constrainrs ("SQL")))
    $OptionParser.AddOption((New-Option "SQLBACKUPDIR" -String))
    $OptionParser.AddOption((New-Option "SQLCOLLATION" -String))
    $OptionParser.AddOption((New-Option "SQLSVCACCOUNT" -String), $true, "NT AUTHORITY\Network Service")
    $OptionParser.AddOption((New-Option "SQLSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "SQLSVCSTARTUPTYPE" -String -Constraints ("Manual", "Automatic", "Disabled")))
    $OptionParser.AddOption((New-Option "SQLSYSADMINACCOUNTS" -String), $true, "$ENV:USERDOMAIN\$ENV:USERNAME")
    $OptionParser.AddOption((New-Option "SQLTEMPDBDIR" -String))
    $OptionParser.AddOption((New-Option "SQLTEMPDBLOGDIR" -String))
    $OptionParser.AddOption((New-Option "SQLUSERDBDIR" -String))
    $OptionParser.AddOption((New-Option "SQLUSERDBLOGDIR" -String))
    $OptionParser.AddOption((New-Option "FILESTREAMLEVEL" -String -Constraints ("0", "1", "2", "3")))
    $OptionParser.AddOption((New-Option "FILESTREAMSHARENAME" -String))
    $OptionParser.AddOption((New-Option "FTSVCACCOUNT" -String))
    $OptionParser.AddOption((New-Option "FTSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "NPENABLED" -Boolean))
    $OptionParser.AddOption((New-Option "TCPENABLED" -Boolean))
    $OptionParser.AddOption((New-Option "RSINSTALLMODE" -String -Constraints ("SharePointFilesOnlyMode", "DefaultNativeMode", "FilesOnlyMode")))
    $OptionParser.AddOption((New-Option "RSSVCACCOUNT" -String), $true, "NT AUTHORITY\Network Service")
    $OptionParser.AddOption((New-Option "RSSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "RSSVCStartupType" -String -Constraints ("Manual", "Automatic", "Disabled")))

    return $OptionParser
}

function New-OptionParserCompleteImageSP1U2 {
    <#
    .SYNOPSIS
    Creates an option parser for MS SQL Server 2012 setup "CompleteImage" action.

    .DESCRIPTION
    Use this cmdlet to create an option parser for MS SQL Server 2012 setup "CompleteImage" action.

    This cmdlet should be used only for MS SQL Server 2012 SP1 Cimilative Update 2 or later.

    All documented option are supported. See the following link for details:
    http://msdn.microsoft.com/en-us/library/ms144259.aspx
    #>
    $OptionParser = New-OptionParser

    $OptionParser.AddOption((New-Option "ACTION" -String -Constraints "CompleteImage"), $true, "CompleteImage")
    $OptionParser.AddOption((New-Option "IACCEPTSQLSERVERLICENSETERMS" -Switch), $true)
    $OptionParser.AddOption((New-Option "ENU" -Switch))
    $OptionParser.AddOption((New-Option "CONFIGURATIONFILE" -String))
    $OptionParser.AddOption((New-Option "ERRORREPORTING" -Boolean))
    $OptionParser.AddOption((New-Option "INDICATEPROGRESS" -Switch))
    $OptionParser.AddOption((New-Option "INSTANCEID" -String))
    $OptionParser.AddOption((New-Option "INSTANCENAME" -String))
    $OptionParser.AddOption((New-Option "PID" -String))
    $OptionParser.AddOption((New-Option "Q" -Switch))
    $OptionParser.AddOption((New-Option "QS" -Switch))
    $OptionParser.AddOption((New-Option "SQMREPORTING" -Boolean))
    $OptionParser.AddOption((New-Option "HIDECONSOLE" -Switch))
    $OptionParser.AddOption((New-Option "AGTSVCACCOUNT" -String), $true, "NT AUTHORITY\Network Service")
    $OptionParser.AddOption((New-Option "AGTSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "AGTSVCSTARTUPTYPE" -String -Constraints ("Manual", "Automatic", "Disabled")))
    $OptionParser.AddOption((New-Option "BROWSERSVCSTARTUPTYPE" -String -Constraints ("Manual", "Automatic", "Disabled")))
    $OptionParser.AddOption((New-Option "ENABLERANU" -Switch))
    $OptionParser.AddOption((New-Option "INSTALLSQLDATADIR" -String))
    $OptionParser.AddOption((New-Option "SAPWD" -String))
    $OptionParser.AddOption((New-Option "SECURITYMODE" -String -Constrainrs ("SQL")))
    $OptionParser.AddOption((New-Option "SQLBACKUPDIR" -String))
    $OptionParser.AddOption((New-Option "SQLCOLLATION" -String))
    $OptionParser.AddOption((New-Option "SQLSVCACCOUNT" -String), $true, "NT AUTHORITY\Network Service")
    $OptionParser.AddOption((New-Option "SQLSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "SQLSVCSTARTUPTYPE" -String -Constraints ("Manual", "Automatic", "Disabled")))
    $OptionParser.AddOption((New-Option "SQLSYSADMINACCOUNTS" -String), $true, "$ENV:USERDOMAIN\$ENV:USERNAME")
    $OptionParser.AddOption((New-Option "SQLTEMPDBDIR" -String))
    $OptionParser.AddOption((New-Option "SQLTEMPDBLOGDIR" -String))
    $OptionParser.AddOption((New-Option "SQLUSERDBDIR" -String))
    $OptionParser.AddOption((New-Option "SQLUSERDBLOGDIR" -String))
    $OptionParser.AddOption((New-Option "FILESTREAMLEVEL" -String -Constraints ("0", "1", "2", "3")))
    $OptionParser.AddOption((New-Option "FILESTREAMSHARENAME" -String))
    $OptionParser.AddOption((New-Option "FTSVCACCOUNT" -String))
    $OptionParser.AddOption((New-Option "FTSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "NPENABLED" -Boolean))
    $OptionParser.AddOption((New-Option "TCPENABLED" -Boolean))
    $OptionParser.AddOption((New-Option "RSINSTALLMODE" -String -Constraints ("SharePointFilesOnlyMode", "DefaultNativeMode", "FilesOnlyMode")))
    $OptionParser.AddOption((New-Option "RSSVCACCOUNT" -String), $true, "NT AUTHORITY\Network Service")
    $OptionParser.AddOption((New-Option "RSSVCPASSWORD" -String))
    $OptionParser.AddOption((New-Option "RSSVCStartupType" -String -Constraints ("Manual", "Automatic", "Disabled")))

    return $OptionParser
}

function New-OptionParserUpgrade {
    # ToDo: Implement
    throw "Not yet implemented"
}

function New-OptionParserEditionUpgrade {
    # ToDo: Implement
    throw "Not yet implemented"
}

function New-OptionParserRepair {
    # ToDo: Implement
    throw "Not yet implemented"
}

function New-OptionParserRebuilddatabase {
    # ToDo: Implement
    throw "Not yet implemented"
}

function New-OptionParserUninstall {
    <#
    .SYNOPSIS
    Creates an option parser for MS SQL Server 2012 setup "INSTALL" action.

    .DESCRIPTION
    Use this cmdlet to create an option parser for MS SQL Server 2012 setup "INSTALL" action.
    All documented option are supported. See the following link for details:
    http://msdn.microsoft.com/en-us/library/ms144259.aspx
    #>
    $OptionParser = New-OptionParser

    $OptionParser.AddOption((New-Option "ACTION" -String -Constraints "UNINSTALL"), $true, "UNINSTALL")
    $OptionParser.AddOption((New-Option "CONFIGURATIONFILE" -String))
    $OptionParser.AddOption((New-Option "FEATURES" -List -Constraints ("SQL","SQLEngine","Replication","FullText","DQ","AS","RS","DQC","IS","MDS","Tools","BC","BOL","BIDS","Conn","SSMS","ADV_SSMS","DREPLAY_CTLR","DREPLAY_CLT","SNAC_SDK","SDK","LocalDB")), $true)
    $OptionParser.AddOption((New-Option "INDICATEPROGRESS" -Switch))
    $OptionParser.AddOption((New-Option "INSTANCENAME" -String), $true, "MSSQLSERVER")
    $OptionParser.AddOption((New-Option "Q" -Switch))
    $OptionParser.AddOption((New-Option "HIDECONSOLE" -Switch))

    return $OptionParser
}

function New-OptionParserInstallFailoverCluster {
    # ToDo: Implement
    throw "Not yet implemented"
}

function New-OptionParserPrepareFailoverCluster {
    # ToDo: Implement
    throw "Not yet implemented"
}

function New-OptionParserCompleteFailoverCluster {
    # ToDo: Implement
    throw "Not yet implemented"
}

function New-OptionParserUpgrade {
    # ToDo: Implement
    throw "Not yet implemented"
}

function New-OptionParserAddNode {
    # ToDo: Implement
    throw "Not yet implemented"
}

function New-OptionParserRemoveNode {
    # ToDo: Implement
    throw "Not yet implemented"
}
