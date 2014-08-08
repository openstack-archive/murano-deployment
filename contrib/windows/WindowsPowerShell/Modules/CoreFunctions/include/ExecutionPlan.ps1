function New-ExecutionResult {
    param (
        [Object] $Result = $null,
        [Switch] $IsException
    )

    $obj = New-Object -TypeName PSObject |
        Add-Member -Type NoteProperty -Name IsException -Value ([Bool] $IsException) -PassThru |
        Add-Member -Type NoteProperty -Name Result -Value $Result -PassThru

    $obj.PSTypeNames.Insert(0, 'Custom.MuranoAgentExecutionsResult')

    return $obj
}



function Add-ExecutionResult {
    param (
        [Object] $InputObject,
        [Object] $Result,
        [Switch] $IsException
    )

    if (@($InputObject.Result)[0].PSTypeNames -contains 'Custom.MuranoAgentExecutionsResult') {
        $InputObject.Result = @($InputObject.Result) + @(New-ExecutionResult $Result -IsException:$IsException)
    }
    else {
        $InputObject.Result = New-ExecutionResult $Result -IsException:$IsException
    }

    if (-not $InputObject.IsException) {
        $InputObject.IsException = ([Bool] $IsException)
    }

    $InputObject
}


function Load-FromJsonFile {
    param (
        [String] $Path = ''
    )
    Write-LogDebug "Loading JSON from file '$Path'"

    if ([IO.File]::Exists($Path)) {
        Get-Content $Path | ConvertFrom-Json
    }
    else {
        throw ("No stored execution plan available.")
    }
}



function Save-ToJsonFile {
    param (
        [String] $Path = '',
        [Object] $ExecutionPlan
    )
    Write-LogDebug "Saving JSON to file '$Path'"

    $ExecutionPlan | ConvertTo-Json -Depth 10 | Out-File $Path
}



function Invoke-ExecutionPlan {
    param (
        [String] $ExecutionPlan = ''
    )

    $ExecutionPlanTempFolder = [IO.Path]::Combine($__ModulePath, 'temp')
    $ExecutionPlanCache_plan = [IO.Path]::Combine($ExecutionPlanTempFolder, 'plan.json')
    $ExecutionPlanCache_result = [IO.Path]::Combine($ExecutionPlanTempFolder, 'result.json')


    try {
        $ExecutionResult = Load-FromJsonFile $ExecutionPlanCache_result
    }
    catch {
        $ExecutionResult = New-ExecutionResult
    }


    try {
        if ($ExecutionPlan -eq '') {
            $ExecutionPlanObject = Load-FromJsonFile $ExecutionPlanCache_plan
        }
        else {
            $ExecutionPlanObject = ConvertFrom-Base64String -Base64String $ExecutionPlan -ToString |
                ConvertFrom-Json |
                Add-Member -Type NoteProperty -Name 'NextCommandIndex' -Value 0 -PassThru
        }
    }
    catch {
        $ExecutionResult.Result = $_ -as "String"
        $ExecutionResult.IsException = $true
        $ExecutionResult | ConvertTo-Json -Depth 10
        return
    }

    try {
        foreach ($Base64Script in $ExecutionPlanObject.Scripts) {
            $ExecutionPlanScript = ConvertFrom-Base64String -Base64String $Base64Script -ToString
            Write-LogDebug @"
Invoking script block
# SCRIPT BLOCK START
$ExecutionPlanScript
# SCRIPT BLOCK END
"@
            Invoke-Expression $ExecutionPlanScript | Out-Null
        }

        $CommandIndex = $ExecutionPlanObject.NextCommandIndex
        while ($CommandIndex -lt $ExecutionPlanObject.Commands.Count) {
            Write-LogDebug "Executing step '$CommandIndex' ..."
            $Command = ConvertTo-PowerShellCommand $ExecutionPlanObject.Commands[$CommandIndex]
            if ($Command -like 'import-module*corefunctions*') {
                Write-Warning "Command '$Command' skipped."
                $ExecutionResult = Add-ExecutionResult $ExecutionResult "Command '$Command' skipped."
            }
            else {
                Write-LogDebug "Invoking command '$command'"
                $ExecutionResult = Add-ExecutionResult $ExecutionResult $(Invoke-Expression $Command)
            }

            $CommandIndex++
            $ExecutionPlanObject.NextCommandIndex = $CommandIndex
            Save-ToJsonFile $ExecutionPlanCache_plan $ExecutionPlanObject

            Save-ToJsonFile $ExecutionPlanCache_result $ExecutionResult
        }
    }
    catch {
        $ExecutionResult = Add-ExecutionResult $ExecutionResult $($_ -as "String") -IsException
        $ExecutionResult | ConvertTo-Json -Depth 10
        return
    }

    if ($CommandIndex -ge $ExecutionPlanObject.Commands.Count) {
        Write-LogDebug "All commands were executed successfully!"
    }

    $ExecutionResult | ConvertTo-Json -Depth 10
}



function ConvertTo-PowerShellCommand {
    param (
        [Object] $InputObject
    )

    $Command = $InputObject.Name

    $InputObject.Arguments |
        Get-Member -MemberType NoteProperty |
        ForEach-Object {
            $ArgName = $_.Name
            $Command += " -$ArgName `"" + $InputObject.Arguments.$ArgName + "`""
        }

    $Command
}
