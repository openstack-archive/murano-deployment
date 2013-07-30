<#
.DESCRIPTION

## Failover Cluster Input Data (from the UI)

* Domain Membership
    - [String] / [Select box] $DomainName - Domain name
* Domain User Credentials
    - [String] $UserName - Username
    - [Password string] $UserPassword - User password
* Shared Folder Information
    - [String] $ShareServer - Server which will host the folder
    - [String] $ShareName - Share name
    - [String] $SharePath - Shared folder internal path
* Failover Cluster Members
    - [String] $ClusterName - Cluster name
    - [String] $ClusterIP - Static IP address that will be assigned to the cluster
    - [String[]] $ClusterNodes - List of node names



## Failover Cluster creation workflow

* Create AD domain
* Join all the VMs to that domain
* Prepare nodes
    - Install Failover Cluster prerequisites on all FC nodes
* Create failover cluster
    - Create new cluster
    - Add members
* Confugure FC quorum
    - Create new folder that will be shared
    - Share that folder with appropriate permissions
    - Configure quorum mode



## Helpful SmbShare* Functions

* New-SmbShare
* Grant-SmbShareAccess

#>



function Start-PowerShellProcess {
	param (
		[String] $Command,
		$Credential = $null
	)
	
	$Bytes = [Text.Encoding]::Unicode.GetBytes($Command)
	$EncodedCommand = [Convert]::ToBase64String($Bytes)

	Write-Log $EncodedCommand

	$StdOut = [IO.Path]::GetTempFileName()
	$StdErr = [IO.Path]::GetTempFileName()
	$ArgumentList = @('-OutputFormat', 'XML', '-EncodedCommand', $EncodedCommand)

	if ($Credential -eq $null) {
		$Process = Start-Process -FilePath 'powershell.exe' `
			-ArgumentList @($ArgumentList) `
			-RedirectStandardOutput $StdOut `
			-RedirectStandardError $StdErr `
			-NoNewWindow `
			-Wait `
            -PassThru
	}
	else {
		$Process = Start-Process -FilePath 'powershell.exe' `
			-ArgumentList @($ArgumentList) `
			-RedirectStandardOutput $StdOut `
			-RedirectStandardError $StdErr `
			-Credential $Credential `
			-NoNewWindow `
			-Wait `
            -PassThru
	}

	if ((Get-Item $StdOut).Length -gt 0) {
		Import-Clixml $StdOut
	}

	if ((Get-Item $StdErr).Length -gt 0) {
		Import-Clixml $StdErr
	}

    if ($Process.ExitCode -ne 0) {
        throw("External PowerShell process exited with code '$($Process.ExitCode)'")
    }

    #Remove-Item $StdOut -Force
    #Remove-Item $StdErr -Force
}



function Install-FailoverClusterPrerequisites {
    Import-Module FailoverClusters

    Add-WindowsFeature Failover-Clustering, RSAT-Clustering-PowerShell
}



function New-FailoverClusterSharedFolder {
	param (
        [String] $ClusterName,
        [String] $DomainName,
        [String] $ShareServer,
		[String] $SharePath,
		[String] $ShareName,
        [String] $UserName,
        [String] $UserPassword
        $Credential = $null
	)
    
    if ($Credential -eq $null) {
        $Credential = New-Credential -UserName "$DomainName\$UserName" -Password "$UserPassword"
    }

    if ((Test-Connection -ComputerName $ShareServer -Count 1 -Quiet) -eq $false) {
        throw("Server '$ShareServer' is unreachable via ICMP.")
    }

    $Session = New-PSSession -ComputerName $ShareServer -Credential $Credential

    Invoke-Command -Session $Session -ScriptBlock {
            param (
                [String] $SharePath,
                [String] $ShareName,
                [String] $ClusterAccount
            )

            New-Item -Path $SharePath -ItemType Container -Force
            
            New-SmbShare -Path $SharePath `
                -Name $ShareName `
                -FullAccess "$ClusterAccount" `
                -Description "Shared folder for Failover Cluster."

        } -ArgumentList $SharePath, $ShareName, "$DomainName\$ClusterName`$"

    Set-ClusterQuorum -NodeAndFileShareMajority "\\$ShareServer\$ShareName"
}



function New-FailoverCluster {
	param (
		[String] $ClusterName,
		[String] $StaticAddress,
		[String[]] $ClusterNodes,
        [String] $UserName,
        [String] $UserPassword
        $Credential
	)

    if ($Credential -eq $null) {
        $Credential = New-Credential -UserName "$DomainName\$UserName" -Password "$UserPassword"
    }

    Import-Module FailoverClusters

	if ((Get-Cluster $ClusterName -ErrorAction SilentlyContinue) -eq $null) {
        Write-Log "Creating new cluster '$ClusterName' ..."
        Start-PowerShellProcess -Command @"
Import-Module FailoverClusters
New-Cluster -Name '$ClusterName' -StaticAddress '$StaticAddress'
"@ -Credential $Credential
        Start-Sleep -Seconds 15
    }
    else {
        Write-Log "Cluster '$ClusterName' already exists."
    }

    foreach ($Node in $ClusterNodes) {
        if ((Get-ClusterNode $Node -ErrorAction SilentlyContinue) -eq $null) {
            Write-Log "Adding node '$Node' to the cluster '$ClusterName' ..."
            Start-PowerShellProcess -Command @"
Import-Module FailoverClusters
Add-ClusterNode -Cluster '$Name' -Name '$Node'
"@ -Credential $Credential
        }
        else {
            Write-Log "Node '$Node' already a part of the cluster '$ClusterName'."
        }
    }
}



<#

# Example

$DomainName = 'fc-acme.local'
$DomainUser = 'Administrator'
$DomainPassword = 'P@ssw0rd'

$ClusterName = 'fc-test'
$ClusterIP = '10.200.0.60'
$ClusterNodes = @('fc-node-01','fc-node-02','fc-node-03')

$ShareServer = 'fc-dc-01'
$ShareName = 'FCShare'

$SharePath = "C:\$ShareName"



Import-Module CoreFunctions -Force

$Creds = New-Credential `
    -UserName "$DomainName\$DomainUser" `
    -Password "$DomainPassword"

New-FailoverCluster `
    -ClusterName $ClusterName `
    -StaticAddress $ClusterIP `
    -ClusterNodes $ClusterNodes `
    -Credential $Creds

New-FailoverClusterSharedFolder `
    -ClusterName $ClusterName `
    -DomainName $DomainName `
    -ShareServer $ShareServer `
    -SharePath "$SharePath" `
    -ShareName "$ShareName" `
    -Credential $Creds

#>
