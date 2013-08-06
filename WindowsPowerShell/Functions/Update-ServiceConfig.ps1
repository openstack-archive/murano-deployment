
function Update-ServiceConfig {
    param (
        [String] $Name,
        [String] $RunAsUser = '',
        [String] $Password = '',
        [Switch] $RunAsLocalService
    )

    $ArgumentList = @('config', "`"$Name`"")

    if ($RunAsLocalService) {
        $ArgumentList += @("obj=", "`"NT AUTHORITY\LocalService`"")
    }
    elseif ($RunAsUser -ne '') {
        $ArgumentList += @("obj=", "`"$RunAsUser`"", "password=", "`"$Password`"")
    }

    $Process = Exec 'sc.exe' $ArgumentList -PassThru -RedirectStreams

    if ($Process.ExitCode -ne 0) {
        throw "Command 'sc.exe' returned exit code '$($Process.ExitCode)'"
    }
}
