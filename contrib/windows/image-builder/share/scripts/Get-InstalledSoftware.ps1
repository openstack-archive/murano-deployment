Function Get-InstalledSoftware{ 
    Param([String[]]$Computers)  
    If (!$Computers) {$Computers = $ENV:ComputerName} 
    $Base = New-Object PSObject; 
    $Base | Add-Member Noteproperty ComputerName -Value $Null; 
    $Base | Add-Member Noteproperty Name -Value $Null; 
    $Base | Add-Member Noteproperty Publisher -Value $Null; 
    $Base | Add-Member Noteproperty InstallDate -Value $Null; 
    $Base | Add-Member Noteproperty EstimatedSize -Value $Null; 
    $Base | Add-Member Noteproperty Version -Value $Null; 
    $Base | Add-Member Noteproperty Wow6432Node -Value $Null; 
    $Results =  New-Object System.Collections.Generic.List[System.Object]; 
 
    ForEach ($ComputerName in $Computers){ 
        $Registry = $Null; 
        Try{$Registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$ComputerName);} 
        Catch{Write-Host -ForegroundColor Red "$($_.Exception.Message)";} 
         
        If ($Registry){ 
            $UninstallKeys = $Null; 
            $SubKey = $Null; 
            $UninstallKeys = $Registry.OpenSubKey("Software\Microsoft\Windows\CurrentVersion\Uninstall",$False); 
            $UninstallKeys.GetSubKeyNames()|%{ 
                $SubKey = $UninstallKeys.OpenSubKey($_,$False); 
                $DisplayName = $SubKey.GetValue("DisplayName"); 
                If ($DisplayName.Length -gt 0){ 
                    $Entry = $Base | Select-Object * 
                    $Entry.ComputerName = $ComputerName; 
                    $Entry.Name = $DisplayName.Trim();  
                    $Entry.Publisher = $SubKey.GetValue("Publisher");  
                    [ref]$ParsedInstallDate = Get-Date 
                    If ([DateTime]::TryParseExact($SubKey.GetValue("InstallDate"),"yyyyMMdd",$Null,[System.Globalization.DateTimeStyles]::None,$ParsedInstallDate)){                     
                    $Entry.InstallDate = $ParsedInstallDate.Value 
                    } 
                    $Entry.EstimatedSize = [Math]::Round($SubKey.GetValue("EstimatedSize")/1KB,1); 
                    $Entry.Version = $SubKey.GetValue("DisplayVersion"); 
                    [Void]$Results.Add($Entry); 
                } 
            } 
             
                If ([IntPtr]::Size -eq 8){ 
                $UninstallKeysWow6432Node = $Null; 
                $SubKeyWow6432Node = $Null; 
                $UninstallKeysWow6432Node = $Registry.OpenSubKey("Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",$False); 
                    If ($UninstallKeysWow6432Node) { 
                        $UninstallKeysWow6432Node.GetSubKeyNames()|%{ 
                        $SubKeyWow6432Node = $UninstallKeysWow6432Node.OpenSubKey($_,$False); 
                        $DisplayName = $SubKeyWow6432Node.GetValue("DisplayName"); 
                        If ($DisplayName.Length -gt 0){ 
                            $Entry = $Base | Select-Object * 
                            $Entry.ComputerName = $ComputerName; 
                            $Entry.Name = $DisplayName.Trim();  
                            $Entry.Publisher = $SubKeyWow6432Node.GetValue("Publisher");  
                            [ref]$ParsedInstallDate = Get-Date 
                            If ([DateTime]::TryParseExact($SubKeyWow6432Node.GetValue("InstallDate"),"yyyyMMdd",$Null,[System.Globalization.DateTimeStyles]::None,$ParsedInstallDate)){                      
                            $Entry.InstallDate = $ParsedInstallDate.Value 
                            } 
                            $Entry.EstimatedSize = [Math]::Round($SubKeyWow6432Node.GetValue("EstimatedSize")/1KB,1); 
                            $Entry.Version = $SubKeyWow6432Node.GetValue("DisplayVersion"); 
                            $Entry.Wow6432Node = $True; 
                            [Void]$Results.Add($Entry); 
                            } 
                        } 
                    } 
                } 
        } 
    } 
    $Results 
}