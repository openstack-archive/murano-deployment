trap {
    $_
    $CanGo=0;
    exit
}

$CanGo=1;
$srcDir = $env:systemdrive+"\Murano";
$srcPacksPath=$srcDir+"\Files";
$srcScriptsPath=$srcDir+"\Scripts";
$agentDir = ${srcDir} + "\Agent"
$modulesDir = ${srcDir} + "\PS";
$sysIntDir = ${env:ProgramFiles(x86)}+"\Sysinternals Suite";
#Logging levels: 0 - no output, 1 - screen only, 2 - screen and logfile
$LogLevel=2;
$logHorSeparator="---------------------------------------------------------------";
#$scriptLogFile = GetLogPath($MyInvocation);
$scriptLogFile = $srcScriptsPath + "\log.txt";
# Functions must be declared before their execution like in bash.
#
# MSI Installer

function installmsi()
{
    param(
        $installPkgPath
    )
    try
    {
        Log "Installing $installPkgPath ...";
        Start-Process -FilePath msiexec -ArgumentList /i, $installPkgPath, /qn -Wait
    }
    catch
    {
        $except= $_ | fl * -Force;
        Log "Installation of  $installPkgPath FAILS with $except";
    }
}

# Unzip
function unzip()
{
    param(
    $srcPath, $dstPath
    )
        $shellApplication = New-Object -com shell.application;
        $zipPackage = $shellApplication.NameSpace($srcPath);
        $destinationFolder = $shellApplication.NameSpace($dstPath);
        try
        {
            Log "Extracting $srcPath to $dstPath ...";
            $destinationFolder.CopyHere($zipPackage.Items(),0x14);
            # 0x14 - force overwrite
        }
        catch
        {
             $except= $_ | fl * -Force;
             Log "Extraction of $srcPath to $dstPath FAILS with $except";
        }
}

# Unzip on core
function un-zip()
{
    param(
    $srcPath, $dstPath
    )
    try
    {
        Log "Unzipping $srcPath to $dstPath  ...";
        $unzipper="$srcPacksPath\unzip.exe";
        Start-Process -FilePath $unzipper -ArgumentList "-e `"$srcPath`" -d `"$dstPath`"" -Wait
    }
    catch
    {
        $except= $_ | fl * -Force;
        Log "Extraction of $srcPath to $dstPath FAILS with $except";
    }

}
# try run exe install
function runexeinstaller()
{
    param(
        $installer, $argList
    )
    try
    {
        Log "Running $installer ...";
        Start-Process -FilePath $installer -ArgumentList "$argList" -Wait
    }
    catch
    {
        $except= $_ | fl * -Force;
        Log "Installation of  $installer FAILS with $except";
    }
}

# Create dirs
function CreateDir()
{
    param(
        $path
    )
    Log "Creating $path";
    if(Test-Path $path)
    {
        Log "$path already exists, nothing todo";
    }
    else
    {
        New-Item -Path $path -ItemType Container| Out-Null;
        if(!(Test-Path $path))
        {
            Log "Can not create $path, exiting...";
            exit;
        }
    }
}

# Log function
function Log()
{
    param(
        $msg
    )
    $datestamp = Get-Date -Format yyyyMMdd-HHmmss;
    $logString = "$datestamp`t$msg";
    if($LogLevel -ge 1)
    {
        Write-Host "LOG:> $logString";
    }
    if($LogLevel -eq 2)
    {
        Add-Content $scriptLogFile "`n$logString";
    }
}

# Updating registry
function AddToEnvPath()
{
    param (
        $addString
    )
    $oldPath=(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
    if ($oldPath | Select-String -SimpleMatch "$addString")
    {
        Log "$addString already within PATH=`"$oldPath`"";
    }
    else
    {
        $newPath=$oldPath+';'+$addString;
        Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath
        Log "$addString was add to system PATH";
    }
}

# Determining log file path
function GetLogPath()
{
    param (
        $Invocation
    )
    $fullPathIncFileName = $Invocation.MyCommand.Definition;
    $currentScriptName = $Invocation.MyCommand.Name;
    $retVal = $fullPathIncFileName.Replace($currentScriptName, "log.txt");
    return $retVal;
}
#Main sequence
Log "Creating directories...";
CreateDir $agentDir;
CreateDir $modulesDir;
CreateDir $sysIntDir;
CreateDir $sysIntDir;
Log $logHorSeparator;
Log "Installing packages...";
# Installing packages from Files directory
$srcFiles = Get-ChildItem -Path $srcPacksPath;
foreach($file in $srcFiles)
{
    if($file.Attributes -ne "Directory")
    {
        switch($file.Extension)
        {
            ".msi"
            {
                installmsi $file.FullName;
            }
            ".zip"
            {
                switch($file.Name)
                {
                    "MuranoAgent.zip"
                    {
                        un-zip $file.FullName $agentDir;
                        Start-Sleep -s 5;
                        & "$agentDir\WindowsAgent.exe" /install
                    }
                    "CoreFunctions.zip"
                    {
                        un-zip $file.FullName $modulesDir;
                        Start-Sleep -s 5
                        Import-Module "$modulesDir\CoreFunctions\CoreFunctions.psm1" -ArgumentList register;
                    }
                    "SysinternalsSuite.zip"
                    {
                        un-zip $file.FullName $sysIntDir
                    }
                }
            }
            ".exe"
            {
                switch($file.Name)
                {
                    "msysgit.exe"
                    {
                        $gitInstDir="$ENV:ProgramData\git";
                        runexeinstaller $file.FullName "/verysilent /setuptype=custom /components=icons,ext,ext\cheetah,assoc,assoc_sh /bash_context=1 /autocrlf=0 /dir=$gitInstDir";
                        Start-Sleep -s 5;
                        AddToEnvPath "$gitInstDir\cmd";
                    }
                }
            }
        }
    }
}

Log $logHorSeparator;
#Run sysprep and Co.
if($CanGo -eq 1)
{
# For windows 2008 r2 x64
    New-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce -Name "PostInstallSysprep" -Value "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe -Command `"& $srcScriptsPath\w2k8r2-standard\2.Start-Sysprep.ps1 -BatchExecution -CoreFunctionsPath $modulesDir\CoreFunctions\CoreFunctions.psm1`""
    Log "WMF 4.0 (Powershell 4) install ..."
    Start-Process -FilePath wusa.exe -ArgumentList "$srcPacksPath\ps4-x64.msu /quiet /forcerestart" -Wait;
}
