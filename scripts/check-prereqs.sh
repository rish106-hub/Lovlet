#!/usr/bin/env bash
set -euo pipefail

status=0

echo "Checking prerequisites..."

if [[ -d "/Applications/Xcode.app" ]]; then
  echo "- Xcode.app: found"
else
  echo "- Xcode.app: missing"
  status=1
fi

if command -v xcodegen >/dev/null 2>&1; then
  echo "- xcodegen: $(xcodegen --version | head -n 1)"
else
  echo "- xcodegen: missing"
  status=1
fi

if command -v xcodebuild >/dev/null 2>&1; then
  echo "- xcodebuild: found"
else
  echo "- xcodebuild: missing"
  status=1
fi

if [[ -f "ios/Config/Secrets.xcconfig" ]]; then
  if /usr/bin/grep -Eq "YOUR_PROJECT|YOUR_SUPABASE_ANON_KEY" "ios/Config/Secrets.xcconfig"; then
    echo "- Supabase secrets: placeholder values detected"
    status=1
  else
    echo "- Supabase secrets: configured"
  fi
else
  echo "- Supabase secrets: ios/Config/Secrets.xcconfig missing"
  status=1
fi

if [[ $status -eq 0 ]]; then
  echo "All prerequisites look good."
else
  echo "Prerequisite check failed."
fi

exit $status
