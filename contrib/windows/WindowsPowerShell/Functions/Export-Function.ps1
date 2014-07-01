
trap {
    &$TrapHandler
}

function Export-Function {
    param (
        [String[]] $Name,

        [Parameter(ValueFromPipeline=$true)]
        [String] $Path = [IO.Path]::GetTempFileName(),

        [Switch] $All
    )

    if ([IO.Path]::GetExtension($Path) -ne 'ps1') {
        $null = Rename-Item -Path $Path -NewName "$Path.ps1" -Force
        $Path = "$Path.ps1"
    }

    $SystemFunctions = @(
        'A:', 'B:', 'C:', 'D:', 'E:', 'F:', 'G:', 'H:', 'I:', 'J:',
        'K:', 'L:', 'M:', 'N:', 'O:', 'P:', 'Q:', 'R:', 'S:', 'T:',
        'U:', 'V:', 'W:', 'X:', 'Y:', 'Z:',
        'cd..', 'cd\', 'help', 'mkdir', 'more', 'oss', 'prompt',
        'Clear-Host', 'Get-Verb', 'Pause', 'TabExpansion2'
    )

    if ($All) {
        Get-ChildItem Function: |
            Where-Object {$_.ModuleName -eq ''} |
            Where-Object {$SystemFunctions -notcontains $_.Name} |
            ForEach-Object {
                Add-Content -Path $Path -Value @"


function $($_.Name) {
$($_.ScriptBlock)
}

"@
            }
    }
    else {
        foreach ($FunctionName in $Name) {
            $FunctionObject = Get-ChildItem "Function:\$FunctionName"
            if ($FunctionObject -ne $null) {
                Add-Content -Path $Path -Value @"


function $FunctionName {
$($FunctionObject.ScriptBlock)
}

"@
            }
        }
    }

    return $Path
}
