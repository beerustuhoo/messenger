# Render deployment — build Flutter web and copy into backend/public
# Run BEFORE pushing to Git when deploying to Render.
#
# Usage:
#   .\scripts\prepare-render-deploy.ps1
#   .\scripts\prepare-render-deploy.ps1 -AppUrl https://mobile-messenger.onrender.com
#
# Then commit backend/public and push. Render serves API + web from one URL.

param(
    [string]$AppUrl = "AUTO"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Write-Host "Building Flutter web (API_URL=$AppUrl)..." -ForegroundColor Cyan
Push-Location "$root\mobile"
flutter pub get
flutter build web --dart-define=API_URL=$AppUrl
if ($LASTEXITCODE -ne 0) { throw "Flutter build failed" }
Pop-Location

$src = "$root\mobile\build\web"
$dest = "$root\backend\public"

if (-not (Test-Path $src)) {
    throw "Build output not found at $src"
}

Write-Host "Copying web build to backend/public..." -ForegroundColor Cyan
if (Test-Path $dest) {
    Get-ChildItem $dest -Exclude ".gitkeep" | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $dest | Out-Null
}

Copy-Item -Path "$src\*" -Destination $dest -Recurse -Force

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Green
Write-Host "  1. git add backend/public"
Write-Host "  2. git commit -m 'Deploy web build for Render'"
Write-Host "  3. git push  (Render auto-deploys)"
Write-Host ""
if ($AppUrl -eq "AUTO") {
    Write-Host "Web app will use the same origin as the API (recommended for Render)." -ForegroundColor Yellow
} else {
    Write-Host "Web app API URL baked in: $AppUrl" -ForegroundColor Yellow
}
