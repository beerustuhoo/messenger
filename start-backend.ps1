# Single-command backend start for reviewers (Windows)
Set-Location $PSScriptRoot
docker compose -f backend/docker-compose.yml up --build -d

$lanIp = $null
try {
    $lanIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*' -and
            $_.IPAddress -notlike '172.1*' -and
            $_.PrefixOrigin -ne 'WellKnown'
        } |
        Sort-Object -Property InterfaceMetric |
        Select-Object -First 1).IPAddress
} catch {}

Write-Host ""
Write-Host "Backend started!"
Write-Host "  API:        http://localhost:3000"
Write-Host "  Health:     http://localhost:3000/health"
Write-Host "  Mail inbox: http://localhost:8025"
Write-Host ""
Write-Host "Mobile Messenger app (releases/app-release.apk):"
Write-Host "  Emulator / Nox / BlueStacks:  http://10.0.2.2:3000  (default — no setup)"
if ($lanIp) {
    Write-Host "  Physical phone (same Wi-Fi):  http://YOUR_PC_IP:3000"
    Write-Host "    This machine's IP:          http://${lanIp}:3000"
    Write-Host "    -> Login screen: tap the Server button -> Test -> Save"
} else {
    Write-Host "  Physical phone: set Server URL in app to http://YOUR_PC_IP:3000"
}
Write-Host ""
Write-Host "Stop with: docker compose -f backend/docker-compose.yml down"
