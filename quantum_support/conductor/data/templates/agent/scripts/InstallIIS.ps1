
trap {
    &$TrapHandler
}


Function Install-WebServer {
	param (
		[String] $PrerequisitesPath
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
	
		Write-Log "--> Install-WebServer"

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

		Write-Log "<-- Install-WebServer"
	}
}
