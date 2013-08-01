
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
        [Switch] $IgnoreStdErr
    )
    
    $Bytes = [Text.Encoding]::Unicode.GetBytes($Command)
    $EncodedCommand = [Convert]::ToBase64String($Bytes)

    Write-Host $EncodedCommand

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

    $ErrorActionPreferenceSaved = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    Write-Log "StdOut file is '$StdOut'"
    Write-Log "StdErr file is '$StdErr'"

    Select-CliXmlBlock $StdOut 

    if ((Get-Item $StdOut).Length -gt 0) {
        Write-Log "Loading StdOut from '$StdOut'"
        $TmpFile = Select-CliXmlBlock $StdOut
        Import-Clixml $TmpFile
        Remove-Item -Path $TmpFile -Force
    }

    Select-CliXmlBlock $StdErr

    if (-not $IgnoreStdErr) {
        if ((Get-Item $StdErr).Length -gt 0) {
            Write-Log "Loading StdErr from '$StdErr'"
            $TmpFile = Select-CliXmlBlock $StdErr
            Import-Clixml $TmpFile
            Remove-Item -Path $TmpFile -Force
        }
    }

    $ErrorActionPreference = $ErrorActionPreferenceSaved

    if ($Process.ExitCode -ne 0) {
        throw("External PowerShell process exited with code '$($Process.ExitCode)'")
    }

    #Remove-Item $StdOut -Force
    #Remove-Item $StdErr -Force
}
