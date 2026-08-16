$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error "Flutter was not found. Install it and add flutter/bin to PATH: https://docs.flutter.dev/get-started/install"
}

flutter doctor
if (-not (Test-Path "android")) {
  Write-Host "Generating standard Android host files..."
  flutter create --platforms=android --org ph.gov.marilao --project-name bantaydengue .
}
flutter pub get

Write-Host ""
Write-Host "Setup complete. Run demo web:"
Write-Host "  flutter run -d chrome --dart-define=APP_MODE=demo"
Write-Host "Or select 'BantayDengue Web (Demo)' in VS Code Run and Debug."
