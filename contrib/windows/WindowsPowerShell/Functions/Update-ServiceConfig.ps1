
trap {
    &$TrapHandler
}



function Update-ServiceConfig {
    param (
        [String] $Name,
        [String] $RunAsUser = '',
        [String] $DomainName = '.',
        [String] $Password = '',
        [Switch] $RunAsLocalService
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

        $ArgumentList = @('config', "`"$Name`"")

        if ($RunAsLocalService) {
            $ArgumentList += @("obj=", "`"NT AUTHORITY\LocalService`"")
        }
        elseif ($RunAsUser -ne '') {
            $ArgumentList += @("obj=", "`"$DomainName\$RunAsUser`"", "password=", "`"$Password`"")
        }

        $Process = Exec 'sc.exe' $ArgumentList -PassThru -RedirectStreams

        if ($Process.ExitCode -ne 0) {
            throw "Command 'sc.exe' returned exit code '$($Process.ExitCode)'"
        }

        $NtRights = "C:\Murano\Tools\ntrights.exe"

        if (-not ([IO.File]::Exists($NtRights))) {
            throw "File '$NtRights' not found."
        }

        $Process = Exec $NtRights @('-u', "$DomainName\$RunAsUser", '+r', 'SeServiceLogonRight') -RedirectStreams -PassThru

        if ($Process.ExitCode -ne 0) {
            throw "Command '$NtRights' returned exit code '$($Process.ExitCode)'"
        }

        $Process = Exec $NtRights @('-u', "$DomainName\$RunAsUser", '+r', 'SeBatchLogonRight') -RedirectStreams -PassThru

        if ($Process.ExitCode -ne 0) {
            throw "Command '$NtRights' returned exit code '$($Process.ExitCode)'"
        }
    }
}
