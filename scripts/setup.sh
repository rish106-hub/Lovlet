#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing xcodegen..."
  brew install xcodegen
fi

if [[ ! -f "$IOS_DIR/Config/Secrets.xcconfig" ]]; then
  cp "$IOS_DIR/Config/Secrets.xcconfig.example" "$IOS_DIR/Config/Secrets.xcconfig"
  echo "Created $IOS_DIR/Config/Secrets.xcconfig"
  echo "Fill in SUPABASE_URL and SUPABASE_ANON_KEY before running app."
fi

xcodegen generate --spec "$IOS_DIR/project.yml"

echo "Project generated: $IOS_DIR/CouplesMVP.xcodeproj"
