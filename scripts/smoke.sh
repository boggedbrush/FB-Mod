#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_LIB_DIR="$ROOT_DIR/dist/lib"

if [[ ! -d "$DIST_LIB_DIR" ]]; then
  echo "Missing dist/lib. Build first (scripts/bootstrap-dev.sh --install)." >&2
  exit 1
fi

CLASSPATH=""
while IFS= read -r jar; do
  if [[ -z "$CLASSPATH" ]]; then
    CLASSPATH="$jar"
  else
    CLASSPATH="$CLASSPATH:$jar"
  fi
done < <(find "$DIST_LIB_DIR" -maxdepth 1 -name '*.jar' | sort)

if [[ -z "$CLASSPATH" ]]; then
  echo "No jar files found in dist/lib" >&2
  exit 1
fi
JAVA_CMD="${JAVA_CMD:-$(command -v java || true)}"
if [[ -n "$JAVA_CMD" && -x "$JAVA_CMD" ]]; then
  if ! "$JAVA_CMD" -version >/dev/null 2>&1; then
    JAVA_CMD=""
  fi
fi
if [[ -z "$JAVA_CMD" || ! -x "$JAVA_CMD" ]]; then
  if [[ -x "/opt/homebrew/opt/openjdk@17/bin/java" ]]; then
    JAVA_CMD="/opt/homebrew/opt/openjdk@17/bin/java"
  fi
fi
if [[ -z "$JAVA_CMD" || ! -x "$JAVA_CMD" ]]; then
  echo "Unable to locate Java. Set JAVA_CMD or install JDK 17." >&2
  exit 1
fi
MAIN_CLASS="net.filebot.Main"

echo "Smoke: version"
"$JAVA_CMD" -cp "$CLASSPATH" "$MAIN_CLASS" -version

echo "Smoke: help"
"$JAVA_CMD" -cp "$CLASSPATH" "$MAIN_CLASS" -help >/dev/null

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

touch "$tmpdir/Example.Show.S01E01.mkv"

echo "Smoke: non-destructive rename test"
"$JAVA_CMD" -cp "$CLASSPATH" "$MAIN_CLASS" -rename --db file --format '{fn}' --action test "$tmpdir/Example.Show.S01E01.mkv" >/dev/null

echo "Smoke checks passed"
