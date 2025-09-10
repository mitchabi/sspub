$ErrorActionPreference="SilentlyContinue"

function SecureBootState { $s=$null; if (Get-Command Confirm-SecureBootUEFI -ErrorAction SilentlyContinue){try{$s=Confirm-SecureBootUEFI -ErrorAction Stop}catch{$s="Unknown: $($_.Exception.Message)"}}; if ($s -is [bool]){if($s){"Enabled"}else{"Disabled"}}elseif($s){$s}else{"Unsupported"} }
function BiosInfo { $b=Get-CimInstance Win32_BIOS; [pscustomobject]@{Vendor=$b.Manufacturer;Version=$b.SMBIOSBIOSVersion;ReleaseDate=$b.ReleaseDate} }
function OsInfo { $o=Get-CimInstance Win32_OperatingSystem; $cv=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; $disp=$cv.DisplayVersion; if(-not $disp){$disp=$cv.ReleaseId}; $edition=$cv.EditionID; $boot=[Management.ManagementDateTimeConverter]::ToDateTime($o.LastBootUpTime); $upt=[int]((New-TimeSpan -Start $boot -End (Get-Date)).TotalSeconds); [pscustomobject]@{Name=$o.Caption;Version=$o.Version;Build=$o.BuildNumber;DisplayVersion=$disp;Edition=$edition;InstallDate=[Management.ManagementDateTimeConverter]::ToDateTime($o.InstallDate);LastBoot=$boot;UptimeSeconds=$upt} }
function CpuInfo { $c=Get-CimInstance Win32_Processor | Select-Object -First 1; [pscustomobject]@{Name=$c.Name;Cores=$c.NumberOfCores;LogicalProcessors=$c.NumberOfLogicalProcessors;MaxClockMHz=$c.MaxClockSpeed} }
function RamInfo { $cs=Get-CimInstance Win32_ComputerSystem; [pscustomobject]@{TotalGB=[math]::Round($cs.TotalPhysicalMemory/1GB,2)} }
function GpuInfo { Get-CimInstance Win32_VideoController | ForEach-Object {[pscustomobject]@{Name=$_.Name;DriverVersion=$_.DriverVersion;VRAM_GB=if($_.AdapterRAM){[math]::Round($_.AdapterRAM/1GB,2)}else{$null}}} }
function NetworkSummary { $ad=Get-NetAdapter | Where-Object {$_.Status -ne $null}; $ip=Get-NetIPConfiguration; [pscustomobject]@{Adapters=($ad|Select-Object Name,InterfaceDescription,Status,MacAddress);IPs=($ip|ForEach-Object {[pscustomobject]@{Interface=$_.InterfaceAlias;IPv4=$_.IPv4Address.IPAddress;IPv6=$_.IPv6Address.IPAddress;Gateway=$_.IPv4DefaultGateway.NextHop}})} }
function StorageSummary { $d=Get-Disk; $ph=Get-CimInstance Win32_DiskDrive; [pscustomobject]@{DiskCount=($d|Where-Object{$_.BusType -ne 'FileBackedVirtual'}).Count;Disks=($ph|ForEach-Object{[pscustomobject]@{Model=$_.Model;Serial=$_.SerialNumber;SizeGB=[math]::Round($_.Size/1GB,2);BusType=$_.InterfaceType}})} }
function BootStats { [pscustomobject]@{BootID12=(Get-WinEvent -FilterHashtable @{LogName='System';Id=12}).Count;Started6005=(Get-WinEvent -FilterHashtable @{LogName='System';Id=6005}).Count;Stopped6006=(Get-WinEvent -FilterHashtable @{LogName='System';Id=6006}).Count;Unexpected6008=(Get-WinEvent -FilterHashtable @{LogName='System';Id=6008}).Count} }
function RdpStatus { $v=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server').fDenyTSConnections; if ($v -eq 0){"Enabled"}elseif($v -eq 1){"Disabled"}else{"Unknown"} }
function VirtualizationHint { $cs=Get-CimInstance Win32_ComputerSystem; $m=("$($cs.Manufacturer) $($cs.Model)").ToLower(); if($m -match 'vmware|virtualbox|kvm|hyper-v|qemu|xen'){"Likely Virtualized"}else{"Likely Physical"} }
function TpmInfo { if (Get-Command Get-Tpm -ErrorAction SilentlyContinue){$t=Get-Tpm; [pscustomobject]@{Present=$t.TpmPresent;Ready=$t.TpmReady;Enabled=$t.TpmEnabled;Activated=$t.TpmActivated}} else {"Unavailable"} }
function BitLockerInfo { if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue){ Get-BitLockerVolume | ForEach-Object {[pscustomobject]@{MountPoint=$_.MountPoint;ProtectionStatus=$_.ProtectionStatus;VolumeStatus=$_.VolumeStatus;EncryptionMethod=$_.EncryptionMethod}} } else {"Unavailable"} }
function DefenderInfo { if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue){$m=Get-MpComputerStatus; [pscustomobject]@{RealTimeProtection=$m.RealTimeProtectionEnabled;AMProductVersion=$m.AMProductVersion;EngineVersion=$m.AMEngineVersion;SignatureVersion=$m.AntispywareSignatureVersion}} else {"Unavailable"} }
function AvProducts { try{ Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct | Select-Object displayName,pathToSignedProductExe,productState } catch {"Unavailable"} }
function DeviceType { $bat=(Get-CimInstance Win32_Battery); $enc=Get-CimInstance Win32_SystemEnclosure; $types=$enc.ChassisTypes; $islap=$false; if($bat){$islap=$true}; if($types){$islap=$islap -or ($types | Where-Object {$_ -in 8,9,10,11,12,14,18,21,30,31,32})}; if($islap){"Laptop"}else{"Desktop"} }
function DecodeChars($arr){ if(-not $arr){return $null}; ($arr | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_}) -join "" }
function MonitorInfo { $mons=Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue; if(-not $mons){ return (Get-CimInstance Win32_DesktopMonitor | ForEach-Object {[pscustomobject]@{Manufacturer=$_.MonitorManufacturer;Name=$_.Name;Serial=$_.PNPDeviceID;Active=$true}}) }; $mons | ForEach-Object { $m=DecodeChars $_.ManufacturerName; $n=DecodeChars $_.UserFriendlyName; $s=DecodeChars $_.SerialNumberID; [pscustomobject]@{Manufacturer=$m;Name=$n;Serial=$s;Active=$true} } }
function MonitorCount { (MonitorInfo | Measure-Object).Count }

