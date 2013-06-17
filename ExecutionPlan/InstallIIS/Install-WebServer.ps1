function Copy-Prerequisites {
	param (
		[String] $Path = '',
		[String] $Destination = ''
	)

	Write-Log "--> Copy-Prerequisites"

    if ($Destination -eq '') {
        throw("Copy-Prerequisites: Destination path not specified!")
    }

    if ($Path -eq '') {
        $Path = [Environment]::GetEnvironmentVariable('MuranoFileShare')
        if ($Path -eq $null) {
            throw("Copy-Prerequisites: Unable to determine source path for prerequisites.")
        }
    }

	Write-Log "Creating new PSDrive ..."
	New-PSDrive -Name 'P' -PSProvider 'FileSystem' -Root $Path | Out-Null
	Write-Log "Creating destination folder ..."
	New-Item -Path $Destination -ItemType Container -Force | Out-Null
	Write-Log "Copying items ..."
	Copy-Item -Path 'P:\Prerequisites\IIS' -Destination $Destination -Recurse -Force | Out-Null
	Write-Log "Removing PSDrive ..."
	Remove-PSDrive -Name 'P' -PSProvider 'FileSystem' -Force | Out-Null
	
	Write-Log "<-- Copy-Prerequisites"
}



function Install-WebServer {
	param (
		[String] $PrerequisitesPath
	)
	
	Write-Log "--> Install-WebServerComponents"

	$FeatureList = @(
		'Web-Server',
		'Web-Net-Ext45',
		'Web-ASP',
		'Web-Asp-Net45',
		'Web-ISAPI-Ext',
		'Web-ISAPI-Filter',
		'Web-Includes'
	)
	
	$PrerequisitesList = @(
		'AspNetMvc4Setup.exe',
		'WebApplications.exe'
	)
    
	$PrerequisitesPath = [IO.Path]::Combine($PrerequisitesPath, 'IIS')
    
	Write-Log "Validating prerequisites based on the list ..."
	foreach ($FileName in $PrerequisitesList) {
		$FilePath = [IO.Path]::Combine($PrerequisitesPath, $FileName)
		if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
			throw("Prerequisite file not found: '$FilePath'")
		}
	}
	
	Import-Module ServerManager
	
	Write-Log "Installing Web Server ..."
	Install-WindowsFeature $FeatureList -IncludeManagementTools
	
	Write-Log "Installing AspNetMvp4 ..."
	$Exec = Exec -FilePath $([IO.Path]::Combine($PrerequisitesPath, 'AspNetMvc4Setup.exe')) -ArgumentList '/q' -PassThru
	if ($Exec.ExitCode -ne 0) {
		throw("Installation of 'AspNetMvc4Setup.exe' failed. Process exit code '$($Exec.ExitCode)'")
	}
	
	# Extract WebApplications folder with *.target files to
	#   C:\Program Files (x86)\MSBuild\Microsoft\VisualStudio\v10.0
	Write-Log "Installing WebApplication targets ..."
	$WebApplicationsTargetsRoot = 'C:\Program Files (x86)\MSBuild\Microsoft\VisualStudio\v10.0'
	$null = New-Item -Path $WebApplicationsTargetsRoot -ItemType Container
	$Exec = Exec -FilePath $([IO.Path]::Combine($PrerequisitesPath, 'WebApplications.exe')) -ArgumentList @("-o`"$WebApplicationsTargetsRoot`"", '-y') -PassThru
	if ($Exec.ExitCode -ne 0) {
		throw("Installation of 'WebApplications.exe' failed. Process exit code '$($Exec.ExitCode)'")
	}

	Write-Log "<-- Install-WebServerComponents"
}

