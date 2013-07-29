<#
.DESCRIPTION

Failover Cluster Input Data (from the UI):

* Domain Membership
    - [String] or [Select box]: Domain name
* Domain User Credentials
    - [String]: Username
    - [Password string]: Password
* Shared Folder Information
    - [String]: Server which will host the folder
    - [String]: Share name
    - [String]: Shared folder internal path
* Failover Cluster Members
    - [String]: Cluster name
    - [String[]]: List of node names

Failover Cluster creation workflow:

* Create AD domain
* Join all the VMs to that domain
* Prepare nodes
    - Install Failover Cluster prerequisites on all FC nodes
    - Disable or configure firewall (?)
* Create failover cluster
    - Create new cluster
    - Add members
* Create shared folder
    - Create new folder
    - Share that folder with appropriate permissions
* Confugure FC quorum
    - Configure quorum mode



Helpful SmbShare* Functions:

* New-SmbShare
* Grant-SmbShareAccess


TODO
====

[-] Script to create shared folder for FC (New-FailoverClusterSharedFolder)

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


<#
function New-FailoverClusterSharedFolder {
	param (
		[String] $Path,
		[String] $ShareName,
        [String] $DomainName,
		[String] $ClusterName
	)
    
    New-Item -Path $Path -ItemType Container -Force
    
    New-SmbShare -Path $Path `
        -Name $ShareName `
        -FullAccess "$DomainName\$ClusterName`$" `
        -Description "Shared folder for Failover Cluster."
}
#>


function New-FailoverCluster {
	param (
		[String] $Name,
		[String] $StaticAddress,
		[String[]] $Members,
		[String] $SharedFolder,
        $Credential
	)
    Import-Module FailoverClusters

	if ((Get-Cluster $Name -ErrorAction SilentlyContinue) -eq $null) {
        Write-Log "Creating new cluster '$Name' ..."
        Start-PowerShellProcess -Command @"
Import-Module FailoverClusters
New-Cluster -Name '$Name' -StaticAddress '$StaticAddress'
"@ -Credential $Credential
        Start-Sleep -Seconds 15
    }
    else {
        Write-Log "Cluster '$Name' already exists."
    }

    foreach ($Node in $Members) {
        if ((Get-ClusterNode $Node -ErrorAction SilentlyContinue) -eq $null) {
            Write-Log "Adding node '$Node' to the cluster '$Name' ..."
            Start-PowerShellProcess -Command @"
Import-Module FailoverClusters
Add-ClusterNode -Cluster '$Name' -Name '$Node'
"@ -Credential $Credential
        }
        else {
            Write-Log "Node '$Node' already a part of the cluster '$Name'."
        }
    }

    #Set-ClusterQuorum -NodeAndFileShareMajority $SharedFolder
}



<#
Import-Module CoreFunctions -Force

$Creds = New-Credential -UserName 'fc-acme\Administrator' -Password 'P@ssw0rd'

New-FailoverCluster -Name 'fc-test-3' -StaticAddress '10.200.0.60' -Members 'fc-node-01','fc-node-02','fc-node-03' -Credential $Creds
#>
