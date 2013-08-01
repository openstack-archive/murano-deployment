
function Export-Function {
    param (
        [String[]] $Name,

        [Parameter(ValueFromPipeline=$true)]
        [String] $Path = [IO.Path]::GetTempFileName()
    )

    foreach ($FunctionName in $Name) {
        $FunctionObject = Get-ChildItem "Function:\$FunctionName"
        if ($FunctionObject -ne $null) {
            Add-Content -Path $Path -Value @"


function $FunctionName {
$($FunctionObject.Definition)
}

"@
        }
    }
    return $Path
}
