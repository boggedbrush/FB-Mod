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
  awk -F': *' -v target="$key" '$1 == target {print $2; exit}' "$APP_PROPERTIES" | xargs
}

APP_NAME="$(get_prop "application.name")"
APP_VERSION="$(get_prop "application.version")"
RELEASE="${APP_NAME}_${APP_VERSION}"
ARCH="$(uname -m)"

ANT_BIN="${ANT_BIN:-}"
if [[ -z "$ANT_BIN" ]]; then
  ANT_BIN="$(command -v ant || true)"
fi
if [[ -z "$ANT_BIN" ]]; then
  if [[ -d "$ROOT_DIR/.tools" ]]; then
    ANT_BIN="$(find "$ROOT_DIR/.tools" -maxdepth 4 -type f -path '*/bin/ant' | head -n 1)"
  fi
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

OUTPUT_DIR="$ROOT_DIR/dist/appimage"
mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.AppImage "$OUTPUT_DIR"/*.AppImage.zsync
rm -f "$ROOT_DIR"/*.AppImage "$ROOT_DIR"/*.AppImage.zsync

TOOLS_DIR="$ROOT_DIR/build/linuxdeploy-tools"
mkdir -p "$TOOLS_DIR"

fetch_if_missing() {
  local url="$1"
  local dest="$2"
  if [[ ! -f "$dest" ]]; then
    curl -fsSL "$url" -o "$dest"
  fi
}

fetch_if_missing "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" "$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
fetch_if_missing "https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage" "$TOOLS_DIR/linuxdeploy-plugin-appimage-x86_64.AppImage"

chmod +x "$TOOLS_DIR"/linuxdeploy-*.AppImage

export PATH="$TOOLS_DIR:$PATH"
export APPIMAGE_EXTRACT_AND_RUN=1

UPDATE_INFO="${APPIMAGE_UPDATE_INFO:-}"
if [[ -n "$UPDATE_INFO" ]]; then
  export UPDATE_INFORMATION="$UPDATE_INFO"
  export LDAI_UPDATE_INFORMATION="$UPDATE_INFO"
fi

LINUXDEPLOY_CMD=("$TOOLS_DIR/linuxdeploy-x86_64.AppImage" --appdir "$APPDIR" --output appimage)
"${LINUXDEPLOY_CMD[@]}"

RAW_APPIMAGE="$(ls -1t "$ROOT_DIR"/*.AppImage 2>/dev/null | head -n 1 || true)"
if [[ -z "$RAW_APPIMAGE" || ! -f "$RAW_APPIMAGE" ]]; then
  echo "Failed to locate linuxdeploy output AppImage." >&2
  exit 1
fi

OUTPUT="$OUTPUT_DIR/${RELEASE}-${ARCH}.AppImage"
mv "$RAW_APPIMAGE" "$OUTPUT"
chmod +x "$OUTPUT"

RAW_ZSYNC="${RAW_APPIMAGE}.zsync"
if [[ -f "$RAW_ZSYNC" ]]; then
  mv "$RAW_ZSYNC" "$OUTPUT.zsync"
fi

echo "Built AppImage: $OUTPUT"
