#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/mirror}"
BASE_URL="${BASE_URL:-https://api.filebot.net/v4}"

DATA_DIR="$OUTPUT_DIR/data"
SCRIPTS_DIR="$OUTPUT_DIR/scripts"
MANIFEST="$OUTPUT_DIR/manifest.sha256"

mkdir -p "$DATA_DIR" "$SCRIPTS_DIR"

files=(
  release-groups.txt.xz
  query-blacklist.txt.xz
  series-mappings.txt.xz
  moviedb.txt.xz
  thetvdb.txt.xz
  anidb.txt.xz
  osdb.txt.xz
)

for file in "${files[@]}"; do
  echo "Downloading data/$file"
  curl -fsSL "$BASE_URL/data/$file" -o "$DATA_DIR/$file"
done

echo "Downloading scripts/fn.jar.xz"
curl -fsSL "$BASE_URL/script/fn.jar.xz" -o "$SCRIPTS_DIR/fn.jar.xz"

{
  echo "# generated=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# source=$BASE_URL"
  (cd "$OUTPUT_DIR" && find . -type f ! -name 'manifest.sha256' -print0 | sort -z | xargs -0 shasum -a 256)
} > "$MANIFEST"

echo "Mirror written to $OUTPUT_DIR"
echo "Use with: --data-source $OUTPUT_DIR"
