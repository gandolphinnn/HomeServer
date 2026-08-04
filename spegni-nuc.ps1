# Shuts down the NUC (Minisforum U500, glnuc) via SSH - clean shutdown.
# Requirements (one-time setup, see GESTIONE-ENERGIA.md): PC SSH key authorized
# for luca@glnuc + NOPASSWD sudoers rule for /usr/sbin/poweroff.
param([switch]$Force)  # accepted for symmetry with the other scripts, not needed here

$ip = "192.168.1.171"

if (-not (Test-Connection -ComputerName $ip -Count 1 -Quiet)) {
    Write-Host "The NUC ($ip) is already off."
    exit 0
}

Write-Host "Sending shutdown to the NUC..."
ssh -o BatchMode=yes -o ConnectTimeout=5 "luca@$ip" "sudo /usr/sbin/poweroff"

$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt 90) {
    if (-not (Test-Connection -ComputerName $ip -Count 1 -Quiet)) {
        Write-Host "NUC is off (after $([int]$sw.Elapsed.TotalSeconds) seconds)."
        exit 0
    }
    Start-Sleep -Seconds 3
}
Write-Host "The NUC is still responding after 90 seconds. Typical causes (see the error above, if any):"
Write-Host " - 'Permission denied'         -> SSH key not set up"
Write-Host " - 'a password is required'    -> sudoers rule missing"
Write-Host "Setup: D:\Personale\HomeServer\GESTIONE-ENERGIA.md"
exit 1
