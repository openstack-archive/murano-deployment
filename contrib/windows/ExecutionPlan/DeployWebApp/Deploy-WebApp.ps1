
function Register-WebApp {
<#
.LINKS

http://www.iis.net/learn/manage/powershell/powershell-snap-in-creating-web-sites-web-applications-virtual-directories-and-application-pools
#>
	param (
		[String] $Source,
		[String] $Path = "C:\inetpub\wwwroot",
		[String] $Name = "",
		[String] $Username = "",
		[String] $Password = ""
	)

	Import-Module WebAdministration
	
	if ($Name -eq "") {
		$Name = @([IO.Path]::GetDirectoryName($Source) -split '\\')[-1]
		if ($Name -eq "wwwroot") {
			throw("Application pool name couldn't be 'wwwroot'.")
		}
	}
	else {
		$Path = [IO.Path]::Combine($Path, $Name)
	}

	Copy-Item -Path $Source -Destination $Path -Recurse -Force
	

	# Create new application pool
    $AppPool = New-WebAppPool -Name $Name -Force
    #$AppPool = Get-Item "IIS:\AppPools\$Name"
    $AppPool.managedRuntimeVersion = 'v4.0'
    $AppPool.managedPipelineMode = 'Classic'
    $AppPool.processModel.loadUserProfile = $true
    $AppPool.processModel.logonType = 'LogonBatch'
    
	#Set Identity type
	if ($Username -eq "") {
		$AppPool.processModel.identityType = 'ApplicationPoolIdentity'
	}
	else {
	    $AppPool.processModel.identityType = 'SpecificUser'
	    $AppPool.processModel.userName = $Username
	    $AppPool.processModel.password = $Password
	    $AppPool | Set-Item
	}


    # Create Website
    $WebSite = New-WebSite -Name $Name -Port 80 -HostHeader $Name -PhysicalPath $Path -Force
    #$WebSite = Get-Item "IIS:\Sites\$Name"
    
	# Set the Application Pool
    Set-ItemProperty "IIS:\Sites\$Name" 'ApplicationPool' $Name
    
	#Turn on Directory Browsing
    #Set-WebConfigurationProperty -Filter '/system.webServer/directoryBrowse' -Name 'enabled' -Value $true -PSPath "IIS:\Sites\$Name"
    
	# Update Authentication
    #Set-WebConfigurationProperty -Filter '/system.WebServer/security/authentication/AnonymousAuthentication' -Name 'enabled' -Value $true -Location $name
    #Set-WebConfigurationProperty -Filter '/system.WebServer/security/authentication/windowsAuthentication' -Name 'enabled' -Value $false -Location $Name
    #Set-WebConfigurationProperty -Filter '/system.WebServer/security/authentication/basicAuthentication' -Name 'enabled' -Value $false -Location $Name
	
	$WebSite.Start()

	Add-Content -Path "C:\Windows\System32\Drivers\etc\hosts" -Value "127.0.0.1   $Name"
}


function Deploy-WebAppFromGit {
	param (
		[String] $URL,
		[String] $TempPath = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName()),
		[String] $OutputPath = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName())
	)
	Write-Log "TempPath = '$TempPath'"
	Write-Log "OutputPath = '$OutputPath'"
	
	
	# Fetch web application
	#----------------------
	Write-Log "Fetching sources from Git ..."
	
	$null = New-Item -Path $TempPath -ItemType Container
	Exec -FilePath 'git.exe' -ArgumentList @('clone', $URL) -WorkingDir $TempPath -RedirectStreams
	
	$Path = @(Get-ChildItem $TempPath)[0].FullName
	#----------------------
	
	
	# Build web application
	#----------------------
	Write-Log "Building sources ..."
	
	$msbuild = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"
	
	$null = New-Item -Path $OutputPath -ItemType Container
	
	$SlnFiles = @(Get-ChildItem -Path $Path -Filter *.sln -Recurse)

    # Start new processs with additional env variables:
	#* VisualStudioVersion = "10.0"
	#* EnableNuGetPackageRestore  = "true"
	Exec -FilePath $msbuild `
		-ArgumentList @($SlnFiles[0].FullName, "/p:OutputPath=$OutputPath") `
		-Environment @{'VisualStudioVersion' = '10.0'; 'EnableNuGetPackageRestore' = 'true'} `
		-RedirectStreams
	
	$AppFolder = @(Get-ChildItem ([IO.Path]::Combine($OutputPath, '_PublishedWebsites')))[0]
	#----------------------
	
	
	# Install web application
	#------------------------
	Register-WebApp -Source $AppFolder.FullName -Name $AppFolder.Name
	#------------------------
}
