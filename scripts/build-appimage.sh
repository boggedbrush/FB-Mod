#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PROPERTIES="$ROOT_DIR/app.properties"

if [[ ! -f "$APP_PROPERTIES" ]]; then
  echo "Missing app.properties at $APP_PROPERTIES" >&2
  exit 1
fi

get_prop() {
  local key="$1"
  grep -m1 -E "^${key}:" "$APP_PROPERTIES" | cut -d: -f2- | xargs
}

APP_NAME="$(get_prop "application.name")"
APP_VERSION="$(get_prop "application.version")"
RELEASE="${APP_NAME}_${APP_VERSION}"
RAW_ARCH="$(uname -m)"
APPIMAGE_ARCH="$RAW_ARCH"
case "$RAW_ARCH" in
  x86_64 | amd64)
    APPIMAGE_ARCH="x86_64"
    ;;
  i386 | i486 | i586 | i686)
    APPIMAGE_ARCH="i686"
    ;;
  aarch64 | arm64)
    APPIMAGE_ARCH="aarch64"
    ;;
  armv6l | armv7l | armv7)
    APPIMAGE_ARCH="armhf"
    ;;
esac

ANT_BIN="${ANT_BIN:-}"
if [[ -z "$ANT_BIN" ]]; then
  ANT_BIN="$(command -v ant || true)"
fi
if [[ -z "$ANT_BIN" ]]; then
  ANT_BIN="$(find "$ROOT_DIR/.tools" -maxdepth 4 -type f -path '*/bin/ant' | head -n 1)"
fi
if [[ -z "$ANT_BIN" ]]; then
  echo "Unable to find Ant binary on PATH or in .tools" >&2
  exit 1
fi

echo "Using Ant at: $ANT_BIN"
"$ANT_BIN" jar appimage

APPDIR="$ROOT_DIR/dist/appimage/AppDir"
if [[ ! -d "$APPDIR" ]]; then
  echo "Missing AppDir at $APPDIR" >&2
  exit 1
fi

APPIMAGETOOL="${APPIMAGETOOL:-}"
if [[ -z "$APPIMAGETOOL" ]]; then
  if command -v appimagetool >/dev/null 2>&1; then
    APPIMAGETOOL="$(command -v appimagetool)"
  elif [[ -x "$ROOT_DIR/.tools/appimagetool.AppImage" ]]; then
    APPIMAGETOOL="$ROOT_DIR/.tools/appimagetool.AppImage"
  fi
fi

if [[ -z "$APPIMAGETOOL" ]]; then
  echo "Unable to find appimagetool. Set APPIMAGETOOL or install it." >&2
  exit 1
fi

OUTPUT="$ROOT_DIR/dist/${RELEASE}-${APPIMAGE_ARCH}.AppImage"
UPDATE_INFO="${APPIMAGE_UPDATE_INFO:-}"

export APPIMAGE_EXTRACT_AND_RUN=1
export APPIMAGETOOL_EXTRACT_AND_RUN=1
export ARCH="$APPIMAGE_ARCH"

if [[ -n "$UPDATE_INFO" ]]; then
  "$APPIMAGETOOL" --updateinformation "$UPDATE_INFO" "$APPDIR" "$OUTPUT"
else
  "$APPIMAGETOOL" "$APPDIR" "$OUTPUT"
fi

echo "Built AppImage: $OUTPUT"
