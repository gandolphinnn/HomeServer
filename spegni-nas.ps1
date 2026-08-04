# Shuts down the NAS (HP MicroServer N40L, glnas) via SSH - clean shutdown.
# Project rule: power off the NUC FIRST, then the NAS -> if the NUC is up
# this script refuses to proceed (use -Force to override).
# Requirements (one-time setup, see GESTIONE-ENERGIA.md): PC SSH key for root@glnas.
param([switch]$Force)

$ip  = "192.168.1.17"
$nuc = "192.168.1.171"

if (-not (Test-Connection -ComputerName $ip -Count 1 -Quiet)) {
    Write-Host "The NAS ($ip) is already off."
    exit 0
}

if (-not $Force) {
    if (Test-Connection -ComputerName $nuc -Count 1 -Quiet) {
        Write-Host "The NUC ($nuc) is still up and has the NAS share mounted:"
        Write-Host "shutting down the NAS now would leave the NUC hanging (and the NUC watchdog"
        Write-Host "would wake the NAS right back up within a couple of minutes anyway)."
        Write-Host "Power off the NUC first (hs off nuc), or run again with -Force."
        exit 1
    }
}

Write-Host "Sending shutdown to the NAS..."
ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$ip" "poweroff"

$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt 90) {
    if (-not (Test-Connection -ComputerName $ip -Count 1 -Quiet)) {
        Write-Host "NAS is off (after $([int]$sw.Elapsed.TotalSeconds) seconds)."
        exit 0
    }
    Start-Sleep -Seconds 3
}
Write-Host "The NAS is still responding after 90 seconds. Typical cause (see the error above, if any):"
Write-Host " - 'Permission denied' -> SSH key not set up for root@$ip"
Write-Host "Setup: D:\Personale\HomeServer\GESTIONE-ENERGIA.md"
exit 1