function Print-Header($t){ Write-Host ""; Write-Host "=== $t ===" }
function Show-GeneralInfo {
    Print-Header "System"
    OsInfo | Format-List
    Write-Host ("DeviceType: " + (DeviceType))
    Print-Header "BIOS"
    BiosInfo | Format-List
    Print-Header "CPU"
    CpuInfo | Format-List
    Print-Header "RAM"
    RamInfo | Format-List
    Print-Header "GPU"
    GpuInfo | Format-Table -AutoSize
    Print-Header "Security"
    Write-Host ("SecureBoot: " + (SecureBootState))
    Write-Host ("RDP: " + (RdpStatus))
    Write-Host ("Virtualization: " + (VirtualizationHint))
    Print-Header "TPM"
    $t=TpmInfo
    if ($t -is [string]) { Write-Host $t } else { $t | Format-List }
    Print-Header "BitLocker"
    $bl=BitLockerInfo
    if ($bl -is [string]) { Write-Host $bl } else { $bl | Format-Table -AutoSize }
    Print-Header "Defender"
    $df=DefenderInfo
    if ($df -is [string]) { Write-Host $df } else { $df | Format-List }
    Print-Header "Antivirus Products"
    $av=AvProducts
    if ($av -is [string]) { Write-Host $av } else { $av | Format-Table -AutoSize }
    Print-Header "Storage"
    $st=StorageSummary
    Write-Host ("DiskCount: " + $st.DiskCount)
    $st.Disks | Format-Table -AutoSize
    Print-Header "Boot Stats"
    BootStats | Format-List
    Print-Header "Monitors"
    Write-Host ("MonitorCount: " + (MonitorCount))
    MonitorInfo | Format-Table -AutoSize
    Print-Header "Network"
    $ns=NetworkSummary
    $ns.Adapters | Format-Table -AutoSize
    $ns.IPs | Format-Table -AutoSize
}

