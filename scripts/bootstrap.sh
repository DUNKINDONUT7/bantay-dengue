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
echo "Setup complete. Run web (uses the built-in fallback Supabase project):"
echo "  flutter run -d chrome"
echo "Or copy env.json.example to env.json with your own project, then:"
echo "  flutter run -d chrome --dart-define-from-file=env.json"
