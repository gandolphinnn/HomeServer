# Wakes the NAS (HP MicroServer N40L, glnas) via Wake-on-LAN.
# Requirements: NAS plugged in, WoL enabled in BIOS (done 30/7)
#               and the Wake-on-LAN toggle in OMV (Network -> Interfaces -> Edit).

$mac = "3C:D9:2B:0C:F3:87"
$ip  = "192.168.1.17"

# Magic packet: 6x 0xFF bytes followed by the MAC repeated 16 times, UDP broadcast on port 9.
# Sent both to the LAN broadcast (192.168.1.255) and the global one: with multiple network
# interfaces (Tailscale, virtual adapters) the global broadcast may leave the wrong NIC;
# the LAN-directed one always leaves the right card.
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
        Write-Host "NAS is up and responding (after $([int]$sw.Elapsed.TotalSeconds) seconds)."
        exit 0
    }
    Start-Sleep -Seconds 5
}
Write-Host "No response after 3 minutes: check the Wake-on-LAN toggle in OMV (Network -> Interfaces) and that the NAS IP is still $ip."
exit 1
