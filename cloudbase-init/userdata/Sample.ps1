Import-Module CoreFunctions

$ModuleBase = "C:\Murano\Modules"


$NewModule_Name = "ModuleName"
$NewModule_Base64 = @'
%BASE64_STRINGS%
'@


$AgentConfig_Path = "C:\Murano\Agent\WindowsAgent.exe.config"
$AgentConfig_Base64 = @'
%AGENT_CONFIG_BASE64%
'@


ConvertFrom-Base64String -Base64String $NewModule_Base64 -Path "$ModuleBase\$NewModule_Name.zip"
Remove-Item -Path "$ModuleBase\$NewModule_Name" -Recurse -Force
Expand-Zip -Path "$ModuleBase\$NewModule_Name.zip" -Destination "$ModuleBase\$NewModule_Name"


Remove-Item -Path $AgentConfig_Path -Force
ConvertFrom-Base64String -Base64String $NewModule_Base64 -Path $AgentConfig_Path
