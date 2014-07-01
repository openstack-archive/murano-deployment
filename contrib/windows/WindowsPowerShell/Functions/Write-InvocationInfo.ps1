
function Write-InvocationInfo {
    param (
        $Invocation,
        [Switch] $End
    )

    if ($End) {
        Write-LogDebug "</function name='$($Invocation.MyCommand.Name)'>"
    }
    else {
        Write-LogDebug "<function name='$($Invocation.MyCommand.Name)'>"
        Write-LogDebug "<param>"
        foreach ($Parameter in $Invocation.MyCommand.Parameters) {
            foreach ($Key in $Parameter.Keys) {
                $Type = $Parameter[$Key].ParameterType.FullName
                foreach ($Value in $Invocation.BoundParameters[$Key]) {
                    Write-LogDebug "[$Type] $Key = '$Value'"
                }
            }
        }
        Write-LogDebug "</param>"
    }
}

