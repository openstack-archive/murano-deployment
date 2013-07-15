Function Join-Domain {
<#
.SYNOPSIS
Executes "Join domain" action.

Requires 'CoreFunctions' module.
#>
	param (
		[String] $DomainName = '',
		[String] $UserName = '',
		[String] $Password = '',
		[String] $OUPath = '',
        [Switch] $AllowRestart
	)
	
	if ($UserName -eq '') {
		$UserName = 'Administrator'
	}

	$Credential = New-Credential -UserName "$DomainName\$UserName" -Password $Password

	if (Test-ComputerName -DomainName $DomainName) {
        Write-LogWarning "Computer already joined to domain '$DomainName'"
	}
	else {
		Write-Log "Joining computer to domain '$DomainName' ..."
		
		if ($OUPath -eq '') {
			Add-Computer -DomainName $DomainName -Credential $Credential -Force -ErrorAction Stop
		}
		else {
			Add-Computer -DomainName $DomainName -Credential $Credential -OUPath $OUPath -Force -ErrorAction Stop
		}
		
        if ($AllowRestart) {
            Write-Log "Restarting computer ..."
            Restart-Computer -Force
        }
        else {
            Write-Log "Please restart the computer now."
        }
	}
}
