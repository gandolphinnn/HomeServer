# Wakes the NUC (Minisforum U500, glnuc) via Wake-on-LAN.
# Project rule: the NAS must be powered on BEFORE the NUC (the NUC mounts the NAS share
# at boot) -> this script checks that the NAS responds; use -Force to skip the check.
param([switch]$Force)

$mac = "84:39:BE:6B:55:73"
$ip  = "192.168.1.171"
$nas = "192.168.1.17"

if (-not $Force) {
    if (-not (Test-Connection -ComputerName $nas -Count 1 -Quiet)) {
        Write-Host "The NAS ($nas) is not responding: power it on first with sveglia-nas.ps1, then run this script again."
        Write-Host "To power on the NUC anyway: add -Force."
        exit 1
    }
}

# Magic packet: 6x 0xFF bytes + MAC repeated 16 times, UDP broadcast on port 9
# (both LAN-directed and global broadcast, same as sveglia-nas.ps1)
$bytes = [byte[]](,0xFF * 6) + (($mac -split ':' | ForEach-Object { [byte]("0x$_") }) * 16)
foreach ($target in @("192.168.1.255", "255.255.255.255")) {
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.EnableBroadcast = $true
    $udp.Connect($target, 9)
    1..3 | ForEach-Object { $udp.Send($bytes, $bytes.Length) | Out-Null; Start-Sleep -Milliseconds 200 }
    $udp.Close()
}
Write-Host "Magic packet sent to $mac. Waiting for $ip to respond (boot takes 1-2 minutes)..."

$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalMinutes -lt 3) {
    if (Test-Connection -ComputerName $ip -Count 1 -Quiet) {
        Write-Host "NUC is up and responding (after $([int]$sw.Elapsed.TotalSeconds) seconds)."
        exit 0
    }
    Start-Sleep -Seconds 5
}
Write-Host "No response after 3 minutes: check 'Wake-on: g' with ethtool on the NUC and the Wake-on-LAN option in the Minisforum BIOS."
exit 1
