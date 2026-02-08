#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_LIB_DIR="$ROOT_DIR/dist/lib"
DIST_JAR="$DIST_LIB_DIR/filebot.jar"
BOOTSTRAP_SCRIPT="$ROOT_DIR/scripts/bootstrap-dev.sh"

needs_rebuild() {
  if [[ ! -d "$DIST_LIB_DIR" || ! -f "$DIST_JAR" ]]; then
    return 0
  fi

  if find "$ROOT_DIR/source" -type f -newer "$DIST_JAR" -print -quit | grep -q .; then
    return 0
  fi

  return 1
}

try_ant_build() {
  if ! command -v ant >/dev/null 2>&1; then
    return 1
  fi

  echo "Rebuilding dist/lib with ant (resolve, jar)" >&2
  (
    cd "$ROOT_DIR"
    ant resolve
    ant jar
  )

  if needs_rebuild; then
    return 1
  fi
}

try_bootstrap_build() {
  if [[ ! -f "$BOOTSTRAP_SCRIPT" ]]; then
    return 1
  fi

  echo "Rebuilding dist/lib via bootstrap-dev.sh --install" >&2
  (
    cd "$ROOT_DIR"
    /usr/bin/env bash "$BOOTSTRAP_SCRIPT" --install
  )

  if needs_rebuild; then
    return 1
  fi
}

if needs_rebuild; then
  echo "Build artifacts are missing or stale." >&2

  if ! try_ant_build; then
    if ! try_bootstrap_build; then
      echo "Automatic rebuild failed: install Ant or run ./scripts/bootstrap-dev.sh --install manually." >&2
      exit 1
    fi
  fi
fi

if [[ ! -f "$DIST_JAR" ]]; then
  echo "Build did not produce $DIST_JAR" >&2
  exit 1
fi
