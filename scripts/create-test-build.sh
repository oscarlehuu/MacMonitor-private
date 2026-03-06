#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/MacMonitor.xcodeproj"
SCHEME="MacMonitor"
DESTINATION="platform=macOS"
DERIVED_DATA_PATH="$ROOT_DIR/build/share"
ARTIFACTS_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/MacMonitor.app"
ZIP_PATH="$ARTIFACTS_DIR/MacMonitor-test.zip"
SOURCE_REPO="oscarlehuu/MacMonitor-private"

resolve_marketing_version() {
  local version=""

  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    local latest_tag
    latest_tag="$(gh release view --repo "$SOURCE_REPO" --json tagName -q .tagName 2>/dev/null || true)"
    if [[ -n "$latest_tag" ]]; then
      version="${latest_tag#v}"
    fi
  fi

  if [[ -z "$version" ]]; then
    version="$(/usr/bin/python3 - <<'PY'
import json
from pathlib import Path
manifest_path = Path(".release-please-manifest.json")
if not manifest_path.exists():
    raise SystemExit("")
try:
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
except json.JSONDecodeError:
    raise SystemExit("")
print(payload.get(".", ""))
PY
)"
  fi

  if [[ -z "$version" ]]; then
    version="0.1.0"
  fi

  printf '%s\n' "$version"
}

MARKETING_VERSION="$(resolve_marketing_version)"

mkdir -p "$ARTIFACTS_DIR"
rm -rf "$DERIVED_DATA_PATH"
rm -f "$ZIP_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  clean build \
  MARKETING_VERSION="$MARKETING_VERSION" \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_IDENTITY="-" \
  ENABLE_HARDENED_RUNTIME=NO \
  CODE_SIGN_ENTITLEMENTS=""

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app was not found at: $APP_PATH" >&2
  exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
rm -rf "$DERIVED_DATA_PATH"
echo "Built MARKETING_VERSION: $MARKETING_VERSION"
echo "Created test build zip: $ZIP_PATH"
