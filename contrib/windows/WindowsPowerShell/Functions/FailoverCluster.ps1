function Init-Clustering {
    <#
    .SYNOPSIS
    Installs all the prerequisites for windows failover cluster.

    .DESCRIPTION
    Checks that computer is a part of Windows Domain.
    Installs Failover Clustering windows feature with management tools if needed.
    Restart may be required to continue installation, so check this cmdlet exit code.
    If exit code is $true, a restart is required. System should be restarted and
    CmdLet should be re-executed to perform all the configuration tasks left.

    Is is safe to execute this CmdLet multiple times. It checks which components
    are missing / unconfigured and performs only necessary steps.

    #>
    $ComputerSystem = Get-WmiObject Win32_ComputerSystem
    if (-not $ComputerSystem.PartOfDomain) {
        throw "The computer should be joined to domain first"
    }
    Import-Module ServerManager
    $Feature = Get-WindowsFeature Failover-Clustering
    if ($Feature -eq $null) {
        throw "Failover-Clustering not found" # Should not happen on Win Server 2012
    }
    if (-not $Feature.Installed) {
        Write-Host "Failover Clustering feature is not installed. Installing it using Server Manager..."
        $FeatureOpResult = Add-WindowsFeature $Feature -IncludeManagementTools
        if (-not $FeatureOpResult.Success) {
            throw "Failed to install Failover-Clustering: " + $FeatureOpResult.ExitCode.toString()
        }
        if ($FeatureOpResult.RestartNeeded) {
            Write-Host "Restart is required to continue..."
            return $true
        }
    }
    $Feature = Get-WindowsFeature RSAT-Clustering
    if ($Feature -eq $null) {
        throw "Failover Clustering Tools feature not found" # Should not happen on Win Server 2012
    }
    if (-not $Feature.Installed) {
        Write-Host "Failover Clustering Tools feature is not installed. Installing it using Server Manager..."
        $FeatureOpResult = Add-WindowsFeature $Feature
        if (-not $FeatureOpResult.Success) {
            throw "Failed to install RSAT-Clustering: " + $FeatureOpResult.ExitCode.toString()
        }
        if ($FeatureOpResult.RestartNeeded) {
            Write-Host "Restart is required to continue..."
            return $true
        }
    }
    $Feature = Get-WindowsFeature RSAT-Clustering-Mgmt
    if ($Feature -eq $null) {
        throw "Failover Cluster Management Tools feature not found" # Should not happen on Win Server 2012
    }
    if (-not $Feature.Installed) {
        Write-Host "Failover Cluster Management Tools feature is not installed. Installing it using Server Manager..."
        $FeatureOpResult = Add-WindowsFeature $Feature
        if (-not $FeatureOpResult.Success) {
            throw "Failed to install RSAT-Clustering-Mgmt: " + $FeatureOpResult.ExitCode.toString()
        }
        if ($FeatureOpResult.RestartNeeded) {
            Write-Host "Restart is required to continue..."
            return $true
        }
    }
    $Feature = Get-WindowsFeature RSAT-Clustering-PowerShell
    if ($Feature -eq $null) {
        throw "Failover Cluster Module for Windows PowerShell feature not found" # Should not happen on Win Server 2012
    }
    if (-not $Feature.Installed) {
        Write-Host "Failover Cluster Module for Windows PowerShell feature is not installed. Installing it using Server Manager..."
        $FeatureOpResult = Add-WindowsFeature $Feature
        if (-not $FeatureOpResult.Success) {
            throw "Failed to install RSAT-Clustering-PowerShell: " + $FeatureOpResult.ExitCode.toString()
        }
        if ($FeatureOpResult.RestartNeeded) {
            Write-Host "Restart is required to continue..."
            return $true
        }
    }
}

function New-WindowsFailoverCluster {
    <#
    .SYNOPSIS
    Creates a Windows Failover Cluster.

    .DESCRIPTION
    Installs all the prerequisites and creates a new Windows Failover Cluster. Init-Clustering is executed
    by this cmdlet to ensure that all the required server components are installed. A reboot mey be
    required to complete installation. In case if this CmdLet returns $true, reboot the system and
    re-invoke the CmdLet with the same arguments to continue installation.

    .PARAMETER ClusterName
    Failover Cluster Name. The installation will fail if a cluster or other object with the same name
    already exists in the domain.

    .PARAMETER Nodes
    List of computers (fully qualified domain names are recommmeneded) to participate in the cluster.
    Current user should have all the required permissions to join all the machones to the cluster.
    #>
    param(
        [parameter(Mandatory = $true)]
        [string]$ClusterName,
        [parameter(Mandatory = $true)]
        [array]$Nodes
    )

    if (Init-Clustering) {
        return $true
    }
    Import-Module FailoverClusters
    [void](Test-Cluster -Cluster $ClusterName -Node $Nodes)
    [void](New-Cluster -Name $ClusterName -Node @("bravo.murano.local", "charlie.murano.local") -NoStorage)
    return $false
}
