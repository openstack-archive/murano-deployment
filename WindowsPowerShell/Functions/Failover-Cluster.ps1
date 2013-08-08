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

trap {
    &$TrapHandler
}



function Install-FailoverClusterPrerequisites {
    #Import-Module FailoverClusters

    Add-WindowsFeature Failover-Clustering, RSAT-Clustering-PowerShell
}



function New-FailoverClusterSharedFolder {
	param (
        [String] $ClusterName,
        [String] $DomainName,
        [String] $ShareServer,
		[String] $SharePath = $($Env:SystemDrive + '\FCShare'),
		[String] $ShareName = 'FCShare',
        [String] $UserName,
        [String] $UserPassword,
        $Credential = $null
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

        Write-Log "--> New-FailoverClusterSharedFolder"

        Write-Log "Creating shared folder for Failover Cluster ..."
        
        if ($Credential -eq $null) {
            $Credential = New-Credential -UserName "$DomainName\$UserName" -Password "$UserPassword"
        }

        if ((Test-Connection -ComputerName $ShareServer -Count 1 -Quiet) -eq $false) {
            throw("Server '$ShareServer' is unreachable via ICMP.")
        }

        $Session = New-PSSession -ComputerName $ShareServer -Credential $Credential

        Write-Log "Creating folder on '$ShareServer' ..."
        Invoke-Command -Session $Session -ScriptBlock {
                param (
                    [String] $SharePath,
                    [String] $ShareName,
                    [String] $ClusterAccount
                )

                Remove-SmbShare -Name $ShareName -Force -ErrorAction 'SilentlyContinue'
                Remove-Item -Path $SharePath -Force -ErrorAction 'SilentlyContinue'

                New-Item -Path $SharePath -ItemType Container -Force
                
                New-SmbShare -Path $SharePath `
                    -Name $ShareName `
                    -FullAccess "$ClusterAccount", 'Everyone' `
                    -Description "Shared folder for Failover Cluster."

            } -ArgumentList $SharePath, $ShareName, "$DomainName\$ClusterName`$"

        Write-Log "Confguring Failover Cluster to use shared folder as qourum resourse ..."

        $null = Set-ClusterQuorum -NodeAndFileShareMajority "\\$ShareServer\$ShareName"

        Write-Log "<-- New-FailoverClusterSharedFolder"
    }
}



function New-FailoverCluster {
	param (
        [String] $ClusterName,
        [String] $StaticAddress,
        [String[]] $ClusterNodes,
        [String] $DomainName,
        [String] $UserName,
        [String] $UserPassword,
        $Credential
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

        Write-Log "ClusterNodes: $($ClusterNodes -join ', ')"

        if ($Credential -eq $null) {
            $Credential = New-Credential -UserName "$DomainName\$UserName" -Password "$UserPassword"
        }

        Import-Module FailoverClusters

    	if ((Get-Cluster $ClusterName -ErrorAction SilentlyContinue) -eq $null) {
            Write-Log "Creating new cluster '$ClusterName' ..."
            Start-PowerShellProcess -Command @"
Import-Module FailoverClusters
New-Cluster -Name '$ClusterName' -StaticAddress '$StaticAddress'
"@ -Credential $Credential -NoBase64
            Start-Sleep -Seconds 15
        }
        else {
            Write-Log "Cluster '$ClusterName' already exists."
        }

        foreach ($Node in $ClusterNodes) {
            Write-Log "Adding node '$Node' to the cluster '$ClusterName' ..."
            if ((Get-ClusterNode $Node -ErrorAction SilentlyContinue) -eq $null) {
                Write-Log "Adding node ..."
                Start-PowerShellProcess -Command @"
Import-Module FailoverClusters
Add-ClusterNode -Cluster '$ClusterName' -Name '$Node'
"@ -Credential $Credential -NoBase64
            }
            else {
                Write-Log "Node '$Node' already a part of the cluster '$ClusterName'."
            }
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
