#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_LIB_DIR="$ROOT_DIR/dist/lib"

/usr/bin/env bash "$ROOT_DIR/scripts/rebuild-if-needed.sh"

resolve_java() {
  local candidate
  local -a candidates=(
    "${JAVA_CMD:-}"
    "${JAVA_HOME:-}/bin/java"
    "$(command -v java || true)"
    "$ROOT_DIR/.tools/jdk-17/bin/java"
    "/usr/lib/jvm/java-17-openjdk/bin/java"
    "/usr/lib/jvm/temurin-17-jdk/bin/java"
    "/usr/lib/jvm/jdk-17/bin/java"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      if "$candidate" -version >/dev/null 2>&1; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi
  done

  return 1
}

resolve_javafx_lib() {
  local candidate
  local -a candidates=(
    "${JAVAFX_LIB:-}"
    "/usr/share/openjfx/lib"
    "/usr/lib/jvm/javafx-sdk/lib"
    "/usr/lib/openjfx/lib"
    "/usr/lib64/openjfx/lib"
    "$ROOT_DIR/cache/javafx-sdk-11.0.2/lib"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" ]] && [[ -f "$candidate/javafx-base.jar" || -f "$candidate/javafx.base.jar" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

JAVA_BIN="$(resolve_java || true)"
if [[ -z "$JAVA_BIN" ]]; then
  echo "Unable to locate Java 17+. Set JAVA_CMD or JAVA_HOME." >&2
  exit 1
fi

JAVAFX_PATH="$(resolve_javafx_lib || true)"
if [[ -z "$JAVAFX_PATH" ]]; then
  echo "Unable to locate JavaFX modules. Set JAVAFX_LIB to a lib directory containing javafx-*.jar." >&2
  echo "Example: export JAVAFX_LIB=\"$ROOT_DIR/cache/javafx-sdk-11.0.2/lib\"" >&2
  exit 1
fi

MODULES="javafx.controls,javafx.fxml,javafx.graphics,javafx.media,javafx.swing,javafx.web"

exec "$JAVA_BIN" \
  --module-path "$JAVAFX_PATH" \
  --add-modules="$MODULES" \
  -cp "$DIST_LIB_DIR/*" \
  net.filebot.Main \
  "$@"
