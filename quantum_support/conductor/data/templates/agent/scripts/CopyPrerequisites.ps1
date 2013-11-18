
trap {
    &$TrapHandler
}


Function Copy-Prerequisites {
	param (
		[String] $Path = '',
		[String] $Destination = ''
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
}
