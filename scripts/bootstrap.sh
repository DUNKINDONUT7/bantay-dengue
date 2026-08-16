#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter was not found. Install Flutter and add it to PATH: https://docs.flutter.dev/get-started/install"
  exit 1
fi

flutter doctor
if [[ ! -d android ]]; then
  echo "Generating standard Android host files..."
  flutter create --platforms=android --org ph.gov.marilao --project-name bantaydengue .
fi
flutter pub get

echo
echo "Setup complete. Run demo web:"
echo "  flutter run -d chrome --dart-define=APP_MODE=demo"
echo "Or select 'BantayDengue Web (Demo)' in VS Code Run and Debug."