function Show-Events($choice,$max){
    if(-not $max){$max=50}
    switch ($choice) {
        1 { Get-WinEvent -FilterHashtable @{LogName='System';Level=1} -MaxEvents $max | Select-Object TimeCreated,Id,ProviderName,Message | Format-Table -Wrap -AutoSize }
        2 { Get-WinEvent -FilterHashtable @{LogName='System';Level=2} -MaxEvents $max | Select-Object TimeCreated,Id,ProviderName,Message | Format-Table -Wrap -AutoSize }
        3 { Get-WinEvent -FilterHashtable @{LogName='Application';Level=1,2} -MaxEvents $max | Select-Object TimeCreated,Id,ProviderName,Message | Format-Table -Wrap -AutoSize }
        4 { Get-WinEvent -FilterHashtable @{LogName='Security';Id=4624,4625} -MaxEvents $max | Select-Object TimeCreated,Id,Message | Format-Table -Wrap -AutoSize }
        5 { Get-WinEvent -FilterHashtable @{LogName='System';Id=41;ProviderName='Microsoft-Windows-Kernel-Power'} -MaxEvents $max | Select-Object TimeCreated,Id,Message | Format-Table -Wrap -AutoSize }
        6 { Get-WinEvent -FilterHashtable @{LogName='System';Id=12,6005,6006,6008} -MaxEvents $max | Select-Object TimeCreated,Id,Message | Format-Table -Wrap -AutoSize }
        7 { Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Service Control Manager';Level=2,3} -MaxEvents $max | Select-Object TimeCreated,Id,Message | Format-Table -Wrap -AutoSize }
        8 { Get-WinEvent -FilterHashtable @{LogName='Application';ProviderName='MsiInstaller'} -MaxEvents $max | Select-Object TimeCreated,Id,Message | Format-Table -Wrap -AutoSize }
        9 { if (Get-WinEvent -ListLog 'Microsoft-Windows-Sysmon/Operational' -ErrorAction SilentlyContinue){ Get-WinEvent -LogName 'Microsoft-Windows-Sysmon/Operational' -MaxEvents $max | Select-Object TimeCreated,Id,ProviderName,Message | Format-Table -Wrap -AutoSize } else { Write-Host "Sysmon log not found" } }
        10 { $a1=Get-WinEvent -FilterHashtable @{LogName='System';Id=1001;ProviderName='BugCheck'} -MaxEvents $max; $a2=Get-WinEvent -FilterHashtable @{LogName='Application';Id=1001;ProviderName='Windows Error Reporting'} -MaxEvents $max; $all=@(); if($a1){$all+=$a1}; if($a2){$all+=$a2}; if($all.Count -eq 0){Write-Host "No BlueScreen events found"} else { $all | Sort-Object TimeCreated -Descending | Select-Object TimeCreated,Id,ProviderName,Message | Format-Table -Wrap -AutoSize } }
        11 { if (Get-WinEvent -ListLog 'Microsoft-Windows-WindowsUpdateClient/Operational' -ErrorAction SilentlyContinue){ Get-WinEvent -LogName 'Microsoft-Windows-WindowsUpdateClient/Operational' -MaxEvents $max | Select-Object TimeCreated,Id,Message | Format-Table -Wrap -AutoSize } else { Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-WindowsUpdateClient'} -MaxEvents $max | Select-Object TimeCreated,Id,Message | Format-Table -Wrap -AutoSize } }
        Default { Write-Host "Invalid selection" }
    }
}

function EventMenu {
    while ($true) {
        Write-Host ""
        Write-Host "Event Views:"
        Write-Host "1 System Critical"
        Write-Host "2 System Errors"
        Write-Host "3 Application Errors/Critical"
        Write-Host "4 Security Log"
        Write-Host "5 Kernel-Power"
        Write-Host "6 Boot/Shutdown"
        Write-Host "7 Service Control Manager Errors/Warnings"
        Write-Host "8 MSI Installer Events"
        Write-Host "9 Sysmon Operational (if present)"
        Write-Host "10 BlueScreen BugCheck 1001"
        Write-Host "11 Windows Update Client"
        Write-Host "0 Exit"
        $sel=Read-Host "Select 0-11"
        if ($sel -eq '0') { break }
        $max=Read-Host "Max events to show (default 50)"
        if (-not [int]::TryParse($max,[ref]0)) { $max=50 }
        Show-Events $sel [int]$max
        Read-Host "Press Enter to continue"
        Clear-Host
        Write-Host "Timestamp: $((Get-Date).ToString('s'))"
    }
}

Clear-Host
Write-Host "Timestamp: $((Get-Date).ToString('s'))"
Show-GeneralInfo
EventMenu
