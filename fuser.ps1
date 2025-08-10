$ascii = @"
 ██████╗██████╗ ███████╗ █████╗ ████████╗██╗██╗   ██╗ ██████╗ ███████╗██████╗ ██████╗ 
██╔════╝██╔══██╗██╔════╝██╔══██╗╚══██╔══╝██║██║   ██║██╔═══██╗██╔════╝██╔══██╗██╔══██╗
██║     ██████╔╝█████╗  ███████║   ██║   ██║██║   ██║██║   ██║███████╗██████╔╝██████╔╝
██║     ██╔══██╗██╔══╝  ██╔══██║   ██║   ██║╚██╗ ██╔╝██║   ██║╚════██║██╔══██╗██╔═══╝ 
╚██████╗██║  ██║███████╗██║  ██║   ██║   ██║ ╚████╔╝ ╚██████╔╝███████║██║  ██║██║     
 ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═══╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝     
"@
Write-Host $ascii -ForegroundColor Cyan

function Get-EdidInfo {
    param([byte[]]$Bytes)
    $len = $Bytes.Length
    $sum = 0; $Bytes[0..([math]::Min(127,$len-1))] | ForEach-Object { $sum += $_ }
    $checksumOk = ($sum % 256) -eq 0
    $serialBytes = $Bytes[12..15]
    $serialAscii = [System.Text.Encoding]::ASCII.GetString($serialBytes) -replace '[^\x20-\x7E]', '' 
    $serialAscii = $serialAscii.Trim()
    $serialHex = ($serialBytes | ForEach-Object { $_.ToString('X2') }) -join ' '
    $serialNum = [System.BitConverter]::ToUInt32($Bytes,12)
    $week = $Bytes[16]
    $year = 1990 + $Bytes[17]
    [PSCustomObject]@{
        BytesLen     = $len
        ChecksumOk   = $checksumOk
        SerialASCII  = if($serialAscii){$serialAscii}else{$null}
        SerialHEX    = $serialHex
        SerialNum    = $serialNum
        Year         = $year
        Week         = $week
    }
}

$results = @()
$displayRoot = "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY"
$monitorKeys = @(Get-ChildItem $displayRoot -ErrorAction SilentlyContinue)

foreach ($monitorKey in $monitorKeys) {
    foreach ($instance in Get-ChildItem $monitorKey.PSPath -ErrorAction SilentlyContinue) {
        $dp = Join-Path $instance.PSPath "Device Parameters"
        $edid = Get-ItemProperty -Path $dp -Name EDID -ErrorAction SilentlyContinue
        $edidOverride = Get-ItemProperty -Path $dp -Name EDID_OVERRIDE -ErrorAction SilentlyContinue
        if ($edid) {
            $info = Get-EdidInfo -Bytes ($edid.EDID)
            $overrideFlags = $false
            Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Video" -ErrorAction SilentlyContinue | ForEach-Object {
                Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
                    Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
                        $_.PSObject.Properties.Name | ForEach-Object {
                            if ($_ -like "OverrideEdidFlags*") { $overrideFlags = $true }
                        }
                    }
                }
            }
            $reason = @()
            if (-not $info.ChecksumOk) { $reason += "InvalidChecksum" }
            if ($edidOverride) { $reason += "EDID_OVERRIDE" }
            if ($overrideFlags) { $reason += "OverrideEdidFlags" }
            if ([string]::IsNullOrWhiteSpace($info.SerialASCII) -and $info.SerialNum -eq 0) { $reason += "EmptySerial" }
            if ($info.BytesLen -notin 128,256) { $reason += "WeirdLength:$($info.BytesLen)" }
            $results += [PSCustomObject]@{
                MonitorID     = $monitorKey.PSChildName
                InstanceID    = $instance.PSChildName
                SerialASCII   = $info.SerialASCII
                SerialHEX     = $info.SerialHEX
                SerialNum     = $info.SerialNum
                Year          = $info.Year
                Week          = $info.Week
                BytesLen      = $info.BytesLen
                ChecksumOk    = $info.ChecksumOk
                HasOverride   = [bool]$edidOverride
                HasFlags      = $overrideFlags
                Suspicious    = $reason.Count -gt 0
                Reason        = ($reason -join ",")
            }
        }
    }
}

$dupes = $results | Group-Object SerialHEX | Where-Object { $_.Count -gt 1 -and $_.Name -ne $null } | Select-Object -ExpandProperty Name
if ($dupes) {
    $results | Where-Object { $dupes -contains $_.SerialHEX } | ForEach-Object {
        if ($_.Reason) { $_.Reason = "$($_.Reason),DuplicateSerial" } else { $_.Reason = "DuplicateSerial" }
        $_.Suspicious = $true
    }
}

$results | Sort-Object @{Expression='Suspicious';Descending=$true}, @{Expression='MonitorID';Descending=$false} | Format-Table -AutoSize
