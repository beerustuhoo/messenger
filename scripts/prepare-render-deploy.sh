#!/usr/bin/env bash
# Build Flutter web and copy into backend/public for Render deploy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_URL="${1:-AUTO}"

echo "Building Flutter web (API_URL=$APP_URL)..."
cd "$ROOT/mobile"
flutter pub get
flutter build web --pwa-strategy=none --dart-define=API_URL="$APP_URL"

DEST="$ROOT/backend/public"
rm -rf "$DEST"/*
mkdir -p "$DEST"
cp -r build/web/* "$DEST/"

echo ""
echo "Done. Commit backend/public and push to trigger Render deploy."
