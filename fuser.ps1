$ascii=@"
 ██████╗██████╗ ███████╗ █████╗ ████████╗██╗██╗   ██╗ ██████╗ ███████╗██████╗ ██████╗ 
██╔════╝██╔══██╗██╔════╝██╔══██╗╚══██╔══╝██║██║   ██║██╔═══██╗██╔════╝██╔══██╗██╔══██╗
██║     ██████╔╝█████╗  ███████║   ██║   ██║██║   ██║██║   ██║███████╗██████╔╝██████╔╝
██║     ██╔══██╗██╔══╝  ██╔══██║   ██║   ██║╚██╗ ██╔╝██║   ██║╚════██║██╔══██╗██╔═══╝ 
╚██████╗██║  ██║███████╗██║  ██║   ██║   ██║ ╚████╔╝ ╚██████╔╝███████║██║  ██║██║     
 ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═══╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝     
"@
Write-Host $ascii -ForegroundColor Cyan

function Get-EdidBlocksOk{param([byte[]]$b)$ok=$true;for($i=0;$i -lt $b.Length;$i+=128){$s=0;for($j=0;$j -lt [Math]::Min(128,$b.Length-$i);$j++){ $s+=$b[$i+$j] }if(($s%256)-ne 0){$ok=$false}}$ok}
function Get-EdidName{param([byte[]]$b)$n=$null;for($o=54;$o -le 108;$o+=18){if($b[$o]-eq 0 -and $b[$o+1]-eq 0 -and $b[$o+2]-eq 0 -and $b[$o+3]-eq 0xFC -and $b[$o+4]-eq 0){$raw=$b[($o+5)..($o+17)];$s=[Text.Encoding]::ASCII.GetString($raw);$s=$s.Split("`n")[0].Trim();if($s){$n=$s}}}$n}
function Get-EdidMfg{param([byte[]]$b)$w=[UInt16]([UInt16]$b[8] -shl 8 -bor [UInt16]$b[9]);$w=$w -band 0x7FFF;$a=[char](64+($w -shr 10));$c=[char](64+(($w -shr 5) -band 31));$d=[char](64+($w -band 31));("$a$c$d")}
function Get-EdidInfo{param([byte[]]$Bytes)$len=$Bytes.Length;$chk=Get-EdidBlocksOk $Bytes;$serialBytes=$Bytes[12..15];$serialAscii=[Text.Encoding]::ASCII.GetString($serialBytes) -replace '[^\x20-\x7E]','';$serialAscii=$serialAscii.Trim();$serialHex=($serialBytes|%{ $_.ToString('X2') }) -join ' ';$serialNum=[BitConverter]::ToUInt32($Bytes,12);$week=$Bytes[16];$year=1990+$Bytes[17];$mfg=Get-EdidMfg $Bytes;$prod=[BitConverter]::ToUInt16($Bytes,10);$name=Get-EdidName $Bytes;[PSCustomObject]@{BytesLen=$len;ChecksumOk=$chk;SerialASCII=($serialAscii?$serialAscii:$null);SerialHEX=$serialHex;SerialNum=$serialNum;Year=$year;Week=$week;Mfg=$mfg;ProductCode=$prod;Model=$name}}
function Test-CRU{ $p=@("$env:USERPROFILE\Downloads\cru.exe","$env:USERPROFILE\Downloads\restart64.exe","$env:ProgramFiles\CRU\cru.exe","$env:ProgramFiles(x86)\CRU\cru.exe","$env:USERPROFILE\Desktop\cru.exe");($p|?{Test-Path $_}).Count -gt 0}
function Has-OverrideFlags{ $hit=$false;Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Video" -ErrorAction SilentlyContinue|%{Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue|%{Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue|%{ $_.PSObject.Properties.Name|%{if($_ -like 'OverrideEdidFlags*'){$hit=$true}}}}};$hit}

$results=@()
$displayRoot="HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY"
$monitorKeys=@(Get-ChildItem $displayRoot -ErrorAction SilentlyContinue)
$nowYear=(Get-Date).Year
$cru=Test-CRU
$flags=Has-OverrideFlags

foreach($monitorKey in $monitorKeys){
    foreach($instance in Get-ChildItem $monitorKey.PSPath -ErrorAction SilentlyContinue){
        $dp=Join-Path $instance.PSPath "Device Parameters"
        $edid=Get-ItemProperty -Path $dp -Name EDID -ErrorAction SilentlyContinue
        $edidOverride=Get-ItemProperty -Path $dp -Name EDID_OVERRIDE -ErrorAction SilentlyContinue
        if($edid){
            $info=Get-EdidInfo -Bytes ($edid.EDID)
            $reasons=@()
            if(-not $info.ChecksumOk){$reasons+="InvalidChecksum"}
            if($edidOverride){$reasons+="EDID_OVERRIDE"}
            if($flags){$reasons+="OverrideEdidFlags"}
            if($cru){$reasons+="CRU_Artifacts"}
            if([string]::IsNullOrWhiteSpace($info.SerialASCII) -and $info.SerialNum -eq 0){$reasons+="EmptySerial"}
            if($info.BytesLen -notin 128,256){$reasons+="WeirdLength:$($info.BytesLen)"}
            if($info.Year -lt 1990 -or $info.Year -gt ($nowYear+1)){$reasons+="WeirdYear:$($info.Year)"}
            if(-not $info.Model){$reasons+="NoModelName"}
            $results+= [PSCustomObject]@{
                MonitorID=$monitorKey.PSChildName
                InstanceID=$instance.PSChildName
                Mfg=$info.Mfg
                Product=$info.ProductCode
                Model=$info.Model
                SerialASCII=$info.SerialASCII
                SerialHEX=$info.SerialHEX
                SerialNum=$info.SerialNum
                Year=$info.Year
                Week=$info.Week
                BytesLen=$info.BytesLen
                ChecksumOk=$info.ChecksumOk
                HasOverride=[bool]$edidOverride
                HasFlags=$flags
                HasCRU=$cru
                Suspicious=$reasons.Count -gt 0
                Reason=($reasons -join ",")
            }
        }
    }
}

$dupeKeys=@()
$g1=$results|Group-Object SerialHEX|?{$_.Name -and $_.Count -gt 1};if($g1){$dupeKeys+=$g1|Select-Object -ExpandProperty Name}
$g2=$results|Group-Object SerialNum|?{$_.Name -and $_.Count -gt 1};if($g2){$dupeKeys+=$g2|Select-Object -ExpandProperty Name}
if($dupeKeys){
    $results|%{
        if($dupeKeys -contains $_.SerialHEX -or ($_.SerialNum -ne 0 -and $dupeKeys -contains ([string]$_.SerialNum))){
            $_.Reason=($_.Reason? "$($_.Reason),DuplicateSerial" : "DuplicateSerial")
            $_.Suspicious=$true
        }
    }
}

$results|Sort-Object @{Expression='Suspicious';Descending=$true},@{Expression='MonitorID';Descending=$false}|Format-Table -AutoSize
