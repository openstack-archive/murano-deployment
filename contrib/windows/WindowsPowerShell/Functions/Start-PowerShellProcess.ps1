
trap {
    &$TrapHandler
}



function Select-CliXmlBlock {
    param (
        [String] $Path,
        [String] $OutFile = [IO.Path]::GetTempFileName()
    )

    $TagFound = $false
    Get-Content $Path |
        ForEach-Object {
            if ($_ -eq '#< CLIXML') {
                $TagFound = $true
            }
            if ($TagFound) {
                Add-Content -Path $OutFile -Value $_
            }
        }
    $OutFile
}



function Start-PowerShellProcess {
    param (
        [String] $Command,
        $Credential = $null,
        [Switch] $IgnoreStdErr,
        [Switch] $NoBase64
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

        $StdOut = [IO.Path]::GetTempFileName()
        $StdErr = [IO.Path]::GetTempFileName()

        $ArgumentList = @('-OutputFormat', 'XML')

        if ($NoBase64) {
            $TmpScript = [IO.Path]::GetTempFileName()
            Rename-Item -Path "$TmpScript" -NewName "$TmpScript.ps1" -Force
            $TmpScript = "$TmpScript.ps1"

            Write-LogDebug $TmpScript

            $Command | Out-File $TmpScript

            $ArgumentList += @('-File', "$TmpScript")
        }
        else {
            $Bytes = [Text.Encoding]::Unicode.GetBytes($Command)
            $EncodedCommand = [Convert]::ToBase64String($Bytes)
            
            Write-LogDebug $EncodedCommand

            $ArgumentList += @('-EncodedCommand', $EncodedCommand)
        }

        Write-LogDebug $ArgumentList

        Write-Log "Starting external PowerShell process ..."

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

        Write-Log "External PowerShell process exited with exit code '$($Process.ExitCode)'."

        #if ($ArgumentList -contains '-File') {
        #    Remove-Item -Path $TmpScript -Force
        #}

        $ErrorActionPreferenceSaved = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'

        Write-LogDebug "StdOut file is '$StdOut'"
        Write-LogDebug "StdErr file is '$StdErr'"

        if ((Get-Item $StdOut).Length -gt 0) {
            try {
                Write-LogDebug "Loading StdOut from '$StdOut'"
                $TmpFile = Select-CliXmlBlock $StdOut
                $StdOutObject = Import-Clixml $TmpFile
                Write-LogDebug "<StdOut>"
                Write-LogDebug ($StdOutObject)
                Write-LogDebug "</StdOut>"
                $StdOutObject
                #Remove-Item -Path $TmpFile -Force
            }
            catch {
                Write-LogDebug "An error occured while loading StdOut from '$TmpFile'"
            }
        }

        if ((Get-Item $StdErr).Length -gt 0) {
            try {
                Write-LogDebug "Loading StdErr ..."
                $TmpFile = Select-CliXmlBlock $StdErr
                $StdErrObject = Import-Clixml $TmpFile
                Write-LogDebug "<StdErr>"
                Write-LogDebug ($StdErrObject)
                Write-LogDebug "</StdErr>"
                if (-not $IgnoreStdErr) {
                    $StdErrObject
                }
                #Remove-Item -Path $TmpFile -Force
            }
            catch {
                Write-LogDebug "An error occured while loading StdErr from '$TmpFile'"
            }
        }

        $ErrorActionPreference = $ErrorActionPreferenceSaved

        if ($Process.ExitCode -ne 0) {
            throw("External PowerShell process exited with code '$($Process.ExitCode)'")
        }

        #Remove-Item $StdOut -Force
        #Remove-Item $StdErr -Force
    }
}
