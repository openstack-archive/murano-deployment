function Copy-Prerequisites {
	param (
		[String] $Path = '',
		[String] $Destination = ''
	)

    if ($Destination -eq '') {
        throw("Copy-Prerequisites: Destination path not specified!")
    }

    if ($Path -eq '') {
        $Path = [Environment]::GetEnvironmentVariable('MuranoFileShare')
        if ($Path -eq $null) {
            throw("Copy-Prerequisites: Unable to determine source path for prerequisites.")
        }
    }

	New-PSDrive -Name 'P' -PSProvider 'FileSystem' -Root $Path
	$null = New-Item -Path $Destination -ItemType Container -Force
	Copy-Item -Path 'P:\Prerequisites\IIS' -Destination $Destination -Recurse -Force
	Remove-PSDrive -Name 'P' -PSProvider 'FileSystem' -Force
}



function Install-WebServerComponents {
	param (
		[String] $PrerequisitesPath
	)
	
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
    
	foreach ($FileName in $PrerequisitesList) {
		$FilePath = [IO.Path]::Combine($PrerequisitesPath, $FileName)
		if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
			throw("Prerequisite file not found: '$FilePath'")
		}
	}
	
	Import-Module ServerManager
	
	Install-WindowsFeature $FeatureList -IncludeManagementTools
	
	$Exec = Exec -FilePath [IO.Path]::Combine($PrerequisitesPath, 'AspNetMvc4Setup.exe') -ArgumentList '/q'
	if ($Exec.ExitCode -ne 0) {
		throw("Installation of 'AspNetMvc4Setup.exe' failed. Process exit code '$($Exec.ExitCode)'")
	}
	
	# Extract WebApplications folder with *.target files to
	#   C:\Program Files (x86)\MSBuild\Microsoft\VisualStudio\v10.0
	$WebApplicationsTargetsRoot = 'C:\Program Files (x86)\MSBuild\Microsoft\VisualStudio\v10.0'
	$null = New-Item -Path $WebApplicationsTargetsRoot -ItemType Container
	$Exec = Exec -FilePath [IO.Path]::Combine($PrerequisitesPath, 'WebApplications.exe') -ArgumentList @("-o`"$WebApplicationsTargetsRoot`"", '-y')
	if ($Exec.ExitCode -ne 0) {
		throw("Installation of 'WebApplications.exe' failed. Process exit code '$($Exec.ExitCode)'")
	}
}

