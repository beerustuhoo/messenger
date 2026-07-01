# Build and deploy Web Messenger (serves on http://localhost:8080)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

Write-Host "Building Flutter web..." -ForegroundColor Cyan
Push-Location "$root\mobile"
flutter build web --dart-define=API_URL=http://localhost:3000
Pop-Location

Write-Host "Starting web container (nginx on port 8080)..." -ForegroundColor Cyan
docker compose -f "$root\backend\docker-compose.yml" up -d web

Write-Host ""
Write-Host "Web Messenger: http://localhost:8080" -ForegroundColor Green
Write-Host "API:           http://localhost:3000" -ForegroundColor Green
