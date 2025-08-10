$ascii = @"
 ██████╗██████╗ ███████╗ █████╗ ████████╗██╗██╗   ██╗ ██████╗ ███████╗██████╗ ██████╗ 
██╔════╝██╔══██╗██╔════╝██╔══██╗╚══██╔══╝██║██║   ██║██╔═══██╗██╔════╝██╔══██╗██╔══██╗
██║     ██████╔╝█████╗  ███████║   ██║   ██║██║   ██║██║   ██║███████╗██████╔╝██████╔╝
██║     ██╔══██╗██╔══╝  ██╔══██║   ██║   ██║╚██╗ ██╔╝██║   ██║╚════██║██╔══██╗██╔═══╝ 
╚██████╗██║  ██║███████╗██║  ██║   ██║   ██║ ╚████╔╝ ╚██████╔╝███████║██║  ██║██║     
 ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═══╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝     
"@
Write-Host $ascii -ForegroundColor Cyan

$monitorKeys = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY"

foreach ($monitorKey in $monitorKeys) {
    foreach ($instance in Get-ChildItem $monitorKey.PSPath) {
        $deviceParamsPath = Join-Path $instance.PSPath "Device Parameters"
        $edid = Get-ItemProperty -Path $deviceParamsPath -Name EDID -ErrorAction SilentlyContinue

        if ($edid) {
            $bytes = $edid.EDID
            $serialBytes = $bytes[12..15]
            $asciiSerial = [System.Text.Encoding]::ASCII.GetString($serialBytes)
            $asciiClean = ($asciiSerial -replace '[^\x20-\x7E]', '').Trim()

            if ($asciiClean.Length -eq 0) {
                $hexSerial = ($serialBytes | ForEach-Object { $_.ToString("X2") }) -join ' '
                Write-Host "[$($monitorKey.PSChildName)] Seriennummer: (HEX) $hexSerial" -ForegroundColor Yellow
            } else {
                Write-Host "[$($monitorKey.PSChildName)] Seriennummer: '$asciiClean'" -ForegroundColor Green
            }
        }
    }
} 
